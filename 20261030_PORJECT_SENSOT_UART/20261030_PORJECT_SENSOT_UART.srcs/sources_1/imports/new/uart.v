`timescale 1ns / 1ps

module uart_fifo_loopback (
    input clk,
    input rst,
    input fifo_rx_pop,
    input rx,           // from PC

    input        fifo_tx_push,
    input  [7:0] fifo_tx_push_data,
    output       fifo_tx_full,
    output       tx,                 //to pc
    output [7:0] rx_pop_data,
    output       rx_empty
);
    wire w_b_tick;
    wire w_rx_done;
    wire [7:0] w_rx_data, w_fifo_rx_pop_data, w_fifo_tx_pop_data;
    wire w_fifo_tx_full, w_fifo_rx_empty, w_fifo_tx_empty, w_tx_busy;

    assign rx_pop_data = w_fifo_rx_pop_data;
    assign rx_empty = ~w_fifo_rx_empty;
    assign fifo_tx_full = w_fifo_tx_full;
    wire w_tx_start;
    reg  tx_start_hold_reg;

    assign w_tx_start = !w_fifo_tx_empty && !w_tx_busy && !tx_start_hold_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_start_hold_reg <= 1'b0;
        end else begin
            if (w_tx_start) tx_start_hold_reg <= 1'b1;
            else if (w_tx_busy) tx_start_hold_reg <= 1'b0;
        end
    end
    // uart rx
    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick),
        .rx(rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)

    );
    fifo #(
        .DEPTH(16)
    ) U_FIFO_RX (
        .clk      (clk),
        .rst      (rst),
        .push     (w_rx_done),           //from integrated ASCII Sender
        .pop      (fifo_rx_pop),
        .push_data(w_rx_data),
        .pop_data (w_fifo_rx_pop_data),
        .full     (),
        .empty    (w_fifo_rx_empty)
    );

    fifo U_FIFO_TX (
        .clk      (clk),
        .rst      (rst),
        .push     (fifo_tx_push),        //from integrated ASCII Sender
        .pop      (w_tx_start),
        .push_data(fifo_tx_push_data),
        .pop_data (w_fifo_tx_pop_data),
        .full     (w_fifo_tx_full),
        .empty    (w_fifo_tx_empty)
    );


    //uart TX
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_tx_start),
        .tx_data(w_fifo_tx_pop_data),
        .b_tick(w_b_tick),
        .tx(tx),
        .tx_busy(w_tx_busy)
    );



    baud_tick_gen U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule



module baud_tick_gen (
    input      clk,
    input      rst,
    output reg b_tick
);
    //100MHz -> 9600Hz
    parameter F_COUNT = 100_000_000 / (9600 * 16);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin

            counter_reg <= counter_reg + 1;

            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end


endmodule


