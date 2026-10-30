`timescale 1ns / 1ps

// btn_lap must be a debounced, one-clock pulse.
module lap_time #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH = 6,
    parameter MIN_BIT_WIDTH = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input clear,
    input btn_lap,
    input sw_lap_display,  // 추가: SW3
    input [MSEC_BIT_WIDTH-1:0] msec,
    input [SEC_BIT_WIDTH-1:0] sec,
    input [MIN_BIT_WIDTH-1:0] min,
    input [HOUR_BIT_WIDTH-1:0] hour,
    output [MSEC_BIT_WIDTH-1:0] display_msec,
    output [SEC_BIT_WIDTH-1:0] display_sec,
    output [MIN_BIT_WIDTH-1:0] display_min,
    output [HOUR_BIT_WIDTH-1:0] display_hour
);
    // Save all four time fields together. Counting continues independently.
    reg lap_valid;
    reg [MSEC_BIT_WIDTH-1:0] lap_msec;
    reg [SEC_BIT_WIDTH-1:0] lap_sec;
    reg [MIN_BIT_WIDTH-1:0] lap_min;
    reg [HOUR_BIT_WIDTH-1:0] lap_hour;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lap_valid <= 1'b0;
            lap_msec <= 0;
            lap_sec <= 0;
            lap_min <= 0;
            lap_hour <= 0;
        end else if (clear) begin
            lap_valid <= 1'b0;
            lap_msec <= 0;
            lap_sec <= 0;
            lap_min <= 0;
            lap_hour <= 0;
        end else if (btn_lap) begin
            lap_valid <= 1'b1;
            lap_msec <= msec;
            lap_sec <= sec;
            lap_min <= min;
            lap_hour <= hour;
        end
    end

    wire show_lap;

    assign show_lap = lap_valid && sw_lap_display;

    assign display_msec = show_lap ? lap_msec : msec;
    assign display_sec  = show_lap ? lap_sec  : sec;
    assign display_min  = show_lap ? lap_min  : min;
    assign display_hour = show_lap ? lap_hour : hour;

endmodule
