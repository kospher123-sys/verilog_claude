`timescale 1ns / 1ps
module tb_TOP ();

    parameter PUSH_TIME = 100*10;
    parameter mSEC = 100_000;

    reg        clk;
    reg        rst;
    reg        btnR;
    reg        btnL;
    reg        btnU;
    reg        btnD;
    reg        sw_setting_mode;
    reg        sw_dsiplay_mode;
    reg        sw_clock_mode;
    wire [3:0] led;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;


    watch_stopwatch DUT (
        .clk(clk),
        .rst(rst),
        .btnR(btnR),
        .btnL(btnL),
        .btnU(btnU),
        .btnD(btnD),
        .sw_setting_mode(sw_setting_mode),
        .sw_dsiplay_mode(sw_dsiplay_mode),
        .sw_clock_mode(sw_clock_mode),
        .led(led),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

    always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;
        btnR = 0;
        btnL = 0;
        btnU = 0;
        btnD = 0;
        sw_setting_mode = 0;
        sw_dsiplay_mode = 0;
        sw_clock_mode = 0;

        #10;

        rst = 0;
        sw_clock_mode = 1;

        #10 btnR=1;
        repeat (PUSH_TIME) @(posedge clk);
        btnR=0;

        repeat (mSEC*4)  @(posedge clk);

        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = 7'd97;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = 6'd59;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = 6'd59;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = 5'd23;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.o_tick = 1'b0;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.o_tick  = 1'b0;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.o_tick  = 1'b0;
        // DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.counter_reg = TICK_COUNT - 1;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.o_tick = 1'b0;
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.counter_reg
        = 1_000_000 - 1;

        wait (
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg == 0 &&
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg  == 0 &&
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg  == 0 &&
        DUT.U_STOPWATCH.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg == 0
    );
        @(negedge clk);

        // repeat (mSEC*100)  @(posedge clk); //10msec
        // #100;
        // sw_setting_mode=1;

        // repeat (mSEC*40)  @(posedge clk); //10msec

        // btnU=1;
        // repeat (PUSH_TIME) @(posedge clk);
        // btnU=0;
        
        // repeat (mSEC*100)  @(posedge clk); //10msec
        // #100;


        // btnL=1;
        // repeat (PUSH_TIME) @(posedge clk);
        // btnL=0;

        // repeat (mSEC*100)  @(posedge clk); //10msec
        // #100;


        // btnD=1;
        // repeat (PUSH_TIME) @(posedge clk);
        // btnD=0;

        // repeat (mSEC*100)  @(posedge clk); //10msec
        // #100;


        // btnR=1;
        // repeat (PUSH_TIME) @(posedge clk);
        // btnR=0;

        // repeat (mSEC*100)  @(posedge clk); //10msec
        // #100;
        // sw_setting_mode=0;

        // repeat (mSEC*10)  @(posedge clk); //10msec
        // #100;

        // repeat (PUSH_TIME) @(posedge clk);

        $stop;

    end

endmodule


























