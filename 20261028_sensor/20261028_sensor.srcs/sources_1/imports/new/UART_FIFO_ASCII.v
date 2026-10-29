`timescale 1ns / 1ps

module UART_FIFO_ASCII (
    input        clk,
    input        rst,
    input        rx,
    input        echo,
    output       trig,
    output       tx,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);


    wire [7:0] w_rx_pop_data;
    wire       w_rx_empty;
    wire [3:0] w_bin;
    wire       w_rx_pop;

    wire       w_run_stop;
    wire       w_clear;
    wire       w_mode;
    wire       w_status;
    wire [8:0] w_distance;


    uart_loopback_FIFO U_UART_LOOPBACK_FIFO (
        .clk         (clk),
        .rst         (rst),
        .rx          (rx),
        .rx_pop_data (w_rx_pop_data),
        .rx_fifo_pop (w_rx_pop),
        .tx_uart_data(w_bin),
        .rx_empty    (w_rx_empty),
        .tx          (tx)
    );

    ascii_decorder_key U_ASCII_DECORDER_KEY (
        .clk   (clk),
        .rst   (rst),
        .enable(w_rx_empty),
        .pop   (w_rx_pop),
        .ascii (w_rx_pop_data),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(w_mode),
        .status(w_status)
    );

    SR04_MASTER U_SR04_MASTER (
        .clk(clk),
        .rst(rst),
        .sr04_start(w_run_stop),
        .echo(echo),
        .trig(trig),
        .distance(w_distance)
    );

    ascii_decorder U_ASCII_DECORDER (
        .clk(clk),
        .rst(rst),
        .enable(1'b1),
        .ascii(w_distance),
        .pop(),
        .bin(w_bin)
    );

    fnd_controller U_FND_CONTROLLER (
        .clk     (clk),
        .reset   (rst),
        .fnd_data(w_bin),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );


endmodule



module baud_tick_gen_framecount (
    input clk,
    input rst,
    output reg b_tick
);

    //1frame tick, 10 baud time
    parameter F_COUNT = (100_000_000 * 10) / 9600;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick      <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            b_tick <= 0;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1;
            end
        end
    end

endmodule

