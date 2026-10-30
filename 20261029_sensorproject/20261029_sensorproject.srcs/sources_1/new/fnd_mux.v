`timescale 1ns / 1ps
module fnd_mode_mux #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input       clk,
    input       rst,
    input [3:0] mode,

    input [MSEC_BIT_WIDTH-1:0] wtc_msec,
    input [ SEC_BIT_WIDTH-1:0] wtc_sec,
    input [ MIN_BIT_WIDTH-1:0] wtc_min,
    input [HOUR_BIT_WIDTH-1:0] wtc_hour,

    input [MSEC_BIT_WIDTH-1:0] stw_msec,
    input [ SEC_BIT_WIDTH-1:0] stw_sec,
    input [ MIN_BIT_WIDTH-1:0] stw_min,
    input [HOUR_BIT_WIDTH-1:0] stw_hour,

    input [8:0] distance,

    input [15:0] HM_TP,

    output reg [7:0] msec,
    output reg [7:0] sec,
    output reg [7:0] min,
    output reg [7:0] hour
);

    wire [7:0] w_distance_msec;
    wire [7:0] w_distance_sec;
    wire [7:0] w_distance_min;
    wire [7:0] w_distance_hour;



    always @(*) begin
        case (mode)
            4'b1000: begin  //wtc
                msec = wtc_msec;
                sec  = wtc_sec;
                min  = wtc_min;
                hour = wtc_hour;  //0~23
            end
            4'b0100: begin  //stw
                msec = stw_msec;
                sec  = stw_sec;
                min  = stw_min;
                hour = stw_hour;  //0~23
            end
            4'b0010: begin  //sr04
                msec = w_distance_msec;
                sec  = w_distance_sec;
                min  = w_distance_min;
                hour = w_distance_hour;
            end
            4'b001: begin  //hm_tp
                msec = 0;
                sec  = 0;
                min  = 0;
                hour = 0;
            end
            default: begin
                msec = 0;
                sec  = 0;
                min  = 0;
                hour = 0;
            end
        endcase
    end
endmodule



module distance_splitter_4places (
    input [13:0] dsin,
    output [7:0] ds_msec,
    output [7:0] ds_sec,
    output [7:0] ds_min,
    output [7:0] ds_hour
);

    assign ds_msec = dsin % 100;
    assign ds_sec  = (dsin / 100) % 10;

    assign ds_min  = ;
    assign ds_hour = ;

endmodule

module hm_tp_splitter_4places (
    input [13:0] dsin,
    output [7:0] ds_msec,
    output [7:0] ds_sec,
    output [7:0] ds_min,
    output [7:0] ds_hour
);

    assign ds_msec = dsin % 100;
    assign ds_sec  = (dsin / 100) % 100;
    assign ds_min  = (dsin / 10000) % 100;
    assign ds_hour = (dsin / 1000000) % 100;

endmodule
