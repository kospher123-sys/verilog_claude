`timescale 1ns / 1ps

// HC-SR04 측정 FSM
//  - trigger: 레지스터 출력 (조합 출력 글리치 방지)
//  - distance: 유효 측정(MIN_CM~MAX_CM cm)일 때만 값, 실패 시 0
//  - error: 마지막 측정 실패(echo 무응답, echo 상한 초과, 측정 범위 밖) = 1
module SR04_sensor #(
    parameter integer MIN_PERIOD_US = 60_000,
    parameter integer CLOCKS_PER_US = 100,
    parameter integer MIN_CM        = 2,    // 데이터시트 측정 범위 하한
    parameter integer MAX_CM        = 400   // 데이터시트 측정 범위 상한
) (
    input clk,
    input start,
    input rst,
    input us_tick,
    input echo,
    output reg trigger,
    output reg enable,
    output reg clear,
    output [8:0] distance,
    output error,
    output [2:0] debug_state

);

    reg [2:0] c_state, n_state;
    reg [8:0] data_reg, data_next;
    reg [15:0] us_tick_cnt_reg, us_tick_cnt_next;
    reg [8:0] echo_cm_reg, echo_cm_next;
    reg [5:0] echo_rem_reg, echo_rem_next;
    reg err_reg, err_next;


    localparam [15:0] TIMEOUT_TICKS = 16'd36_000;
    // 거리 카운터 포화값: MAX_CM을 넘었다는 것만 알면 되므로 MAX_CM+1에서 멈춘다(9비트 랩어라운드 방지)
    localparam [8:0] CM_SAT = MAX_CM + 1;
    localparam [8:0] CM_MIN = MIN_CM;
    localparam [8:0] CM_MAX = MAX_CM;


    localparam [2:0] IDLE = 3'b000, START = 3'b001, WAIT = 3'b010, DISTANCE = 3'b011, STOP = 3'b100;


    assign distance = data_reg;
    assign error = err_reg;
    assign debug_state = c_state;

    // Echo 2-FF Synchronizer
    (* ASYNC_REG = "TRUE" *) reg echo_meta;
    (* ASYNC_REG = "TRUE" *) reg echo_sync;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            echo_meta <= 1'b0;
            echo_sync <= 1'b0;
        end else begin
            echo_meta <= echo;
            echo_sync <= echo_meta;
        end
    end

    // Minimum Start-to-Start Period Timer

    localparam integer PERIOD_CYCLES = MIN_PERIOD_US * CLOCKS_PER_US;  // 60ms (기본값 60_000us x 100clk)

    localparam integer PERIOD_WIDTH = (PERIOD_CYCLES <= 1) ? 1 : $clog2(
        PERIOD_CYCLES
    );

    reg [PERIOD_WIDTH-1:0] period_cnt_reg;
    reg period_ready_reg;

    wire start_accept;

    assign start_accept =(c_state == IDLE) &&start &&!echo_sync &&period_ready_reg; //idle state + start + echo == 0 + out of the cycle

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            period_cnt_reg   <= 0;
            period_ready_reg <= 1'b1;
        end else if (start_accept) begin
            period_cnt_reg   <= 0;
            period_ready_reg <= 1'b0;
        end else if (!period_ready_reg) begin   //measure the time with clk for 1cycle periode
            if (period_cnt_reg == PERIOD_CYCLES - 1) begin
                period_ready_reg <= 1'b1;
            end else begin
                period_cnt_reg <= period_cnt_reg + 1'b1;
            end
        end
    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            data_reg        <= 0;
            us_tick_cnt_reg <= 0;
            echo_cm_reg     <= 0;
            echo_rem_reg    <= 0;
            err_reg         <= 0;
        end else begin
            c_state         <= n_state;
            data_reg        <= data_next;
            us_tick_cnt_reg <= us_tick_cnt_next;
            echo_cm_reg     <= echo_cm_next;
            echo_rem_reg    <= echo_rem_next;
            err_reg         <= err_next;
        end
    end

    // trigger 레지스터 출력: 다음 상태가 START인 동안 1
    // → START 상태 구간과 정확히 같은 폭, 클럭 엣지에서만 바뀌므로 글리치 없음
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            trigger <= 1'b0;
        end else begin
            trigger <= (n_state == START);
        end
    end

    always @(*) begin
        data_next = data_reg;
        n_state = c_state;
        us_tick_cnt_next = us_tick_cnt_reg;

        echo_cm_next = echo_cm_reg;
        echo_rem_next = echo_rem_reg;

        err_next = err_reg;
        enable = 0;
        clear = 0;


        case (c_state)
            IDLE: begin
                clear = 1'b1;
                us_tick_cnt_next = 0;
                if (start_accept) begin
                    n_state = START;
                end
            end
            START: begin    // trigger 구간 (trigger는 레지스터에서 생성)
                enable  = 1'b1;
                if (us_tick) begin
                    if (us_tick_cnt_reg == 11) begin
                        n_state = WAIT;
                        us_tick_cnt_next = 0;
                    end else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin     //wait a echo signal after send the trigger
                clear = 1'b0;
                enable = 1'b1;

                echo_cm_next = 9'd0;    //58us마다 1씩 증가 하면 cm를 계산
                echo_rem_next = 6'd0;   //58us를 계산

                if (us_tick) begin
                    if (echo_sync) begin
                        echo_cm_next = 9'd0;
                        echo_rem_next = 6'd1;   //echo상승이후 1us지난후 상태전이 되기 떄문에 1로 시작
                        us_tick_cnt_next = 1;
                        n_state = DISTANCE;
                    end else if (us_tick_cnt_reg == TIMEOUT_TICKS - 1) begin    //타임아웃: echo 무응답
                        us_tick_cnt_next = 0;
                        data_next = 0;
                        err_next = 1'b1;
                        n_state = IDLE;
                    end else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1;
                    end
                end
            end

            DISTANCE: begin
                enable = 1'b1;

                if (!echo_sync) begin   // echo 하강: 측정 범위 검사 후 저장
                    if ((echo_cm_reg < CM_MIN) || (echo_cm_reg > CM_MAX)) begin
                        data_next = 0;
                        err_next  = 1'b1;
                    end else begin
                        data_next = echo_cm_reg;
                        err_next  = 1'b0;
                    end
                    us_tick_cnt_next = 0;
                    n_state = STOP;
                end else if (us_tick) begin

                    // Distance Counter (CM_SAT에서 포화)
                    if (echo_rem_reg == 58 -1 ) begin
                        echo_rem_next = 0;
                        if (echo_cm_reg != CM_SAT) begin
                            echo_cm_next = echo_cm_reg + 1'b1;
                        end
                    end else begin
                        echo_rem_next = echo_rem_reg + 1'b1;
                    end

                    // 36ms Timeout: echo High 상한 초과
                    if (us_tick_cnt_reg == TIMEOUT_TICKS - 1) begin
                        us_tick_cnt_next = 0;
                        data_next = 0;
                        err_next = 1'b1;
                        n_state = IDLE;
                    end else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1'b1;
                    end
                end
            end

            STOP: begin
                enable = 1'b1;
                if (us_tick) begin
                    if (us_tick_cnt_reg == 10000) begin
                        us_tick_cnt_next = 0;
                        n_state = IDLE;
                    end else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1;
                    end
                end else begin
                    us_tick_cnt_next = us_tick_cnt_reg;
                end


            end

            default: begin
                n_state = IDLE;
            end
        endcase
    end
endmodule
