`timescale 1ns / 1ps

// sr04_top 시뮬레이션 시나리오
//  TC1 리셋 직후 IDLE
//  TC2 정상 측정 10cm  (trigger 폭 10us 이상 확인 포함)
//  TC3 정상 측정 100cm / 399cm
//  TC4 측정 중 start 재입력 -> 무시
//  TC5 60ms 이내 start 재입력 -> 무시 (최소 측정 주기)
//  TC6 echo 무응답 -> WAIT 36ms 타임아웃 -> distance 0
//  TC7 물체 없음(echo 38ms) -> DISTANCE 36ms 타임아웃 -> distance 0
//  TC8 echo가 high로 붙어 있으면 start 거부
module tb_sr04_top ();

    localparam IDLE = 3'd0, START = 3'd1, WAIT = 3'd2, DISTANCE = 3'd3, STOP = 3'd4;
    localparam ECHO_DELAY_US = 200;  // trigger 하강 후 echo 상승까지 (센서 버스트 시간)

    reg clk, rst, start, echo;
    wire trigger;
    wire [8:0] distance;
    wire [2:0] debug_state;

    integer pass_cnt = 0, fail_cnt = 0;
    time t_trig_rise, trig_width;

    sr04_top #(
        .MIN_PERIOD_US(60_000)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .echo(echo),
        .trigger(trigger),
        .distance(distance),
        .debug_state(debug_state)
    );

    always #5 clk = ~clk;  // 100MHz

    // trigger 폭 측정
    always @(posedge trigger) t_trig_rise = $time;
    always @(negedge trigger) trig_width = $time - t_trig_rise;

    task check(input [255:0] name, input [8:0] got, input [8:0] exp);
        begin
            if (got === exp) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS] %0s : got=%0d exp=%0d (t=%0t)", name, got, exp, $time);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL] %0s : got=%0d exp=%0d (t=%0t)", name, got, exp, $time);
            end
        end
    endtask

    // 버튼/UART 명령처럼 1클럭 펄스
    task press_start;
        begin
            @(negedge clk) start = 1;
            @(negedge clk) start = 0;
        end
    endtask

    // 센서 모델: trigger 끝나고 ECHO_DELAY_US 후 echo_us 동안 high
    task sensor_echo(input integer echo_us);
        begin
            @(negedge trigger);
            #(ECHO_DELAY_US * 1000);
            echo = 1;
            #(echo_us * 1000);
            echo = 0;
        end
    endtask

    // 측정 한 번: start -> echo -> STOP -> IDLE 까지 기다린 뒤 결과 확인
    task measure(input [255:0] name, input integer echo_us, input [8:0] exp_cm);
        begin
            press_start;
            sensor_echo(echo_us);
            wait (debug_state == IDLE);
            check(name, distance, exp_cm);
        end
    endtask

    // 다음 측정 전 60ms 주기 보장
    task wait_period;
        #(61_000_000);
    endtask

    initial begin
        $timeformat(-6, 2, " us", 12);
        clk = 0; rst = 1; start = 0; echo = 0;
        #100 rst = 0;

        // TC1 리셋 직후
        #100;
        check("TC1 reset state", debug_state, IDLE);
        check("TC1 reset distance", distance, 0);
        check("TC1 reset trigger", trigger, 0);

        // TC2 10cm = 580us
        measure("TC2 10cm", 10 * 58, 10);
        check("TC2 trigger>=10us", (trig_width >= 10_000), 1);
        $display("       trigger width = %0t", trig_width);

        // TC3 100cm, 399cm
        wait_period;
        measure("TC3 100cm", 100 * 58, 100);
        wait_period;
        measure("TC3 399cm", 399 * 58, 399);

        // TC4 DISTANCE 중 start 재입력 -> 결과는 그대로 30cm
        wait_period;
        fork
            sensor_echo(30 * 58);
            begin
                press_start;
                wait (debug_state == DISTANCE);
                press_start;  // 무시되어야 함
                check("TC4 start ignored (state)", debug_state, DISTANCE);
            end
        join
        wait (debug_state == IDLE);
        check("TC4 30cm", distance, 30);

        // TC5 60ms 안 지난 상태(STOP->IDLE 직후) start -> 거부
        press_start;
        repeat (5) @(posedge clk);
        check("TC5 early start rejected", debug_state, IDLE);

        // TC6 echo 무응답 -> 36ms 후 IDLE, distance 0
        wait_period;
        press_start;
        wait (debug_state == WAIT);
        wait (debug_state == IDLE);
        check("TC6 no echo -> 0", distance, 0);

        // TC7 물체 없음: echo 38ms high -> DISTANCE 36ms 타임아웃 -> 0
        wait_period;
        measure("TC7 10cm before", 10 * 58, 10);  // 이전 값이 0이 아님을 만들어 둠
        wait_period;
        fork
            sensor_echo(38_000);
            begin
                press_start;
                wait (debug_state == DISTANCE);
                wait (debug_state == IDLE);
                check("TC7 echo 38ms -> 0", distance, 0);
            end
        join

        // TC8 echo가 high로 붙은 상태 -> start 거부
        wait_period;
        echo = 1;
        #(1000);
        press_start;
        repeat (5) @(posedge clk);
        check("TC8 echo stuck high -> rejected", debug_state, IDLE);
        echo = 0;

        $display("==== RESULT: PASS %0d / FAIL %0d ====", pass_cnt, fail_cnt);
        $finish;
    end

endmodule
