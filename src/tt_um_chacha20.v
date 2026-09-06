`timescale 1ns / 1ps

module tt_um_chacha20 (
    input  wire [7:0] ui_in,    // Dedicated inputs: [7:0] Data Byte
    output wire [7:0] uo_out,   // Dedicated outputs: [7:0] Data Byte
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (1 = output, 0 = input)
    input  wire       ena,      // Tiny Tapeout enable
    input  wire       clk,      // Clock
    input  wire       rst_n     // Active-low reset
);

    // Control Pins:
    // uio_in[0] = cfg_valid
    // uio_in[2:1] = cfg_sel (2'b00: Key, 2'b01: Counter, 2'b10: Nonce)
    // uio_in[3] = cipher_start
    // uio_in[4] = data_in_valid
    // uio_in[5] = data_out_ready
    wire       cfg_valid      = uio_in[0];
    wire [1:0] cfg_sel        = uio_in[2:1];
    wire       cipher_start   = uio_in[3];
    wire       data_in_valid  = uio_in[4];
    wire       data_out_ready = uio_in[5];

    // Status Pins (bits 7:6 output):
    // uio_out[6] = core_ready
    // uio_out[7] = data_out_valid
    wire core_ready;
    wire data_out_valid;
    wire data_in_ready;

    assign uio_oe  = 8'b11000000;
    assign uio_out = {data_out_valid, core_ready, 6'b000000};

    // Configuration Registers
    reg [255:0] key_reg;
    reg [31:0]  counter_reg;
    reg [95:0]  nonce_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_reg     <= 256'd0;
            counter_reg <= 32'd0;
            nonce_reg   <= 96'd0;
        end else if (cfg_valid) begin
            case (cfg_sel)
                2'b00: key_reg     <= {ui_in, key_reg[255:8]};
                2'b01: counter_reg <= {ui_in, counter_reg[31:8]};
                2'b10: nonce_reg   <= {ui_in, nonce_reg[95:8]};
            endcase
        end
    end

    // Subsystem Instance
    chacha_stream_cipher stream_engine (
        .clk(clk),
        .rst_n(rst_n),
        .start(cipher_start),
        .key(key_reg),
        .counter(counter_reg),
        .nonce(nonce_reg),
        .core_ready(core_ready),
        .data_in_valid(data_in_valid),
        .data_in(ui_in),
        .data_in_ready(data_in_ready),
        .data_out_valid(data_out_valid),
        .data_out(uo_out),
        .data_out_ready(data_out_ready)
    );

endmodule