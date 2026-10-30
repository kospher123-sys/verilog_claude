`timescale 1ns / 1ps



module watch_stopwatch (
    input        clk,
    input        rst,
    input        btnR,
    input        btnL,
    input        btnU,
    input        btnD,
    input        sw_setting_mode,
    input        sw_dsiplay_mode,
    input        sw_clock_mode,
    output [3:0] led,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;

    wire w_btnR_STW, w_btnL_STW, w_btnU_STW, w_btnD_STW;
    wire w_btnR_W, w_btnL_W, w_btnU_W, w_btnD_w;
    wire w_btnR, w_btnL, w_btnU, w_btnD;

    wire [MSEC_BIT_WIDTH -1:0] w_stw_msec, w_w_msec, w_o_msec;
    wire [SEC_BIT_WIDTH  -1:0] w_stw_sec, w_w_sec, w_o_sec;
    wire [MIN_BIT_WIDTH  -1:0] w_stw_min, w_w_min, w_o_min;
    wire [HOUR_BIT_WIDTH -1:0] w_stw_hour, w_w_hour, w_o_hour;

    wire [1:0] w_setting_state;

    assign led[0] = sw_clock_mode;
    assign led[1] = sw_dsiplay_mode;
    assign led[2] = sw_setting_mode;



// btn_debounce U_BD_R (
//         .clk  (clk),
//         .reset(rst),
//         .i_btn(btnR),
//         .o_btn(w_btnR)
//     );

//     btn_debounce U_BD_L (
//         .clk  (clk),
//         .reset(rst),
//         .i_btn(btnL),
//         .o_btn(w_btnL)
//     );

//     btn_debounce U_BD_U (
//         .clk  (clk),
//         .reset(rst),
//         .i_btn(btnU),
//         .o_btn(w_btnU)
//     );

//     btn_debounce U_BD_D (
//         .clk  (clk),
//         .reset(rst),
//         .i_btn(btnD),
//         .o_btn(w_btnD)
//     );

//     btn_block U_BTN_BLOCK (
//         .i_btnR(w_btnR),
//         .i_btnL(w_btnL),
//         .i_btnU(w_btnU),
//         .i_btnD(w_btnD),
//         .sw_clock_mode(sw_clock_mode),
//         .o_btnR_STW(w_btnR_STW),
//         .o_btnL_STW(w_btnL_STW),
//         .o_btnU_STW(w_btnU_STW),
//         .o_btnD_STW(w_btnD_STW),
//         .o_btnR_W(w_btnR_W),
//         .o_btnL_W(w_btnL_W),
//         .o_btnU_W(w_btnU_W),
//         .o_btnD_W(w_btnD_w)
//     );

    // watch U_WATCH (
    //     .clk            (clk),
    //     .rst            (rst),
    //     .btnR           (w_btnR_W),
    //     .btnL           (w_btnL_W),
    //     .btnU           (w_btnU_W),
    //     .btnD           (w_btnD_w),
    //     .sw_setting_mode(sw_setting_mode),
    //     .msec           (w_w_msec),
    //     .sec            (w_w_sec),
    //     .min            (w_w_min),
    //     .hour           (w_w_hour),
    //     .setting_state  (w_setting_state)
    // );



    stopwatch U_STOPWATCH (
        .clk (clk),
        .rst (rst),
        .btnR(w_btnR_STW),
        .btnL(w_btnL_STW),
        .btnU(w_btnU_STW),
        .btnD(w_btnD_STW),
        .led (led[3]),
        .msec(w_stw_msec),
        .sec (w_stw_sec),
        .min (w_stw_min),
        .hour(w_stw_hour)
    );



    fnd_mux_2x1 U_FND_MUX_2X1 (
        .sw_clock_mode(sw_clock_mode),
        .stw_msec(w_stw_msec),
        .stw_sec(w_stw_sec),
        .stw_min(w_stw_min),
        .stw_hour(w_stw_hour),
        .w_msec(w_w_msec),
        .w_sec(w_w_sec),
        .w_min(w_w_min),
        .w_hour(w_w_hour),
        .o_msec(w_o_msec),
        .o_sec(w_o_sec),
        .o_min(w_o_min),
        .o_hour(w_o_hour)
    );

    // fnd_controller U_FND_CNTL (
    //     .clk            (clk),
    //     .rst            (rst),
    //     .sw_dsiplay_mode(sw_dsiplay_mode),  // switch mesc_sec, min_hour
    //     .msec           (w_o_msec),
    //     .sec            (w_o_sec),
    //     .min            (w_o_min),
    //     .hour           (w_o_hour),
    //     .setting        (sw_setting_mode),
    //     .sw_clock_mode(sw_clock_mode),
    //     .setting_state  (w_setting_state),
    //     .fnd_com        (fnd_com),
    //     .fnd_font       (fnd_font)
    // );

endmodule

module btn_block (
    input i_btnR,
    input i_btnL,
    input i_btnU,
    input i_btnD,
    input sw_clock_mode,
    output reg o_btnR_STW,
    output reg o_btnL_STW,
    output reg o_btnU_STW,
    output reg o_btnD_STW,
    output reg o_btnR_W,
    output reg o_btnL_W,
    output reg o_btnU_W,
    output reg o_btnD_W
);

    always @(*) begin
        o_btnR_STW = 0;
        o_btnL_STW = 0;
        o_btnU_STW = 0;
        o_btnD_STW = 0;
        o_btnR_W   = 0;
        o_btnL_W   = 0;
        o_btnU_W   = 0;
        o_btnD_W   = 0;
        if (sw_clock_mode) begin
            o_btnR_STW = i_btnR;
            o_btnL_STW = i_btnL;
            o_btnU_STW = i_btnU;
            o_btnD_STW = i_btnD;
        end else begin
            o_btnR_W = i_btnR;
            o_btnL_W = i_btnL;
            o_btnU_W = i_btnU;
            o_btnD_W = i_btnD;
        end
    end
endmodule

module fnd_mux_2x1 #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input sw_clock_mode,
    input [MSEC_BIT_WIDTH -1:0] stw_msec,
    input [SEC_BIT_WIDTH  -1:0] stw_sec,
    input [MIN_BIT_WIDTH  -1:0] stw_min,
    input [HOUR_BIT_WIDTH -1:0] stw_hour,
    input [MSEC_BIT_WIDTH -1:0] w_msec,
    input [SEC_BIT_WIDTH  -1:0] w_sec,
    input [MIN_BIT_WIDTH  -1:0] w_min,
    input [HOUR_BIT_WIDTH -1:0] w_hour,
    output reg [MSEC_BIT_WIDTH -1:0] o_msec,
    output reg [SEC_BIT_WIDTH  -1:0] o_sec,
    output reg [MIN_BIT_WIDTH  -1:0] o_min,
    output reg [HOUR_BIT_WIDTH -1:0] o_hour
);

    always @(*) begin
        if (sw_clock_mode) begin
            o_msec = stw_msec;
            o_sec  = stw_sec;
            o_min  = stw_min;
            o_hour = stw_hour;
        end else begin
            o_msec = w_msec;
            o_sec  = w_sec;
            o_min  = w_min;
            o_hour = w_hour;
        end
    end


endmodule
