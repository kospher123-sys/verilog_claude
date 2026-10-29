`timescale 1ns / 1ps

module tb_watch_datapath(

    );

    parameter BD_PUSH_TIME = 10 * 10_000;
    parameter MSEC = 100_000 * 10;
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH  = 6;
    parameter MIN_BIT_WIDTH  = 6;
    parameter HOUR_BIT_WIDTH = 5;

    reg clk, rst, btnR, btnU, btnL,btnD, setting;
    reg [MSEC_BIT_WIDTH -1:0] rst_msec;
    reg [SEC_BIT_WIDTH  -1:0] rst_sec;
    reg [MIN_BIT_WIDTH  -1:0] rst_min;
    reg [HOUR_BIT_WIDTH -1:0] rst_hour;

    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire [MSEC_BIT_WIDTH -1:0] msec;
    wire [SEC_BIT_WIDTH  -1:0] sec;
    wire [MIN_BIT_WIDTH  -1:0] min;
    wire [HOUR_BIT_WIDTH -1:0] hour;

// watch_datapath UDT (
//     .clk(clk),
//     .rst(rst),
//     .setting(setting),
//     .rst_msec(rst_msec),
//     .rst_sec(rst_sec),
//     .rst_min(rst_min),
//     .rst_hour(rst_hour),
//     .msec(msec),
//     .sec(sec),
//     .min(min),
//     .hour(hour)
// );

watch DUT(
    .clk(clk),
    .rst(rst),
    .btnR(btnR),
    .btnL(btnL),
    .btnU(btnU),
    .btnD(btnD),
    .sw_setting_mode(setting),
    // .sw_dsiplay_mode(),/
    .fnd_com(fnd_com),
    .fnd_font(fnd_font)

);



always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;
        btnR = 0;
        btnU = 0;
        btnL = 0;
        rst_msec = 0;
        rst_sec = 0;
        rst_min = 0;
        rst_hour = 0;
        setting = 0;

        #10;
        rst = 0;

        // btnR =1;
        repeat(BD_PUSH_TIME) @(posedge clk);
        // btnR=0


        // repeat (10) #(MSEC*10);
        

        setting = 1;



        btnD =1;
        repeat(BD_PUSH_TIME) @(posedge clk);
        btnD=0;

        setting = 0;


        // repeat(10) #(MSEC*10);

        // #(MSEC *10);



        // #(MSEC *10);

        // btnR =1;
        // repeat(BD_PUSH_TIME) @(posedge clk);
        // btnR=0;

        //stop state


        #100;
        $stop;
    end


endmodule

