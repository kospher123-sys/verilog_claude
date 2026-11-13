`timescale 1ns / 1ps

module uart(

);

endmodule

module uart_tx_top (
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx_busy,
    output logic       tx
);

    logic w_b_tick;
    logic w_enable;

    uart_tx_sv U_UART_TX_SV (
        .*,
        .b_tick(w_b_tick),
        .enable(w_enable)

    );

    uart_tx_tick_gen U_UART_TX_TICK_GEN (
        .*,
        .enable(w_enable),
        .b_tick(w_b_tick)
    );

endmodule

module uart_tx_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic       b_tick,
    input  logic [7:0] tx_data,
    output logic       tx_busy,
    output logic       enable,
    output logic       tx
);
    parameter IDLE = 0, START = 1, DATA = 2, STOP = 3;
    logic [1:0] c_state, n_state;
    logic busy_next, tx_next, enable_next;

    logic [$clog2(16)-1:0] b_tick_cnt, b_tick_cnt_next;
    logic [$clog2(8)-1:0] bit_cnt, bit_cnt_next;
    logic [7:0] send_data, send_data_next;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state    <= IDLE;
            tx_busy    <= 0;
            tx         <= 1;
            b_tick_cnt <= 0;
            bit_cnt    <= 0;
            send_data  <= 0;
        end else begin
            c_state    <= n_state;
            tx_busy    <= busy_next;
            tx         <= tx_next;
            b_tick_cnt <= b_tick_cnt_next;
            bit_cnt    <= bit_cnt_next;
            send_data  <= send_data_next;
        end
    end

    always_comb begin
        n_state         = c_state;
        busy_next       = tx_busy;
        tx_next         = tx;

        b_tick_cnt_next = b_tick_cnt;
        bit_cnt_next    = bit_cnt;
        send_data_next  = send_data;

        case (c_state)
            IDLE: begin
                tx_next = 1;
                busy_next = 0;
                enable = 0;
                if (tx_start) begin
                    n_state = START;
                    busy_next = 1;
                    b_tick_cnt_next = 0;
                    send_data_next = tx_data;
                end
            end
            START: begin
                tx_next   = 0;
                busy_next = 1;
                enable    = 1;
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
                tx_next   = send_data[0];
                busy_next = 1;
                enable    = 1;
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        bit_cnt_next = bit_cnt + 1;
                        b_tick_cnt_next = 0;
                        if (bit_cnt == 7) begin
                            n_state = STOP;
                            bit_cnt_next = 0;
                        end else send_data_next = {1'b0, send_data[7:1]};
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
            STOP: begin
                tx_next   = 1;
                busy_next = 1;
                enable    = 1;
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        n_state = IDLE;
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        busy_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
        endcase
    end
endmodule

module uart_tx_tick_gen (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    output logic b_tick
);

    parameter F_COUNT = 100_000_000 / (9600 * 16);
    logic [$clog2(F_COUNT)-1:0] clk_counter;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            clk_counter <= 0;
            b_tick <= 0;
        end else begin
            if (enable) begin
                if (clk_counter == F_COUNT - 1) begin
                    clk_counter <= 0;
                    b_tick <= 1;
                end else begin
                    clk_counter <= clk_counter + 1;
                    b_tick <= 0;
                end
            end else begin
                clk_counter <= 0;
                b_tick <= 0;
            end
        end
    end
endmodule
