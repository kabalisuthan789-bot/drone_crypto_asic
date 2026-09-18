`default_nettype none
`timescale 1ns / 1ps

module chacha_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [255:0] key,
    input  wire [95:0]  nonce,
    input  wire [31:0]  counter,
    input  wire [3:0]   out_addr,
    output wire [31:0]  out_word,
    output reg         done
);

    // Internal 4x4 matrix state (16 x 32-bit words)
    reg [31:0] state [0:15];
    reg [31:0] init_state [0:15];

    // Iteration control registers
    reg [4:0] round_idx; // 0 to 19
    reg [1:0] qr_step;   // 0 to 3
    reg [1:0] sub_step;  // 0 to 3
    reg [1:0] fsm_state;

    localparam S_IDLE   = 2'd0;
    localparam S_INIT   = 2'd1;
    localparam S_ROUNDS = 2'd2;
    localparam S_DONE   = 2'd3;

    // QR index multiplexing
    reg [3:0] idx_a, idx_b, idx_c, idx_d;

    always @(*) begin
        if (~round_idx[0]) begin
            // Column rounds
            case (qr_step)
                2'd0: {idx_a, idx_b, idx_c, idx_d} = {4'd0, 4'd4, 4'd8,  4'd12};
                2'd1: {idx_a, idx_b, idx_c, idx_d} = {4'd1, 4'd5, 4'd9,  4'd13};
                2'd2: {idx_a, idx_b, idx_c, idx_d} = {4'd2, 4'd6, 4'd10, 4'd14};
                2'd3: {idx_a, idx_b, idx_c, idx_d} = {4'd3, 4'd7, 4'd11, 4'd15};
            endcase
        end else begin
            // Diagonal rounds
            case (qr_step)
                2'd0: {idx_a, idx_b, idx_c, idx_d} = {4'd0, 4'd5, 4'd10, 4'd15};
                2'd1: {idx_a, idx_b, idx_c, idx_d} = {4'd1, 4'd6, 4'd11, 4'd12};
                2'd2: {idx_a, idx_b, idx_c, idx_d} = {4'd2, 4'd7, 4'd8,  4'd13};
                2'd3: {idx_a, idx_b, idx_c, idx_d} = {4'd3, 4'd4, 4'd9,  4'd14};
            endcase
        end
    end

    // Single shared 32-bit Quarter-Round datapath
    reg  [31:0] qr_in1, qr_in2;
    reg  [4:0]  rot_amt;
    wire [31:0] add_res = qr_in1 + qr_in2;
    wire [31:0] xor_res = qr_in1 ^ qr_in2;
    wire [31:0] rot_res = (xor_res << rot_amt) | (xor_res >> (32 - rot_amt));

    // Continuous output word generation
    assign out_word = state[out_addr] + init_state[out_addr];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done      <= 1'b0;
            fsm_state <= S_IDLE;
            round_idx <= 5'd0;
            qr_step   <= 2'd0;
            sub_step  <= 2'd0;
            qr_in1    <= 32'd0;
            qr_in2    <= 32'd0;
            rot_amt   <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
                state[i]      <= 32'd0;
                init_state[i] <= 32'd0;
            end
        end else begin
            case (fsm_state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        fsm_state <= S_INIT;
                    end
                end

                S_INIT: begin
                    state[0]  <= 32'h61707865;
                    state[1]  <= 32'h3320646e;
                    state[2]  <= 32'h79622d32;
                    state[3]  <= 32'h6b206574;
                    state[4]  <= key[31:0];
                    state[5]  <= key[63:32];
                    state[6]  <= key[95:64];
                    state[7]  <= key[127:96];
                    state[8]  <= key[159:128];
                    state[9]  <= key[191:160];
                    state[10] <= key[223:192];
                    state[11] <= key[255:224];
                    state[12] <= counter;
                    state[13] <= nonce[31:0];
                    state[14] <= nonce[63:32];
                    state[15] <= nonce[95:64];

                    init_state[0]  <= 32'h61707865;
                    init_state[1]  <= 32'h3320646e;
                    init_state[2]  <= 32'h79622d32;
                    init_state[3]  <= 32'h6b206574;
                    init_state[4]  <= key[31:0];
                    init_state[5]  <= key[63:32];
                    init_state[6]  <= key[95:64];
                    init_state[7]  <= key[127:96];
                    init_state[8]  <= key[159:128];
                    init_state[9]  <= key[191:160];
                    init_state[10] <= key[223:192];
                    init_state[11] <= key[255:224];
                    init_state[12] <= counter;
                    init_state[13] <= nonce[31:0];
                    init_state[14] <= nonce[63:32];
                    init_state[15] <= nonce[95:64];

                    round_idx <= 5'd0;
                    qr_step   <= 2'd0;
                    sub_step  <= 2'd0;
                    fsm_state <= S_ROUNDS;
                end

                S_ROUNDS: begin
                    case (sub_step)
                        2'd0: begin
                            qr_in1 <= state[idx_a];
                            qr_in2 <= state[idx_b];
                            rot_amt <= 5'd16;
                            state[idx_a] <= add_res;
                            state[idx_d] <= rot_res;
                            sub_step <= 2'd1;
                        end
                        2'd1: begin
                            qr_in1 <= state[idx_c];
                            qr_in2 <= state[idx_d];
                            rot_amt <= 5'd12;
                            state[idx_c] <= add_res;
                            state[idx_b] <= rot_res;
                            sub_step <= 2'd2;
                        end
                        2'd2: begin
                            qr_in1 <= state[idx_a];
                            qr_in2 <= state[idx_b];
                            rot_amt <= 5'd8;
                            state[idx_a] <= add_res;
                            state[idx_d] <= rot_res;
                            sub_step <= 2'd3;
                        end
                        2'd3: begin
                            qr_in1 <= state[idx_c];
                            qr_in2 <= state[idx_d];
                            rot_amt <= 5'd7;
                            state[idx_c] <= add_res;
                            state[idx_b] <= rot_res;
                            sub_step <= 2'd0;

                            if (qr_step == 2'd3) begin
                                qr_step <= 2'd0;
                                if (round_idx == 5'd19) begin
                                    fsm_state <= S_DONE;
                                end else begin
                                    round_idx <= round_idx + 1'b1;
                                end
                            end else begin
                                qr_step <= qr_step + 1'b1;
                            end
                        end
                    endcase
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        fsm_state <= S_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
