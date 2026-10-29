`timescale 1ns / 1ps

module uart_ascii_fnd (
    input clk,
    input rst,
    input rx,
    output tx,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);
    wire w_rx_done;
    wire [7:0] w_rx_data;
    wire [4:0] w_fnd_data;

    uart U_UART (
        .clk(clk),
        .rst(rst),
        .rx   (rx),
        .tx   (tx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    ascii_decorder U_ASCII_DECORDER (
        .rx_data (w_rx_data),
        .rx_done (w_rx_done),
        .fnd_data(w_fnd_data)
    );


    fnd_controller U_FND_CONTROLLER (
        .clk   (clk),
        .rst(rst),
        .fnd_data(w_fnd_data),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

endmodule
