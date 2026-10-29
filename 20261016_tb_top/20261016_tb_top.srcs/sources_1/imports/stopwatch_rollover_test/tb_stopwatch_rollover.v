`timescale 1ns / 1ps

module tb_stopwatch_rollover;
    // 테스트에서만 분주값을 줄인다. 실제 stopwatch 기본값은 1,000,000 유지.
    localparam TICK_COUNT = 4;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btnR = 1'b0;
    reg btnL = 1'b0;
    reg btnU = 1'b0;
    reg btnD = 1'b0;

    wire led;
    wire [6:0] msec;
    wire [5:0] sec;
    wire [5:0] min;
    wire [4:0] hour;

    stopwatch #(.TICK_COUNT(TICK_COUNT)) dut (
        .clk(clk), .rst(rst),
        .btnR(btnR), .btnL(btnL), .btnU(btnU), .btnD(btnD),
        .led(led), .msec(msec), .sec(sec), .min(min), .hour(hour)
    );

    always #5 clk = ~clk; // 100MHz equivalent test clock (10ns period)

    initial begin
        $display("time(ns) | hour:min:sec:msec");
        $monitor("%0t | %02d:%02d:%02d:%02d", $time, hour, min, sec, msec);

        // Reset 해제 후 Run 버튼을 눌러 스톱워치를 실행 상태로 만든다.
        #22 rst = 1'b0;
        @(negedge clk); btnR = 1'b1;
        @(negedge clk); btnR = 1'b0;
        repeat (2) @(negedge clk);

        // 내부 카운터를 최댓값으로 설정해 긴 카운트 과정을 생략한다.
        // 다음 분주 틱 이후 밀리초 -> 초 -> 분 -> 시 순서로 자리 올림을 확인한다.
        dut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.counter_reg = 7'd99;
        dut.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.counter_reg  = 6'd59;
        dut.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.counter_reg  = 6'd59;
        dut.U_STOPWATCH_DATAPATH.U_HOUR_COUNTER.counter_reg = 5'd23;
        dut.U_STOPWATCH_DATAPATH.U_MSEC_COUNTER.o_tick = 1'b0;
        dut.U_STOPWATCH_DATAPATH.U_SEC_COUNTER.o_tick  = 1'b0;
        dut.U_STOPWATCH_DATAPATH.U_MIN_COUNTER.o_tick  = 1'b0;
        dut.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.counter_reg = TICK_COUNT - 1;
        dut.U_STOPWATCH_DATAPATH.U_TICK_GEN_100HZ.o_tick = 1'b0;

        $display("\n[CHECK] Starting from 24:59:59:99; waiting for rollover...\n");

        // registered carry가 각 자릿수로 전달되므로 몇 클럭 동안 중간 상태가 나타날 수 있다.
        wait (hour == 0 && min == 0 && sec == 0 && msec == 0);
        @(negedge clk);
        $display("\n[PASS] Rollover reached 00:00:00:00 at %0t ns", $time);
        $finish;
    end


endmodule
