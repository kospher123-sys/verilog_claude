`timescale 1ns / 1ps


module sr04_top #(
    parameter integer MIN_PERIOD_US = 60_000
) (
    input clk,
    input rst,
    input start,
    input echo,
    output trigger,
    output [8:0] distance,
    output [2:0] debug_state
);

    wire w_us_tick;
    wire w_enable;
    wire w_clear;



    SR04_sensor #(
        .MIN_PERIOD_US(MIN_PERIOD_US),
        .CLOCKS_PER_US(100)
    ) U_SR04_SENSOR (
        .clk(clk),
        .start(start),
        .rst(rst),
        .us_tick(w_us_tick),
        .echo(echo),
        .trigger(trigger),
        .enable(w_enable),
        .clear(w_clear),
        .distance(distance),
        .debug_state(debug_state)
    );

    baud_tick_gen_sr04 #(
        .F_COUNT(100)
    ) U_BAUD_TICK_GEN_SR04 (
        .clk(clk),
        .rst(rst),
        .enable(w_enable),
        .clear(w_clear),
        .b_tick(w_us_tick)


    );
endmodule
