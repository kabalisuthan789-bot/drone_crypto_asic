`default_nettype none

module chacha_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [255:0] key,
    input  wire [95:0]  nonce,
    input  wire [31:0]  counter,
    output reg  [511:0] keystream,
    output reg         ready
);

    // Internal ChaCha20 4x4 matrix state (16 x 32-bit registers)
    reg [31:0] state [0:15];
    reg [31:0] initial_state [0:15];

    // Iterative control counters
    reg [4:0]  round_idx; // 0 to 19 (20 rounds)
    reg [2:0]  qr_step;   // 0 to 3 (4 QRs per round)
    reg [1:0]  sub_step;  // 4 operations within one QR
    reg [1:0]  fsm_state;

    localparam S_IDLE  = 2'd0;
    localparam S_INIT  = 2'd1;
    localparam S_ROUNDS= 2'd2;
    localparam S_FINAL = 2'd3;

    // QR active indices
    reg [3:0] idx_a, idx_b, idx_c, idx_d;

    // Round routing logic: alternate between column and diagonal rounds
    always @(*) begin
        if (~round_idx[0]) begin
            // Column Rounds (Even rounds)
            case (qr_step)
                3'd0: {idx_a, idx_b, idx_c, idx_d} = {4'd0, 4'd4, 4'd8,  4'd12};
                3'd1: {idx_a, idx_b, idx_c, idx_d} = {4'd1, 4'd5, 4'd9,  4'd13};
                3'd2: {idx_a, idx_b, idx_c, idx_d} = {4'd2, 4'd6, 4'd10, 4'd14};
                default: {idx_a, idx_b, idx_c, idx_d} = {4'd3, 4'd7, 4'd11, 4'd15};
            endcase
        end else begin
            // Diagonal Rounds (Odd rounds)
            case (qr_step)
                3'd0: {idx_a, idx_b, idx_c, idx_d} = {4'd0, 4'd5, 4'd10, 4'd15};
                3'd1: {idx_a, idx_b, idx_c, idx_d} = {4'd1, 4'd6, 4'd11, 4'd12};
                3'd2: {idx_a, idx_b, idx_c, idx_d} = {4'd2, 4'd7, 4'd8,  4'd13};
                default: {idx_a, idx_b, idx_c, idx_d} = {4'd3, 4'd4, 4'd9,  4'd14};
            endcase
        end
    end

    // Single Shared Quarter-Round Hardware Engine
    reg  [31:0] qr_in1, qr_in2;
    reg  [4:0]  rot_amt;
    wire [31:0] add_res = qr_in1 + qr_in2;
    wire [31:0] xor_res = qr_in1 ^ qr_in2;
    wire [31:0] rot_res = (xor_res << rot_amt) | (xor_res >> (32 - rot_amt));

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready     <= 1'b1;
            fsm_state <= S_IDLE;
            round_idx <= 5'd0;
            qr_step   <= 3'd0;
            sub_step  <= 2'd0;
            keystream <= 512'd0;
        end else begin
            case (fsm_state)
                S_IDLE: begin
                    ready <= 1'b1;
                    if (start) begin
                        ready     <= 1'b0;
                        fsm_state <= S_INIT;
                    end
                end

                S_INIT: begin
                    // ChaCha20 standard constant words ("expand 32-byte k")
                    state[0]  <= 32'h61707865;
                    state[1]  <= 32'h3320646e;
                    state[2]  <= 32'h79622d32;
                    state[3]  <= 32'h6b206574;
                    // 256-bit Key
                    state[4]  <= key[31:0];
                    state[5]  <= key[63:32];
                    state[6]  <= key[95:64];
                    state[7]  <= key[127:96];
                    state[8]  <= key[159:128];
                    state[9]  <= key[191:160];
                    state[10] <= key[223:192];
                    state[11] <= key[255:224];
                    // 32-bit Counter
                    state[12] <= counter;
                    // 96-bit Nonce
                    state[13] <= nonce[31:0];
                    state[14] <= nonce[63:32];
                    state[15] <= nonce[95:64];

                    // Cache initial matrix for post-addition
                    for (i = 0; i < 16; i = i + 1) begin
                        initial_state[i] <= state[i];
                    end

                    round_idx <= 5'd0;
                    qr_step   <= 3'd0;
                    sub_step  <= 2'd0;
                    fsm_state <= S_ROUNDS;
                end

                S_ROUNDS: begin
                    // Time-multiplexed QR execution
                    case (sub_step)
                        2'd0: begin // a = a + b; d = (d ^ a) <<< 16;
                            qr_in1 <= state[idx_a];
                            qr_in2 <= state[idx_b];
                            rot_amt <= 5'd16;
                            state[idx_a] <= add_res;
                            state[idx_d] <= rot_res;
                            sub_step <= 2'd1;
                        end
                        2'd1: begin // c = c + d; b = (b ^ c) <<< 12;
                            qr_in1 <= state[idx_c];
                            qr_in2 <= state[idx_d];
                            rot_amt <= 5'd12;
                            state[idx_c] <= add_res;
                            state[idx_b] <= rot_res;
                            sub_step <= 2'd2;
                        end
                        2'd2: begin // a = a + b; d = (d ^ a) <<< 8;
                            qr_in1 <= state[idx_a];
                            qr_in2 <= state[idx_b];
                            rot_amt <= 5'd8;
                            state[idx_a] <= add_res;
                            state[idx_d] <= rot_res;
                            sub_step <= 2'd3;
                        end
                        2'd3: begin // c = c + d; b = (b ^ c) <<< 7;
                            qr_in1 <= state[idx_c];
                            qr_in2 <= state[idx_d];
                            rot_amt <= 5'd7;
                            state[idx_c] <= add_res;
                            state[idx_b] <= rot_res;
                            sub_step <= 2'd0;

                            if (qr_step == 3'd3) begin
                                qr_step <= 3'd0;
                                if (round_idx == 5'd19) begin
                                    fsm_state <= S_FINAL;
                                end else begin
                                    round_idx <= round_idx + 1'b1;
                                end
                            end else begin
                                qr_step <= qr_step + 1'b1;
                            end
                        end
                    endcase
                end

                S_FINAL: begin
                    // Final addition of original state to processed state
                    for (i = 0; i < 16; i = i + 1) begin
                        keystream[(i*32) +: 32] <= state[i] + initial_state[i];
                    end
                    ready     <= 1'b1;
                    fsm_state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
