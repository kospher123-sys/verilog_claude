`timescale 1ns / 1ps


module uart (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] tx_data,
    output logic       tx_busy,
    output logic       tx
);

    logic b_tick;
    baud_tick U_BAUD_TICK (.*);

    uart_tx U_UART_TX (.*);


endmodule



module baud_tick (
    input  logic clk,
    input  logic rst,
    // input  logic enable,
    output logic b_tick
);

    parameter DIV_COUNT = 100_000_000 / (9600 * 16);
    logic [$clog2(DIV_COUNT)-1:0] counter;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            counter <= 0;
            b_tick  <= 0;
        end else begin
            // if (enable) begin
            if (counter == DIV_COUNT - 1) begin
                counter <= 0;
                b_tick  <= 1;
            end else begin
                counter <= counter + 1;
                b_tick  <= 0;
            end
            // end else begin
            //     counter <= 0;
            //     b_tick  <= 0;
            // end
        end
    end
endmodule

