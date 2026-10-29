`timescale 1ns / 1ps


module uart_loopback_FIFO (
    input  clk,
    input  rst,
    input  rx,
    output tx
);
    parameter DEPTH = 4, A_BIT_WIDTH = $clog2(DEPTH), D_BIT_WIDTH = 8;
    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data, w_rx_pop_data, w_tx_pop_data;

    wire w_tx_empty, w_tx_full, tx_busy;
    wire w_rx_empty;


    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .rx     (rx),
        .b_tick (w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    fifo #(
        .DEPTH(DEPTH),
        .D_BIT_WIDTH(D_BIT_WIDTH)
    ) U_FIFO_RX (
        .clk(clk),
        .rst(rst),
        .push(w_rx_done),
        .pop(~w_tx_full),
        .push_data(w_rx_data),
        .pop_data(w_rx_pop_data),
        .full(),
        .empty(w_rx_empty)
    );

    fifo #(
        .DEPTH(DEPTH),
        .D_BIT_WIDTH(D_BIT_WIDTH)
    ) U_FIFO_TX (
        .clk(clk),
        .rst(rst),
        .push(~w_rx_empty),
        .pop(~tx_busy),
        .push_data(w_rx_pop_data),
        .pop_data(w_tx_pop_data),
        .full(w_tx_full),
        .empty(w_tx_empty)
    );

    uart_tx_datastate U_UART_TX (
        .clk  (clk),
        .rst   (rst),
        .tx_start(~w_tx_empty),
        .tx_data(w_tx_pop_data),
        .b_tick  (w_b_tick),
        .tx  (tx),
        .tx_busy (tx_busy)
    );


    baud_tick_gen_datastate U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );
endmodule
