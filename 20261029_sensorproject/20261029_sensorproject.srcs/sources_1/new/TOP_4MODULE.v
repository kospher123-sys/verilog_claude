`timescale 1ns / 1ps


module TOP_4MODULE (
    input clk,
    input rst,

    input rx,
    input sw_dsiplay_mode,  //sw[0]
    input sw_setting,       //sw[1]

    input btnR,
    input btnL,
    input btnU,
    input btnD,
    input sw_mode1,
    input sw_mode2,
    input sw_mode3,
    input sw_mode4,

    // output [3:0] led,

    input  echo,
    output trig,

    inout dht11_io,

    output [3:0] fnd_com,
    output [7:0] fnd_font,
    output tx

);
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;

    wire w_btn_R, w_btn_L, w_btn_U, w_btn_D, w_sw_mode1, w_sw_mode2, w_sw_mode3, w_sw_mode4;
    wire w_asciiR, w_asciiL, w_asciiU, w_asciiD, w_ascii_mode1, w_ascii_mode2, w_ascii_mode3, w_ascii_mode4;
    wire w_R, w_L, w_U, w_D, w_mode1, w_mode2, w_mode3, w_mode4;

    wire [MSEC_BIT_WIDTH -1:0] w_stw_msec, w_w_msec, w_o_msec;
    wire [SEC_BIT_WIDTH  -1:0] w_stw_sec, w_w_sec, w_o_sec;
    wire [MIN_BIT_WIDTH  -1:0] w_stw_min, w_w_min, w_o_min;
    wire [HOUR_BIT_WIDTH -1:0] w_stw_hour, w_w_hour, w_o_hour;

    wire w_enable, w_enable_sr04, w_enable_dht11;
    assign w_enable = w_enable_dht11 | w_enable_sr04;

    wire [1:0] w_setting_state;
    wire w_b_tick;
    wire baud_tick;

    wire [8:0] w_distance;
    wire [7:0] w_humidity, w_temperature;

    wire [7:0] w_msec;
    wire [7:0] w_sec;
    wire [7:0] w_min;
    wire [7:0] w_hour;

    wire [3:0] w_msec_ds1;
    wire [3:0] w_msec_ds10;
    wire [3:0] w_sec_ds1;
    wire [3:0] w_sec_ds10;
    wire [3:0] w_min_ds1;
    wire [3:0] w_min_ds10;
    wire [3:0] w_hour_ds1;
    wire [3:0] w_hour_ds10;


    btn_debouce_block U_BTN_DEBOUNCE_BLOCK (
        .clk (clk),
        .rst (rst),
        .btnR(btnR),
        .btnL(btnL),
        .btnU(btnU),
        .btnD(btnD),

        .btnR_tick(w_btn_R),
        .btnL_tick(w_btn_L),
        .btnU_tick(w_btn_U),
        .btnD_tick(w_btn_D)

    );


    baud_tick_gen_datastate U_BAUDTICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(baud_tick)
    );

    RX_ASCII_DECORDER U_RX_ASCII_DECORDER (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(baud_tick),

        .btnR(w_asciiR),
        .btnL(w_asciiL),
        .btnU(w_asciiU),
        .btnD(w_asciiD),
        .mode1(w_ascii_mode1),
        .mode2(w_ascii_mode2),
        .mode3(w_ascii_mode3),
        .mode4(w_ascii_mode4)
    );


    btn_or_ascii U_BTN_OR_ASCII (
        .clk(clk),
        .rst(rst),
        .btn_R(w_btn_R),
        .btn_L(w_btn_L),
        .btn_U(w_btn_U),
        .btn_D(w_btn_D),
        .sw_mode1(sw_mode1),
        .sw_mode2(sw_mode2),
        .sw_mode3(sw_mode3),
        .sw_mode4(sw_mode4),
        .ascii_R(w_asciiR),
        .ascii_L(w_asciiL),
        .ascii_U(w_asciiU),
        .ascii_D(w_asciiD),
        .ascii_mode1(w_ascii_mode1),
        .ascii_mode2(w_ascii_mode2),
        .ascii_mode3(w_ascii_mode3),
        .ascii_mode4(w_ascii_mode4),

        .btnR_tick(w_R),
        .btnL_tick(w_L),
        .btnU_tick(w_U),
        .btnD_tick(w_D),
        .mode1(w_mode1),
        .mode2(w_mode2),
        .mode3(w_mode3),
        .mode4(w_mode4)
    );  //각 모듈로 연결할땐 버튼4개랑 & mode1 연산으로 넣기 + mode로 FND 셀렉



    watch U_WATCH (
        .clk(clk),
        .rst(rst),
        .btnR(w_R & w_mode1),
        .btnL(w_L & w_mode1),
        .btnU(w_U & w_mode1),
        .btnD(w_D & w_mode1),
        .sw_setting_mode(sw_setting & w_mode1),
        .msec(w_w_msec),
        .sec(w_w_sec),
        .min(w_w_min),
        .hour(w_w_hour),
        .setting_state  (w_setting_state) //세팅중을 알리는 신호 -> fnd_controll
    );


    stopwatch U_STOPWATCH (
        .clk (clk),
        .rst (rst),
        .btnR(w_R & w_mode2),
        .btnL(w_L & w_mode2),
        .btnU(w_U & w_mode2),
        .btnD(w_D & w_mode2),
        // .led (led[3]),
        .msec(w_stw_msec),
        .sec (w_stw_sec),
        .min (w_stw_min),
        .hour(w_stw_hour)
    );

    tick_gen_us_sr04 U_TICK_GEN_US (
        .clk(clk),
        .rst(rst),
        .enable(w_enable),
        .b_tick(w_b_tick)
    );


    controll_unit_sr04 U_CONTROLL_SR04UNIT (
        .clk(clk),
        .rst(rst),
        .start(w_R & w_mode3),
        .echo(echo),
        .b_tick(w_b_tick),
        .enable(w_enable_sr04),
        .trig(trig),
        .distance(w_distance)
    );

    dht11_controller U_DHT11_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .dht11_start(w_R & w_mode4),
        .us_tick(w_b_tick),
        .enable(w_enable_dht11),
        .valid(),  //valid 어따씀;;
        .humidity(w_humidity),
        .temperature(w_temperature),
        .dht11_io(dht11_io)
    );


    fnd_mode_mux U_FND_MODE_MUX (
        .clk(clk),
        .rst(rst),
        .mode({w_mode1, w_mode2, w_mode3, w_mode4}),
        .wtc_msec(w_w_msec),
        .wtc_sec(w_w_sec),
        .wtc_min(w_w_min),
        .wtc_hour(w_w_hour),

        .stw_msec(w_stw_msec),
        .stw_sec (w_stw_sec),
        .stw_min (w_stw_min),
        .stw_hour(w_stw_hour),

        .distance(w_distance),
        .HM_TP({w_humidity, w_temperature}),

        .msec(w_msec),
        .sec (w_sec),
        .min (w_min),
        .hour(w_hour)
    );


    fnd_controller U_FND_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .sw_dsiplay_mode(sw_dsiplay_mode),
        .msec(w_msec),
        .sec(w_sec),
        .min(w_min),
        .hour(w_hour),
        .setting_state(w_setting_state),
        .setting(sw_setting),
        .mode({w_mode1, w_mode2, w_mode3, w_mode4}),
        .w_msec_ds1(w_msec_ds1),
        .w_msec_ds10(w_msec_ds10),
        .w_sec_ds1(w_sec_ds1),
        .w_sec_ds10(w_sec_ds10),
        .w_min_ds1(w_min_ds1),
        .w_min_ds10(w_min_ds10),
        .w_hour_ds1(w_hour_ds1),
        .w_hour_ds10(w_hour_ds10),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );





    tx_sender U_TX_SENDER (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick),
        .w_msec_ds1(w_msec_ds1),
        .w_msec_ds10(w_msec_ds10),
        .w_sec_ds1(w_sec_ds1),
        .w_sec_ds10(w_sec_ds10),
        .w_min_ds1(w_min_ds1),
        .w_min_ds10(w_min_ds10),
        .w_hour_ds1(w_hour_ds1),
        .w_hour_ds10(w_hour_ds10),
        .tx(tx)
    );


endmodule
