`timescale 1ns / 1ps

module chacha_stream_cipher (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [255:0] key,
    input  wire [31:0]  counter,
    input  wire [95:0]  nonce,
    output wire        core_ready,
    input  wire        data_in_valid,
    input  wire [7:0]  data_in,
    output reg         data_in_ready,
    output reg         data_out_valid,
    output reg  [7:0]  data_out,
    input  wire        data_out_ready
);
    reg         core_start;
    wire        core_done;
    reg  [3:0]  core_out_addr;
    wire [31:0] core_out_word;

    reg [7:0] keystream_buf [0:63];
    reg [5:0] byte_idx;
    reg [4:0] word_idx;

    chacha_core core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(core_start),
        .key(key),
        .counter(counter),
        .nonce(nonce),
        .done(core_done),
        .out_addr(core_out_addr),
        .out_word(core_out_word)
    );

    localparam S_IDLE       = 3'd0;
    localparam S_GEN_BLOCK  = 3'd1;
    localparam S_FETCH_ADDR = 3'd2;
    localparam S_LOAD_BYTES = 3'd3;
    localparam S_STREAM     = 3'd4;

    reg [2:0] state;
    assign core_ready = (state == S_IDLE);

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= S_IDLE;
            core_start     <= 1'b0;
            core_out_addr  <= 4'd0;
            word_idx       <= 5'd0;
            byte_idx       <= 6'd0;
            data_in_ready  <= 1'b0;
            data_out_valid <= 1'b0;
            data_out       <= 8'd0;
            for (i = 0; i < 64; i = i + 1) begin
                keystream_buf[i] <= 8'd0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    data_in_ready  <= 1'b0;
                    data_out_valid <= 1'b0;
                    word_idx       <= 5'd0;
                    byte_idx       <= 6'd0;
                    if (start) begin
                        core_start <= 1'b1;
                        state      <= S_GEN_BLOCK;
                    end
                end

                S_GEN_BLOCK: begin
                    core_start <= 1'b0;
                    if (core_done) begin
                        core_out_addr <= 4'd0;
                        word_idx      <= 5'd0;
                        state         <= S_FETCH_ADDR;
                    end
                end

                S_FETCH_ADDR: begin
                    core_out_addr <= word_idx[3:0];
                    state         <= S_LOAD_BYTES;
                end

                S_LOAD_BYTES: begin
                    keystream_buf[{word_idx[3:0], 2'b00}] <= core_out_word[7:0];
                    keystream_buf[{word_idx[3:0], 2'b01}] <= core_out_word[15:8];
                    keystream_buf[{word_idx[3:0], 2'b10}] <= core_out_word[23:16];
                    keystream_buf[{word_idx[3:0], 2'b11}] <= core_out_word[31:24];

                    if (word_idx == 5'd15) begin
                        byte_idx      <= 6'd0;
                        data_in_ready <= 1'b1;
                        state         <= S_STREAM;
                    end else begin
                        word_idx <= word_idx + 1'b1;
                        state    <= S_FETCH_ADDR;
                    end
                end

                S_STREAM: begin
                    if (data_out_valid && data_out_ready) begin
                        data_out_valid <= 1'b0;
                        data_in_ready  <= 1'b1;
                    end

                    if (data_in_valid && data_in_ready) begin
                        data_out       <= data_in ^ keystream_buf[byte_idx];
                        data_out_valid <= 1'b1;
                        data_in_ready  <= 1'b0;

                        if (byte_idx == 6'd63) begin
                            state <= S_IDLE;
                        end else begin
                            byte_idx <= byte_idx + 1'b1;
                        end
                    end
                end
            endcase
        end
    end
endmodule