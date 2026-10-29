`timescale 1ns / 1ps

module UART_FIFO_ASCII (
    input        clk,
    input        rst,
    input        rx,
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

    uart_loopback_FIFO U_UART_LOOPBACK_FIFO (
        .clk        (clk),
        .rst        (rst),
        .rx         (rx),
        .rx_pop_data(w_rx_pop_data),
        .rx_fifo_pop(w_rx_pop),
        .rx_empty   (w_rx_empty),
        .tx         (tx)
    );

    ascii_decorder U_ASCII_DECORDER (
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

    fnd_controller U_FND_CONTROLLER (
        .clk     (clk),
        .reset   (rst),
        .fnd_data(w_bin),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );


endmodule

module ascii_sender (
    input clk,
    input rst,
    input status,
    input [23:0] in_data,  //{hour, min, sec, msec} - value not a bit
    input b_tick,
    output reg push,
    output reg [7:0] out_data
);

    localparam IDLE = 1'b0, SEND = 1'b1;
    reg c_state, n_state;
    reg [6:0] data0 = in_data[6:0];  //msec ~99
    reg [5:0] data1 = in_data[12:7];  //sec ~59
    reg [5:0] data2 = in_data[18:13];  //min ~59
    reg [4:0] data3 = in_data[23:19];  //hour ~23

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        n_state = c_state;
        push = 0;
        out_data = 0;
        if (b_tick) begin
            case (c_state)
                SEND: begin
                        
                        out_data = ;
                        push = 1;
                    end
                IDLE: begin
                    if (status) n_state = SEND;
                end
            endcase
        end
    end

endmodule

module mux_4x1(
    
);
// 먹스로 데이터 4개중 1나 순서대로 출력하기
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

