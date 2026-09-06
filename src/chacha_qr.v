`timescale 1ns / 1ps

// Combinational ChaCha20 Quarter-Round (QR) Engine
module chacha_qr (
    input  wire [31:0] a_in,
    input  wire [31:0] b_in,
    input  wire [31:0] c_in,
    input  wire [31:0] d_in,
    output wire [31:0] a_out,
    output wire [31:0] b_out,
    output wire [31:0] c_out,
    output wire [31:0] d_out
);

    // Internal intermediate wires between steps
    wire [31:0] a1, b1, c1, d1;
    wire [31:0] a2, b2, c2, d2;

    // Helper: 32-bit Left Rotate function
    function [31:0] rotl;
        input [31:0] val;
        input [4:0]  shift;
        begin
            rotl = (val << shift) | (val >> (32 - shift));
        end
    endfunction

    // Step 1: Add into a, XOR-rotate d by 16
    assign a1 = a_in + b_in;
    assign d1 = rotl((d_in ^ a1), 5'd16);

    // Step 2: Add into c, XOR-rotate b by 12
    assign c1 = c_in + d1;
    assign b1 = rotl((b_in ^ c1), 5'd12);

    // Step 3: Add into a, XOR-rotate d by 8
    assign a2 = a1 + b1;
    assign d2 = rotl((d1 ^ a2), 5'd8);

    // Step 4: Add into c, XOR-rotate b by 7
    assign c_out = c1 + d2;
    assign b_out = rotl((b1 ^ c_out), 5'd7);

    // Final a and d outputs
    assign a_out = a2;
    assign d_out = d2;

endmodule