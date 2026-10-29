`timescale 1ns / 1ps

module uart (
    input  clk,
    input  rst,
    input  rx,   //from PC
    output tx    //to PC
);

    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data;


    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .rx     (rx),
        .b_tick (w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    uart_tx_datastate U_UART_TX (
        .clk  (clk),
        .rst   (rst),
        .tx_start(w_rx_done),
        .tx_data(w_rx_data),
        .b_tick  (w_b_tick),
        .tx  (tx)
    );


    baud_tick_gen_datastate U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );



endmodule
