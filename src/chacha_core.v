`timescale 1ns / 1ps

module chacha_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [255:0] key,
    input  wire [31:0]  counter,
    input  wire [95:0]  nonce,
    output reg         done,
    input  wire [3:0]  out_addr,
    output reg  [31:0] out_word
);
    reg [31:0] state_mat [0:15];
    reg [31:0] orig_mat  [0:15];

    localparam S_IDLE   = 2'd0;
    localparam S_LOAD   = 2'd1;
    localparam S_ROUNDS = 2'd2;
    localparam S_DONE   = 2'd3;

    reg [1:0] current_state;
    reg [4:0] round_cnt;
    reg [1:0] step_in_round;

    reg [3:0] idx_a, idx_b, idx_c, idx_d;
    wire is_diag = round_cnt[0];

    always @(*) begin
        if (!is_diag) begin
            case (step_in_round)
                2'd0: begin idx_a = 4'd0; idx_b = 4'd4; idx_c = 4'd8;  idx_d = 4'd12; end
                2'd1: begin idx_a = 4'd1; idx_b = 4'd5; idx_c = 4'd9;  idx_d = 4'd13; end
                2'd2: begin idx_a = 4'd2; idx_b = 4'd6; idx_c = 4'd10; idx_d = 4'd14; end
                2'd3: begin idx_a = 4'd3; idx_b = 4'd7; idx_c = 4'd11; idx_d = 4'd15; end
            endcase
        end else begin
            case (step_in_round)
                2'd0: begin idx_a = 4'd0; idx_b = 4'd5; idx_c = 4'd10; idx_d = 4'd15; end
                2'd1: begin idx_a = 4'd1; idx_b = 4'd6; idx_c = 4'd11; idx_d = 4'd12; end
                2'd2: begin idx_a = 4'd2; idx_b = 4'd7; idx_c = 4'd8;  idx_d = 4'd13; end
                2'd3: begin idx_a = 4'd3; idx_b = 4'd4; idx_c = 4'd9;  idx_d = 4'd14; end
            endcase
        end
    end

    wire [31:0] qr_a_out, qr_b_out, qr_c_out, qr_d_out;

    chacha_qr qr_unit (
        .a_in(state_mat[idx_a]),
        .b_in(state_mat[idx_b]),
        .c_in(state_mat[idx_c]),
        .d_in(state_mat[idx_d]),
        .a_out(qr_a_out),
        .b_out(qr_b_out),
        .c_out(qr_c_out),
        .d_out(qr_d_out)
    );

    always @(*) begin
        out_word = state_mat[out_addr] + orig_mat[out_addr];
    end

    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            round_cnt     <= 5'd0;
            step_in_round <= 2'd0;
            done          <= 1'b0;
            for (k = 0; k < 16; k = k + 1) begin
                state_mat[k] <= 32'd0;
                orig_mat[k]  <= 32'd0;
            end
        end else begin
            case (current_state)
                S_IDLE: begin
                    done          <= 1'b0;
                    round_cnt     <= 5'd0;
                    step_in_round <= 2'd0;
                    if (start) current_state <= S_LOAD;
                end

                S_LOAD: begin
                    orig_mat[0]  <= 32'h61707865; orig_mat[1]  <= 32'h3320646e;
                    orig_mat[2]  <= 32'h79622d32; orig_mat[3]  <= 32'h6b206574;
                    orig_mat[4]  <= key[31:0];     orig_mat[5]  <= key[63:32];
                    orig_mat[6]  <= key[95:64];    orig_mat[7]  <= key[127:96];
                    orig_mat[8]  <= key[159:128];  orig_mat[9]  <= key[191:160];
                    orig_mat[10] <= key[223:192];  orig_mat[11] <= key[255:224];
                    orig_mat[12] <= counter;
                    orig_mat[13] <= nonce[31:0];
                    orig_mat[14] <= nonce[63:32];
                    orig_mat[15] <= nonce[95:64];

                    state_mat[0]  <= 32'h61707865; state_mat[1]  <= 32'h3320646e;
                    state_mat[2]  <= 32'h79622d32; state_mat[3]  <= 32'h6b206574;
                    state_mat[4]  <= key[31:0];     state_mat[5]  <= key[63:32];
                    state_mat[6]  <= key[95:64];    state_mat[7]  <= key[127:96];
                    state_mat[8]  <= key[159:128];  state_mat[9]  <= key[191:160];
                    state_mat[10] <= key[223:192];  state_mat[11] <= key[255:224];
                    state_mat[12] <= counter;
                    state_mat[13] <= nonce[31:0];
                    state_mat[14] <= nonce[63:32];
                    state_mat[15] <= nonce[95:64];

                    round_cnt     <= 5'd0;
                    step_in_round <= 2'd0;
                    current_state <= S_ROUNDS;
                end

                S_ROUNDS: begin
                    state_mat[idx_a] <= qr_a_out;
                    state_mat[idx_b] <= qr_b_out;
                    state_mat[idx_c] <= qr_c_out;
                    state_mat[idx_d] <= qr_d_out;

                    if (step_in_round == 2'd3) begin
                        step_in_round <= 2'd0;
                        if (round_cnt == 5'd19) begin
                            current_state <= S_DONE;
                            done          <= 1'b1;
                        end else begin
                            round_cnt <= round_cnt + 1'b1;
                        end
                    end else begin
                        step_in_round <= step_in_round + 1'b1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (!start) current_state <= S_IDLE;
                end
            endcase
        end
    end
endmodule