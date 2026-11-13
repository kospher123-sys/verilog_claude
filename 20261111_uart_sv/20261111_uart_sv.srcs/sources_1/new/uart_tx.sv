`timescale 1ns / 1ps

module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic       b_tick,
    input  logic [7:0] tx_data,
    output logic       tx_busy,
    // output logic       enable,
    output logic       tx
);
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_e;
    state_e c_state, n_state;

    logic busy_next, tx_next, enable_next;

    logic [$clog2(16)-1:0] b_tick_cnt, b_tick_cnt_next;
    logic [$clog2(8)-1:0] bit_cnt, bit_cnt_next;
    logic [7:0] data_reg, data_next;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state    <= IDLE;
            tx         <= 1'b1;
            tx_busy    <= 1'b0;
            data_reg   <= 0;
            bit_cnt    <= 0;
            b_tick_cnt <= 0;
        end else begin
            c_state    <= n_state;
            tx         <= tx_next;
            tx_busy    <= busy_next;
            data_reg   <= data_next;
            bit_cnt    <= bit_cnt_next;
            b_tick_cnt <= b_tick_cnt_next;
        end
    end

    always_comb begin
        n_state         = c_state;
        tx_next         = tx;
        busy_next       = tx_busy;
        data_next       = data_reg;
        bit_cnt_next    = bit_cnt;
        b_tick_cnt_next = b_tick_cnt;

        case (c_state)
            IDLE: begin
                tx_next = 1;
                busy_next = 0;
                // enable = 0;
                if (start) begin
                    n_state = START;
                    data_next = tx_data;
                    bit_cnt_next = 0;
                    b_tick_cnt_next = 0;
                    busy_next = 1;
                end
            end
            START: begin
                tx_next = 0;
                // enable  = 1;
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];

                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt == 7) begin  //왜 8이 아닐까 ㅠㅠ
                            bit_cnt_next = 0;
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt + 1;
                            data_next = {1'b0, data_reg[7:1]};
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;

                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        busy_next = 0;
                        n_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
        endcase
    end
endmodule
