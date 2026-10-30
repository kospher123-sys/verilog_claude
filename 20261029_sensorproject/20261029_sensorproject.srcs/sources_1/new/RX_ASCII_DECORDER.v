`timescale 1ns / 1ps


module RX_ASCII_DECORDER(
    input clk,
    input rst,
    input rx,
    input b_tick,
    output btnR,
    output btnL,
    output btnU,
    output btnD,
    output mode1,
    output mode2,
    output mode3,
    output mode4
    );

    parameter DEPTH = 4, A_BIT_WIDTH = $clog2(DEPTH), D_BIT_WIDTH = 8;
    wire  w_rx_done, w_rx_pop;
    wire       w_rx_empty;
    wire [7:0] w_rx_data, w_rx_pop_data;

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .rx     (rx),
        .b_tick (b_tick),
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
        .pop(w_rx_pop),
        .push_data(w_rx_data),
        .pop_data(w_rx_pop_data),
        .full(),
        .empty(w_rx_empty)
    );


    ascii_decorder U_ASCII_DECORDER (
        .clk   (clk),
        .rst   (rst),
        .enable(~w_rx_empty),
        .pop   (w_rx_pop),
        .ascii (w_rx_pop_data),
        .run_stop(btnR),
        .clear(btnL),
        .mode(btnU),
        .status(btnD),
        .mode1(mode1),
        .mode2(mode2),
        .mode3(mode3),
        .mode4(mode4)
    );






endmodule
