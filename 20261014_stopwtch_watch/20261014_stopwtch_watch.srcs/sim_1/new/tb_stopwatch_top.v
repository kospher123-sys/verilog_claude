`timescale 1ns / 1ps


module tb_stopwatch_top ();
    //10clk * 1mhz * 10
    parameter BD_PUSH_TIME = 10 * 10000;
    parameter MSEC = 1_000_000;

    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;

    reg clk, rst, btnR, btnU, btnL, btnD;
    reg sw_display_mode;
    wire [MSEC_BIT_WIDTH-1:0] msec;
    wire [SEC_BIT_WIDTH-1:0] sec;
    wire [MIN_BIT_WIDTH-1:0] min;
    wire [HOUR_BIT_WIDTH-1:0] hour;
    wire w_btnR, w_btnD;

    btn_debounce U_BD_RUN_STOP (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_btnR)
    );

    btn_debounce U_BD_CLEAR (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnD),
        .o_btn(w_btnD)
    );

    stopwatch DUT (
        .clk (clk),
        .rst (rst),
        .btnR(w_btnR),
        .btnL(btnL),
        .btnU(btnU),
        .btnD(w_btnD),
        .msec(msec),
        .sec (sec),
        .min (min),
        .hour(hour)
    );


    always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;
        btnR = 0;
        btnU = 0;
        btnL = 0;
        btnD = 0;
        sw_display_mode = 0;
        #10;
        rst  = 0;

        btnR = 1;
        repeat (BD_PUSH_TIME) @(posedge clk);
        btnR = 0;

        // repeat (10) #(MSEC * 10); 
        // btnR = 1;
        // repeat (BD_PUSH_TIME) @(posedge clk);
        // btnR = 0;

        repeat (10) #(MSEC * 10);


        DUT.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = 7'd99;
        DUT.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = 6'd59;
        DUT.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = 6'd59;
        DUT.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = 5'd23;

        // btnD = 1;
        // repeat (BD_PUSH_TIME) @(posedge clk);
        // btnD = 0;

        // repeat (5) #(MSEC * 10);


        //stop state


        #100;




        $stop;
    end




endmodule
