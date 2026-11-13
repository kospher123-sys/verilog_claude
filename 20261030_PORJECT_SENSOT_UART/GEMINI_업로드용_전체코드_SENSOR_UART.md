# 통합 시스템 전체 RTL + 테스트벤치 (Gemini 업로드용 묶음)

> 학습자료(AI검증_학습자료_SENSOR_UART_통합시스템.md)와 함께 첨부. 탑 모듈: integrated_system_top / 시뮬레이션 탑: tb_sr04_top

## 파일 목록
- `sources_1/imports/new/integrated_system_top.v` (693 lines)
- `sources_1/imports/new/SR04_sensor.v` (207 lines)
- `sources_1/imports/new/ascii_sender.v` (377 lines)
- `sources_1/imports/new/baud_tick_gen_dht11.v` (37 lines)
- `sources_1/imports/new/baud_tick_gen_sr04.v` (40 lines)
- `sources_1/imports/new/btn_debounce.v` (57 lines)
- `sources_1/imports/new/control_unit.v` (66 lines)
- `sources_1/imports/new/dht11_timeout_period.v` (254 lines)
- `sources_1/imports/new/fifo.v` (177 lines)
- `sources_1/imports/new/fnd_controller_stopwatch_watch.v` (386 lines)
- `sources_1/imports/new/integrated_control_unit.v` (112 lines)
- `sources_1/imports/new/lap_time.v` (62 lines)
- `sources_1/imports/new/reset_controller.v` (133 lines)
- `sources_1/imports/new/sensor_fnd_controller.v` (191 lines)
- `sources_1/imports/new/sr04_top.v` (49 lines)
- `sources_1/imports/new/stopwatch.v` (216 lines)
- `sources_1/imports/new/uart.v` (124 lines)
- `sources_1/imports/new/uart_ascii_decoder.v` (156 lines)
- `sources_1/imports/new/uart_rx.v` (107 lines)
- `sources_1/imports/new/uart_tx.v` (108 lines)
- `sources_1/imports/new/watch_control_unit.v` (53 lines)
- `sources_1/imports/new/watch_datapath_sw2.v` (142 lines)
- `sources_1/imports/new/watch_fnd_blink.v` (69 lines)
- `sources_1/imports/new/watch_setting.v` (108 lines)
- `sim_1/new/tb_sr04_top.v` (164 lines)

---

## `sources_1/imports/new/integrated_system_top.v`

```verilog

`timescale 1ns / 1ps

module integrated_system_top (
    input        clk,
    input        rst,   // BTNC: Selected Reset
    input        btnR,
    input        btnL,
    input        btnU,
    input        btnD,
    input [15:0] sw,


    // Sensor Interface
    input  echo,
    output trigger,
    inout  dht11_io,

    // UART Interface
    input  rx,
    output tx,

    output [3:0] fnd_com,
    output [7:0] fnd_font,
    output [2:0] led
);
    // ========================================
    // UART Signal Declaration
    // ========================================

    // UART RX FIFO
    wire [7:0] w_uart_rx_data;
    wire       w_uart_rx_not_empty;
    wire       w_uart_rx_pop;
    wire       w_ascii_sender_ready;
    wire       w_uart_decode_enable;
    reg        w_uart_decode_gap;

    // UART TX FIFO
    wire       w_uart_tx_full;
    wire       w_uart_tx_push;
    wire [7:0] w_uart_tx_data;

    // ASCII Decoder
    wire       w_uart_run_stop;
    wire       w_uart_clear;
    wire       w_uart_mode;
    wire       w_uart_status;
    wire [3:0] w_uart_bin;
    wire       w_uart_mode_valid;
    wire [2:0] w_uart_select_mode;
    // ========================================
    // 1. Switch Mode Synchronization / Filter
    // ========================================

    wire [2:0] w_sw_mode;

    reset_input_filter U_SW0_FILTER (
        .clk(clk),
        .raw_in(sw[0]),
        .stable_out(w_sw_mode[0])
    );

    reset_input_filter U_SW1_FILTER (
        .clk(clk),
        .raw_in(sw[1]),
        .stable_out(w_sw_mode[1])
    );

    reset_input_filter U_SW2_FILTER (
        .clk(clk),
        .raw_in(sw[2]),
        .stable_out(w_sw_mode[2])
    );

    reg  [2:0] active_mode_reg = 3'b000;
    reg  [2:0] sw_mode_prev_reg = 3'b000;

    wire [2:0] w_active_mode;
    assign w_active_mode = active_mode_reg;
    // Active Mode LED Indicator
    assign led = w_active_mode;
    wire w_is_stopwatch;
    wire w_is_watch;
    wire w_time_mode;

    assign w_is_stopwatch = (w_active_mode == 3'b000);
    assign w_is_watch     = (w_active_mode == 3'b001);

    assign w_time_mode    = w_is_stopwatch | w_is_watch;

    // 기존 SW0 선택 신호와 동일한 의미
    // 0 = Watch, 1 = Stopwatch / Other
    wire w_old_sw0;
    assign w_old_sw0 = ~w_is_watch;


    // ========================================
    // 2. Reset Controller
    // ========================================

    wire w_rst_watch;
    wire w_rst_stopwatch;
    wire w_rst_global;

    reset_controller #(
        .SW0_STABLE_CYCLES(1),
        .USE_RESET_ENABLE (1)
    ) U_RESET_CONTROLLER (
        .clk(clk),

        .btn_reset(rst),
        .reset_enable(w_time_mode),

        .sw0 (w_old_sw0),
        .sw15(sw[15]),

        .sw0_clean(),
        .rst_watch(w_rst_watch),
        .rst_stopwatch(w_rst_stopwatch),
        .rst_shared(w_rst_global)
    );

    // ========================================
    // 2-A. SW / UART Mode Selection
    // ========================================

    always @(posedge clk) begin
        if (w_rst_global) begin
            active_mode_reg  <= w_sw_mode;
            sw_mode_prev_reg <= w_sw_mode;
        end else begin
            sw_mode_prev_reg <= w_sw_mode;

            // Priority 1: Physical SW
            if (w_sw_mode != sw_mode_prev_reg) active_mode_reg <= w_sw_mode;

            // Priority 2: UART Command
            else if (w_uart_mode_valid) active_mode_reg <= w_uart_select_mode;
        end
    end

    // ========================================
    // 3. Button Debounce
    // ========================================

    wire w_btn_r, w_btn_l, w_btn_u, w_btn_d;

    btn_debounce U_BTN_R (
        .clk  (clk),
        .reset(w_rst_global),
        .i_btn(btnR),
        .o_btn(w_btn_r)
    );

    btn_debounce U_BTN_L (
        .clk  (clk),
        .reset(w_rst_global),
        .i_btn(btnL),
        .o_btn(w_btn_l)
    );

    btn_debounce U_BTN_U (
        .clk  (clk),
        .reset(w_rst_global),
        .i_btn(btnU),
        .o_btn(w_btn_u)
    );

    btn_debounce U_BTN_D (
        .clk  (clk),
        .reset(w_rst_global),
        .i_btn(btnD),
        .o_btn(w_btn_d)
    );


    // ========================================
    // 4. Integrated Control Unit
    // ========================================

    wire w_sw_run_stop_btn;
    wire w_sw_clear_btn;
    wire w_sw_mode_btn;
    wire w_sw_lap_btn;

    wire w_watch_right;
    wire w_watch_left;
    wire w_watch_up;
    wire w_watch_down;

    wire w_sr04_start;
    wire w_dht11_start;
    wire w_status_request;

    integrated_control_unit U_INTEGRATED_CONTROL (
        .sw_mode(w_active_mode),

        .btn_r(w_btn_r),
        .btn_l(w_btn_l),
        .btn_u(w_btn_u),
        .btn_d(w_btn_d),

        // UART ASCII Command
        .cmd_r(w_uart_run_stop),
        .cmd_c(w_uart_clear),
        .cmd_u(w_uart_mode),
        .cmd_s(w_uart_status),

        .sw_run_stop(w_sw_run_stop_btn),
        .sw_clear(w_sw_clear_btn),
        .sw_mode_btn(w_sw_mode_btn),
        .sw_lap(w_sw_lap_btn),

        .watch_right(w_watch_right),
        .watch_left(w_watch_left),
        .watch_up(w_watch_up),
        .watch_down(w_watch_down),

        .sr04_start(w_sr04_start),
        .dht11_start(w_dht11_start),
        .status_request(w_status_request)
    );


    // ========================================
    // 5. Stopwatch Control Unit
    // ========================================

    wire w_sw_run_stop;
    wire w_sw_clear;
    wire w_stopwatch_mode;

    control_unit U_STOPWATCH_CONTROL_UNIT (
        .clk  (clk),
        .reset(w_rst_stopwatch),

        .btn_run_stop(w_sw_run_stop_btn),
        .btn_clear(w_sw_clear_btn),
        .btn_mode(w_sw_mode_btn),

        .run_stop(w_sw_run_stop),
        .clear(w_sw_clear),
        .mode(w_stopwatch_mode)
    );


    // ========================================
    // 6. Stopwatch Datapath
    // ========================================

    wire [6:0] w_sw_msec;
    wire [5:0] w_sw_sec;
    wire [5:0] w_sw_min;
    wire [4:0] w_sw_hour;

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk(clk),
        .rst(w_rst_stopwatch),

        .run_stop(w_sw_run_stop),
        .clear(w_sw_clear),
        .mode(w_stopwatch_mode),

        .msec(w_sw_msec),
        .sec (w_sw_sec),
        .min (w_sw_min),
        .hour(w_sw_hour)
    );


    // ========================================
    // 7. Watch Control Unit
    // ========================================

    wire w_watch_select;
    wire w_edit_enable;
    wire w_count_enable;
    wire [1:0] w_edit_field;
    wire w_inc_pulse;
    wire w_dec_pulse;
    wire w_blink_enable;
    wire w_fnd_display_mode;

    wire w_watch_setting;
    assign w_watch_setting = w_is_watch & sw[5];

    watch_control_unit U_WATCH_CONTROL_UNIT (
        .clk(clk),
        .rst(w_rst_watch),

        .sw0(w_old_sw0),
        .sw2(w_watch_setting),
        .sw_display_mode(sw[4]),

        .btn_right(w_watch_right),
        .btn_left(w_watch_left),
        .btn_up(w_watch_up),
        .btn_down(w_watch_down),

        .watch_select(w_watch_select),
        .edit_enable(w_edit_enable),
        .count_enable(w_count_enable),
        .edit_field(w_edit_field),
        .inc_pulse(w_inc_pulse),
        .dec_pulse(w_dec_pulse),
        .blink_enable(w_blink_enable),
        .fnd_display_mode(w_fnd_display_mode)
    );


    // ========================================
    // 8. Watch Datapath
    // ========================================

    wire [6:0] w_watch_msec;
    wire [5:0] w_watch_sec;
    wire [5:0] w_watch_min;
    wire [4:0] w_watch_hour;

    watch_datapath_sw2 U_WATCH_DATAPATH (
        .clk(clk),
        .rst(w_rst_watch),

        .count_enable(w_count_enable),
        .edit_enable(w_edit_enable),
        .edit_field(w_edit_field),
        .inc_pulse(w_inc_pulse),
        .dec_pulse(w_dec_pulse),

        .msec(w_watch_msec),
        .sec (w_watch_sec),
        .min (w_watch_min),
        .hour(w_watch_hour)
    );


    // ========================================
    // 9. Stopwatch Lap
    // ========================================

    wire [6:0] w_sw_display_msec;
    wire [5:0] w_sw_display_sec;
    wire [5:0] w_sw_display_min;
    wire [4:0] w_sw_display_hour;

    lap_time U_LAP_TIME (
        .clk  (clk),
        .rst  (w_rst_stopwatch),
        .clear(w_sw_clear),

        .btn_lap(w_sw_lap_btn),
        .sw_lap_display(sw[3]),

        .msec(w_sw_msec),
        .sec (w_sw_sec),
        .min (w_sw_min),
        .hour(w_sw_hour),

        .display_msec(w_sw_display_msec),
        .display_sec (w_sw_display_sec),
        .display_min (w_sw_display_min),
        .display_hour(w_sw_display_hour)
    );


    // ========================================
    // 10. Time Data MUX
    // ========================================

    wire [6:0] w_fnd_msec;
    wire [5:0] w_fnd_sec;
    wire [5:0] w_fnd_min;
    wire [4:0] w_fnd_hour;

    assign w_fnd_msec = w_watch_select ? w_watch_msec : w_sw_display_msec;

    assign w_fnd_sec  = w_watch_select ? w_watch_sec : w_sw_display_sec;

    assign w_fnd_min  = w_watch_select ? w_watch_min : w_sw_display_min;

    assign w_fnd_hour = w_watch_select ? w_watch_hour : w_sw_display_hour;


    // ========================================
    // 11. Status Data (24-bit)
    // ========================================

    wire [23:0] w_stopwatch_status;
    wire [23:0] w_watch_status;

    assign w_stopwatch_status = {w_sw_hour, w_sw_min, w_sw_sec, w_sw_msec};

    assign w_watch_status = {
        w_watch_hour, w_watch_min, w_watch_sec, w_watch_msec
    };


    // ========================================
    // 12. FND Controller
    // ========================================

    wire [3:0] w_fnd_com_raw;
    wire [7:0] w_fnd_font_raw;

    wire [3:0] w_fnd_com_time;
    wire [7:0] w_fnd_font_time;

    fnd_controller_stopwatch_watch U_FND_CNT (
        .clk(clk),
        .rst(w_rst_global),

        .sw_display_mode(w_fnd_display_mode),

        .msec(w_fnd_msec),
        .sec (w_fnd_sec),
        .min (w_fnd_min),
        .hour(w_fnd_hour),

        .fnd_com (w_fnd_com_raw),
        .fnd_font(w_fnd_font_raw)
    );


    // ========================================
    // 13. Watch Blink
    // ========================================

    watch_fnd_blink U_WATCH_FND_BLINK (
        .clk(clk),
        .rst(w_rst_watch),

        .watch_select(w_watch_select),
        .blink_enable(w_blink_enable),
        .edit_field  (w_edit_field),

        .fnd_com_in (w_fnd_com_raw),
        .fnd_font_in(w_fnd_font_raw),

        .fnd_com_out (w_fnd_com_time),
        .fnd_font_out(w_fnd_font_time)
    );


    // ========================================
    // 14. Final FND Output MUX
    // ========================================

    wire w_sensor_mode;
    wire [3:0] w_fnd_com_sensor;
    wire [7:0] w_fnd_font_sensor;

    assign w_sensor_mode = (w_active_mode == 3'b010) || (w_active_mode == 3'b011);

    assign fnd_com =
    w_time_mode   ? w_fnd_com_time   :
    w_sensor_mode ? w_fnd_com_sensor :
                    4'b1111;

    assign fnd_font =
    w_time_mode   ? w_fnd_font_time   :
    w_sensor_mode ? w_fnd_font_sensor :
                    8'hFF;

    // ========================================
    // 15. HC-SR04 Ultrasonic Sensor
    // ========================================

    wire [8:0] w_sr04_distance;
    wire [2:0] w_sr04_state;

    sr04_top #(
        .MIN_PERIOD_US(60_000)
    ) U_SR04_TOP (
        .clk        (clk),
        .rst        (w_rst_global),
        .start      (w_sr04_start),
        .echo       (echo),
        .trigger    (trigger),
        .distance   (w_sr04_distance),
        .debug_state(w_sr04_state)
    );

    // ========================================
    // 16. DHT11 Temperature / Humidity Sensor
    // ========================================

    wire w_dht11_us_tick;
    wire w_dht11_valid;
    wire w_dht11_error;

    wire [15:0] w_dht11_humidity;
    wire [15:0] w_dht11_temperature;

    baud_tick_gen_dht11 #(
        .F_COUNT(100)
    ) U_DHT11_TICK_GEN (
        .clk   (clk),
        .rst   (w_rst_global),
        .enable(1'b1),
        .clear (1'b0),
        .b_tick(w_dht11_us_tick)
    );

    dht11_controller #(
        .MIN_PERIOD_US(1_000_000),
        .TIMEOUT_US(150)
    ) U_DHT11_CONTROLLER (
        .clk        (clk),
        .rst        (w_rst_global),
        .dht11_start(w_dht11_start),
        .us_tick    (w_dht11_us_tick),

        .valid(w_dht11_valid),
        .error(w_dht11_error),

        .humidity   (w_dht11_humidity),
        .temperature(w_dht11_temperature),

        .dht11_io(dht11_io)
    );
    // ========================================
    // 16-A. Sensor FND Controller
    // ========================================


    sensor_fnd_controller U_SENSOR_FND (
        .clk(clk),
        .rst(w_rst_global),

        .sw_mode(w_active_mode),
        .sw_display_mode(sw[4]),

        .distance(w_sr04_distance),

        .humidity(w_dht11_humidity),
        .temperature(w_dht11_temperature),

        .dht_valid(w_dht11_valid),
        .dht_error(w_dht11_error),

        .fnd_com (w_fnd_com_sensor),
        .fnd_font(w_fnd_font_sensor)
    );
    // ========================================
    // 16-1. Status Data MUX (32-bit)
    // ========================================

    reg [31:0] w_selected_status;

    always @(*) begin
        w_selected_status = 32'b0;

        case (w_active_mode)

            3'b000: begin
                w_selected_status = {8'b0, w_stopwatch_status};
            end

            3'b001: begin
                w_selected_status = {8'b0, w_watch_status};
            end

            3'b010: begin
                w_selected_status = {23'b0, w_sr04_distance};
            end

            3'b011: begin
                w_selected_status = {w_dht11_humidity, w_dht11_temperature};
            end

            default: begin
                w_selected_status = 32'b0;
            end

        endcase
    end

    // ========================================
    // 17. UART / FIFO
    // ========================================

    // UART / Dual FIFO
    uart_fifo_loopback U_UART_FIFO_LOOPBACK (
        .clk(clk),
        .rst(w_rst_global),

        .rx(rx),
        .tx(tx),

        // FIFO RX
        .fifo_rx_pop(w_uart_rx_pop),
        .rx_pop_data(w_uart_rx_data),
        .rx_empty   (w_uart_rx_not_empty),

        // FIFO TX (temporary)
        .fifo_tx_push     (w_uart_tx_push),
        .fifo_tx_push_data(w_uart_tx_data),
        .fifo_tx_full     (w_uart_tx_full)
    );

    // ========================================
    // 18. ASCII Decoder
    // ========================================

    ascii_decoder U_ASCII_DECODER (
        .clk(clk),
        .rst(w_rst_global),

        .enable(w_uart_decode_enable),
        .ascii (w_uart_rx_data),
        .pop   (w_uart_rx_pop),

        .run_stop      (w_uart_run_stop),
        .clear         (w_uart_clear),
        .mode          (w_uart_mode),
        .status        (w_uart_status),
        // New UART Mode Selection
        .mode_sel_valid(w_uart_mode_valid),
        .mode_sel      (w_uart_select_mode),

        .bin(w_uart_bin)
    );
    // ========================================
    // UART RX Command Flow Control
    // ========================================

    // Sender가 IDLE이고, RX FIFO에 데이터가 있으며,
    // 직전 Clock에 이미 읽지 않았을 때만 수신 허용
    assign w_uart_decode_enable =
    w_uart_rx_not_empty &&
    w_ascii_sender_ready &&
    !w_uart_decode_gap;

    // Decoder가 명령을 출력하는 1Clock 동안
    // 다음 Byte가 연속으로 소비되는 것을 방지
    always @(posedge clk or posedge w_rst_global) begin
        if (w_rst_global) w_uart_decode_gap <= 1'b0;
        else w_uart_decode_gap <= w_uart_decode_enable;
    end

    // ========================================
    // Periodic Status Request (0.5 sec)
    // Stopwatch / Watch Only
    // ========================================

    reg [25:0] period_cnt_reg;

    always @(posedge clk or posedge w_rst_global) begin
        if (w_rst_global) period_cnt_reg <= 26'd0;

        else if (!w_time_mode) period_cnt_reg <= 26'd0;

        else if (period_cnt_reg == 26'd49_999_999) period_cnt_reg <= 26'd0;

        else period_cnt_reg <= period_cnt_reg + 1'b1;
    end

    wire w_periodic_status;

    assign w_periodic_status =
    w_time_mode &&
    (period_cnt_reg == 26'd49_999_999) &&
    w_ascii_sender_ready &&
    !w_uart_rx_not_empty;
    // ========================================
    // 19. Integrated ASCII Sender
    // ========================================

    ascii_sender U_ASCII_SENDER (
        .clk(clk),
        .rst(w_rst_global),

        .run_stop(w_uart_run_stop),
        .clear(w_uart_clear),
        .mode(w_uart_mode),
        .status(w_status_request),

        // UART Remote Mode Selection
        .mode_sel_valid(w_uart_mode_valid),
        .mode_sel(w_uart_select_mode),

        .sw_mode(w_active_mode),
        .status_data(w_selected_status),
        .periodic_status(w_periodic_status),

        .full(w_uart_tx_full),

        .push(w_uart_tx_push),
        .push_data(w_uart_tx_data),
        .ready(w_ascii_sender_ready)
    );
endmodule

```

---

## `sources_1/imports/new/SR04_sensor.v`

```verilog
`timescale 1ns / 1ps

module SR04_sensor #(
    parameter integer MIN_PERIOD_US = 60_000,
    parameter integer CLOCKS_PER_US = 100
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
    output [2:0] debug_state

);

    reg [2:0] c_state, n_state;
    reg [8:0] data_reg, data_next;
    reg [15:0] us_tick_cnt_reg, us_tick_cnt_next;
    reg [8:0] echo_cm_reg, echo_cm_next;
    reg [5:0] echo_rem_reg, echo_rem_next;
    reg timeout_reg, timeout_next;


    localparam [15:0] TIMEOUT_TICKS = 16'd36_000;


    localparam [2:0] IDLE = 3'b000, START = 3'b001, WAIT = 3'b010, DISTANCE = 3'b011, STOP = 3'b100;


    assign distance = data_reg;
    assign debug_state = c_state;

    // Echo 2-FF Synchronizer
    reg echo_meta;
    reg echo_sync;

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

    localparam integer PERIOD_CYCLES = MIN_PERIOD_US * CLOCKS_PER_US;  //6ms - 1 cycle period

    localparam integer PERIOD_WIDTH = (PERIOD_CYCLES <= 1) ? 1 : $clog2(
        PERIOD_CYCLES
    );

    reg [PERIOD_WIDTH-1:0] period_cnt_reg;
    reg period_ready_reg;

    wire start_accept;

    assign start_accept =(c_state == IDLE) &&start &&!echo_sync &&period_ready_reg; //idle state + start + ech0 == 0 + out of the cycle

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
            timeout_reg     <= 0;
        end else begin
            c_state         <= n_state;
            data_reg        <= data_next;
            us_tick_cnt_reg <= us_tick_cnt_next;
            echo_cm_reg     <= echo_cm_next;
            echo_rem_reg    <= echo_rem_next;
            timeout_reg     <= timeout_next;
        end
    end

    always @(*) begin
        data_next = data_reg;
        n_state = c_state;
        us_tick_cnt_next = us_tick_cnt_reg;

        echo_cm_next = echo_cm_reg;
        echo_rem_next = echo_rem_reg;

        timeout_next = timeout_reg;
        trigger = 0;
        enable = 0;
        clear = 0;


        case (c_state)
            IDLE: begin
                clear = 1'b1;
                us_tick_cnt_next = 0;
                // data_next = 0;
                if (start_accept) begin
                    timeout_next = 1'b0;
                    n_state = START;
                end
            end
            START: begin    //output trigger signal
                trigger = 1'b1;
                enable  = 1'b1;
                if (us_tick) begin
                    if (us_tick_cnt_reg == 11) begin
                        n_state = WAIT;
                        trigger = 1'b0;
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
                    end else if (us_tick_cnt_reg == TIMEOUT_TICKS - 1) begin    //타임아웃
                        us_tick_cnt_next = 0;
                        data_next = 0;
                        timeout_next = 1'b1;
                        n_state = IDLE;
                    end else begin
                        us_tick_cnt_next = us_tick_cnt_reg + 1;
                    end
                end
            end

            DISTANCE: begin
                enable = 1'b1;

                if (!echo_sync) begin   //when echo ==0, move to STOP, sve echo_cm_reg to data_next
                    data_next = echo_cm_reg;
                    us_tick_cnt_next = 0;
                    n_state = STOP;
                end else if (us_tick) begin

                    // Distance Counter
                    if (echo_rem_reg == 58 -1 ) begin
                        echo_rem_next = 0;
                        echo_cm_next  = echo_cm_reg + 1'b1;
                    end else begin
                        echo_rem_next = echo_rem_reg + 1'b1;
                    end

                    // 36ms Timeout
                    if (us_tick_cnt_reg == TIMEOUT_TICKS - 1) begin
                        us_tick_cnt_next = 0;
                        data_next = 0;
                        timeout_next = 1'b1;
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
        endcase
    end
endmodule

```

---

## `sources_1/imports/new/ascii_sender.v`

```verilog

`timescale 1ns / 1ps

module ascii_sender (
    input clk,
    rst,
    input run_stop,
    clear,
    mode,
    status,
    input mode_sel_valid,
    input [2:0] mode_sel,
    input [2:0] sw_mode,
    input [31:0] status_data,
    input periodic_status,
    input full,
    output reg push,
    output reg [7:0] push_data,
    output wire ready
);

    localparam IDLE = 2'd0, CONVERT = 2'd1, SEND = 2'd2;

    reg [1:0] state;
    reg [2:0] saved_mode;
    reg [31:0] saved_data;
    reg is_echo;
    reg [7:0] echo_char;
    reg [5:0] idx;

    reg [8:0] binary_shift;
    reg [11:0] bcd_work, bcd0, bcd1;
    reg [3:0] bit_count;
    reg [1:0] part;

    // Watch / Stopwatch Decimal Data
    reg [7:0] bcd_hour;
    reg [7:0] bcd_min;
    reg [7:0] bcd_sec;
    reg [7:0] bcd_cs;

    assign ready = (state == IDLE);

    // Skip leading zero digits, but preserve the last digit
    wire skip_digit =
        (saved_mode == 3'd2 &&
           ((idx == 6'd11 && bcd0[11:8] == 0) ||
            (idx == 6'd12 && bcd0[11:8] == 0 &&
             bcd0[7:4] == 0))) ||
        (saved_mode == 3'd3 &&
           ((idx == 6'd9 && bcd0[11:8] == 0) ||
            (idx == 6'd10 && bcd0[11:8] == 0 &&
             bcd0[7:4] == 0) ||
            (idx == 6'd28 && bcd1[11:8] == 0) ||
            (idx == 6'd29 && bcd1[11:8] == 0 &&
             bcd1[7:4] == 0)));

    // Double Dabble: Add-3
    function [11:0] add3;
        input [11:0] x;
        reg [11:0] y;
        begin
            y = x;

            if (y[3:0] >= 5) y[3:0] = y[3:0] + 4'd3;

            if (y[7:4] >= 5) y[7:4] = y[7:4] + 4'd3;

            if (y[11:8] >= 5) y[11:8] = y[11:8] + 4'd3;

            add3 = y;
        end
    endfunction

    wire [11:0] adjusted = add3(bcd_work);
    wire [11:0] shifted_bcd = {adjusted[10:0], binary_shift[8]};

    // FSM Sequential Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            saved_mode   <= 0;
            saved_data   <= 0;
            is_echo      <= 0;
            echo_char    <= 0;
            idx          <= 0;
            binary_shift <= 0;
            bcd_work     <= 0;
            bcd0         <= 0;
            bcd1         <= 0;
            bit_count    <= 0;
            part         <= 0;
            bcd_hour     <= 8'd0;
            bcd_min      <= 8'd0;
            bcd_sec      <= 8'd0;
            bcd_cs       <= 8'd0;
        end else begin
            case (state)

                IDLE: begin
                    idx <= 0;

                    if (run_stop || clear || mode || mode_sel_valid) begin

                        is_echo <= 1;

                        if (run_stop) echo_char <= "r";
                        else if (clear) echo_char <= "c";
                        else if (mode) echo_char <= "u";
                        else echo_char <= 8'h31 + {5'b0, mode_sel};

                        state <= SEND;

                    end else if (status || periodic_status) begin
                        is_echo    <= 0;
                        saved_mode <= sw_mode;
                        saved_data <= status_data;

                        bit_count  <= 0;
                        part       <= 0;
                        bcd_work   <= 0;

                        case (sw_mode)

                            // Stopwatch / Watch
                            3'd0, 3'd1: begin
                                binary_shift <= {4'b0000, status_data[23:19]};
                                state <= CONVERT;
                            end

                            // HC-SR04
                            3'd2: begin
                                binary_shift <= status_data[8:0];
                                state <= CONVERT;
                            end

                            // DHT11
                            3'd3: begin
                                binary_shift <= {1'b0, status_data[31:24]};
                                state <= CONVERT;
                            end

                            default: begin
                                state <= SEND;
                            end

                        endcase
                    end
                end

                CONVERT: begin

                    bcd_work <= shifted_bcd;

                    binary_shift <= {binary_shift[7:0], 1'b0};

                    if (bit_count == 4'd8) begin

                        bit_count <= 0;
                        bcd_work  <= 0;

                        // Stopwatch / Watch
                        if (saved_mode == 3'd0 || saved_mode == 3'd1) begin

                            case (part)

                                2'd0: begin
                                    bcd_hour <= shifted_bcd[7:0];
                                    binary_shift <= {3'b000, saved_data[18:13]};
                                    part <= 2'd1;
                                end

                                2'd1: begin
                                    bcd_min <= shifted_bcd[7:0];
                                    binary_shift <= {3'b000, saved_data[12:7]};
                                    part <= 2'd2;
                                end

                                2'd2: begin
                                    bcd_sec <= shifted_bcd[7:0];
                                    binary_shift <= {2'b00, saved_data[6:0]};
                                    part <= 2'd3;
                                end

                                2'd3: begin
                                    bcd_cs <= shifted_bcd[7:0];
                                    state  <= SEND;
                                end

                            endcase

                        end  // HC-SR04 / DHT11
                        else begin

                            if (part == 2'd0) bcd0 <= shifted_bcd;
                            else bcd1 <= shifted_bcd;

                            if (saved_mode == 3'd3 && part == 2'd0) begin

                                part <= 2'd1;
                                binary_shift <= {1'b0, saved_data[15:8]};

                            end else begin
                                state <= SEND;
                            end

                        end

                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end

                end

                SEND: begin
                    if (!is_echo && skip_digit) begin
                        idx <= idx + 1'b1;

                    end else if (!full) begin
                        if ((is_echo && idx == 6'd2) ||
            (!is_echo && saved_mode < 2 && idx == 6'd14) ||
            (!is_echo && saved_mode == 2 && idx == 6'd17) ||
            (!is_echo && saved_mode == 3 && idx == 6'd33) ||
            (!is_echo && saved_mode > 3 && idx == 6'd11)) begin

                            state <= IDLE;
                        end else begin
                            idx <= idx + 1'b1;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    // ASCII Character Generation
    reg [3:0] hex_digit;

    always @(*) begin
        push = 1'b0;
        push_data = 8'h00;
        hex_digit = 0;

        if (state == SEND && !full && (is_echo || !skip_digit)) begin

            push = 1'b1;

            if (is_echo) begin
                case (idx)
                    6'd0: push_data = echo_char;
                    6'd1: push_data = 8'h0D;  // CR
                    6'd2: push_data = 8'h0A;  // LF
                    default: push_data = 8'h00;
                endcase

            end else begin
                case (saved_mode)

                    // Stopwatch / Watch: HH:MM:SS.CC
                    3'd0, 3'd1: begin
                        case (idx)

                            0: push_data = 8'h30 + {5'b0, saved_mode};
                            1: push_data = ":";

                            // Hour
                            2: push_data = 8'h30 + bcd_hour[7:4];
                            3: push_data = 8'h30 + bcd_hour[3:0];

                            4: push_data = ":";

                            // Minute
                            5: push_data = 8'h30 + bcd_min[7:4];
                            6: push_data = 8'h30 + bcd_min[3:0];

                            7: push_data = ":";

                            // Second
                            8: push_data = 8'h30 + bcd_sec[7:4];
                            9: push_data = 8'h30 + bcd_sec[3:0];

                            10: push_data = ".";

                            // Centisecond
                            11: push_data = 8'h30 + bcd_cs[7:4];
                            12: push_data = 8'h30 + bcd_cs[3:0];

                            13: push_data = 8'h0D;
                            14: push_data = 8'h0A;

                            default: push_data = 8'h00;

                        endcase
                    end

                    // HC-SR04: distance : xxcm
                    3'd2: begin
                        case (idx)
                            0:  push_data = "d";
                            1:  push_data = "i";
                            2:  push_data = "s";
                            3:  push_data = "t";
                            4:  push_data = "a";
                            5:  push_data = "n";
                            6:  push_data = "c";
                            7:  push_data = "e";
                            8:  push_data = " ";
                            9:  push_data = ":";
                            10: push_data = " ";
                            11: push_data = 8'h30 + bcd0[11:8];
                            12: push_data = 8'h30 + bcd0[7:4];
                            13: push_data = 8'h30 + bcd0[3:0];
                            14: push_data = "c";
                            15: push_data = "m";
                            16: push_data = 8'h0D;
                            17: push_data = 8'h0A;
                        endcase
                    end

                    // DHT11: humidity and temperature
                    3'd3: begin
                        case (idx)
                            0:  push_data = "h";
                            1:  push_data = "u";
                            2:  push_data = "m";
                            3:  push_data = "i";
                            4:  push_data = "d";
                            5:  push_data = "i";
                            6:  push_data = "t";
                            7:  push_data = "y";
                            8:  push_data = ":";
                            9:  push_data = 8'h30 + bcd0[11:8];
                            10: push_data = 8'h30 + bcd0[7:4];
                            11: push_data = 8'h30 + bcd0[3:0];
                            12: push_data = "%";
                            13: push_data = 8'h0D;
                            14: push_data = 8'h0A;

                            15: push_data = "t";
                            16: push_data = "e";
                            17: push_data = "m";
                            18: push_data = "p";
                            19: push_data = "e";
                            20: push_data = "r";
                            21: push_data = "a";
                            22: push_data = "t";
                            23: push_data = "u";
                            24: push_data = "r";
                            25: push_data = "e";
                            26: push_data = ":";
                            27: push_data = " ";
                            28: push_data = 8'h30 + bcd1[11:8];
                            29: push_data = 8'h30 + bcd1[7:4];
                            30: push_data = 8'h30 + bcd1[3:0];
                            31: push_data = "C";
                            32: push_data = 8'h0D;
                            33: push_data = 8'h0A;
                        endcase
                    end

                    default: begin
                        case (idx)
                            0: push_data = "?";
                            1: push_data = ":";
                            10: push_data = 8'h0D;
                            11: push_data = 8'h0A;
                            default: push_data = "0";
                        endcase
                    end

                endcase
            end
        end
    end

endmodule

```

---

## `sources_1/imports/new/baud_tick_gen_dht11.v`

```verilog
module baud_tick_gen_dht11 #(
    parameter integer F_COUNT = 100
)(
    input clk,
    input rst,
    input enable,
    input clear,
    output reg b_tick
);

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 0;
        end
        else if (clear) begin
            counter_reg <= 0;
            b_tick <= 0;
        end
        else if (enable) begin
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1;
            end
            else begin
                counter_reg <= counter_reg + 1'b1;
                b_tick <= 0;
            end
        end
        else begin
            counter_reg <= 0;
            b_tick <= 0;
        end
    end

endmodule
```

---

## `sources_1/imports/new/baud_tick_gen_sr04.v`

```verilog
`timescale 1ns / 1ps

module baud_tick_gen_sr04 #(
    parameter integer F_COUNT = 100
)(
    input clk,
    input rst,
    input enable,
    input clear,
    output reg b_tick
);

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 0;
        end
        else if (clear) begin
            counter_reg <= 0;
            b_tick <= 0;
        end
        else if (enable) begin
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1;
            end
            else begin
                counter_reg <= counter_reg + 1'b1;
                b_tick <= 0;
            end
        end
        else begin
            counter_reg <= 0;
            b_tick <= 0;
        end
    end

endmodule

```

---

## `sources_1/imports/new/btn_debounce.v`

```verilog
`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);
    reg [7:0] q_reg;
    wire debounce;  // debounced 
    reg edge_reg; // edge detect signal

    // clk div : 100mHz -> 1mhz
    parameter F_COUNT = 1000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg clk_1mhz;
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            counter_reg <= 0;
            clk_1mhz <= 1'b0;
        end else begin
            counter_reg <= counter_reg + 1;
            if(counter_reg == (F_COUNT-1)) begin
                counter_reg <= 0;
                clk_1mhz <= 1'b1;
            end else begin
                clk_1mhz <= 1'b0;
            end
        end
    end

    // 8bit shift register :SIPO
    always @(posedge clk_1mhz, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h00;
        end else begin
            q_reg <= {i_btn, q_reg[7:1]};  // right shift, msb : in, 7:1 -> 6:0 
        end
    end

    // 8-input AND gate
    assign debounce = &q_reg;


    //edge detection
    always @(posedge clk, posedge reset) begin
        if(reset)begin
            edge_reg <= 1'b0;
        end else begin
            edge_reg <= debounce;
        end
    end

    // rising edge, tick gen
    assign o_btn = ~edge_reg & debounce;

endmodule

```

---

## `sources_1/imports/new/control_unit.v`

```verilog
`timescale 1ns / 1ps

module control_unit (
    input clk,
    input reset,
    input btn_run_stop,
    input btn_clear,
    input btn_mode,
    output reg run_stop,
    output reg clear,
    output mode
);

    parameter STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10, MODE = 2'b11;
    reg [1:0] c_state, n_state;
    reg mode_reg, mode_next;  // mode_reg : current mode, mode_next: next mode

    assign mode = mode_reg;

    always @(posedge clk, posedge reset) begin //상승엣지로 만드는 이유 : 다른 부분이 상승엣지에 맞춰져 있다.
        if (reset) begin
            c_state  <= STOP;
            mode_reg <= 1'b0;
        end else begin
            c_state  <= n_state;
            mode_reg <= mode_next;
        end
    end

    //next / output CL
    always @(*) begin
        n_state = c_state;
        run_stop = 1'b0;
        clear = 1'b0;
        mode_next = mode_reg;
        case (c_state)
            STOP: begin
                // moore output
                run_stop = 1'b0;
                clear = 1'b0;
                if (btn_run_stop == 1'b1) begin
                    n_state = RUN;
                end else if (btn_clear == 1'b1) begin
                    n_state = CLEAR;
                end else if (btn_mode == 1'b1) begin
                    n_state = MODE;
                end
            end
            RUN: begin
                run_stop = 1'b1;
                if (btn_run_stop == 1'b1) begin
                    n_state = STOP;
                end
            end
            CLEAR: begin
                clear   = 1'b1;
                n_state = STOP;  // next posedge clk
            end
            MODE : begin
                mode_next = ~mode_reg;
                n_state = STOP;
            end
        endcase
    end

endmodule

```

---

## `sources_1/imports/new/dht11_timeout_period.v`

```verilog
`timescale 1ns / 1ps

// DHT11 independent version: 8-state controller + per-state Timeout +
// a minimum start-to-start interval. Default parameters are for real hardware.

module dht11_controller #(
    parameter integer MIN_PERIOD_US = 1_000_000,
    parameter integer TIMEOUT_US    = 150
)(
    input clk,
    input rst,
    input dht11_start,
    input us_tick,
    output valid,
    output error,
    output [15:0] humidity,
    output [15:0] temperature,
    inout dht11_io
);
    localparam [3:0] IDLE=0, START=1, WAIT=2, SYNC_L=3,
                     SYNC_H=4, DATA_SYNC=5, DATA_BIT=6, STOP=7;
    localparam integer PERIOD_W = (MIN_PERIOD_US < 2) ? 1 : $clog2(MIN_PERIOD_US + 1);

    reg [3:0] c_state, n_state;
    reg dht11_io_control_reg, dht11_io_control_next;
    reg dht11_io_reg, dht11_io_next;
    reg [$clog2(19_000)-1:0] tick_cnt_reg, tick_cnt_next;
    reg [5:0] bit_cnt_reg, bit_cnt_next;
    reg [39:0] data_reg, data_next;
    reg valid_reg, valid_next;
    reg error_reg, error_next;
    reg [15:0] humidity_reg, humidity_next;
    reg [15:0] temperature_reg, temperature_next;
    reg [PERIOD_W-1:0] period_cnt_reg;
    reg start_accept;

    (* ASYNC_REG = "TRUE" *) reg dht_meta;
    (* ASYNC_REG = "TRUE" *) reg dht_sync;
    reg dht_prev;
    wire dht_rise, dht_fall;
    wire [7:0] checksum_calc;
    wire checksum_ok;

    assign checksum_calc = data_reg[39:32] + data_reg[31:24]
                         + data_reg[23:16] + data_reg[15:8];
    assign checksum_ok = (checksum_calc == data_reg[7:0]);
    assign valid = valid_reg;
    assign error = error_reg;
    assign humidity = humidity_reg;
    assign temperature = temperature_reg;

    // Low / High-Z only: never actively drive HIGH against the sensor.
    assign dht11_io = dht11_io_control_reg ? dht11_io_reg : 1'bz;
    assign dht_rise = dht_sync & ~dht_prev;
    assign dht_fall = ~dht_sync & dht_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            dht11_io_control_reg <= 1'b0;
            dht11_io_reg <= 1'b1;
            tick_cnt_reg <= 0;
            bit_cnt_reg <= 0;
            data_reg <= 0;
            valid_reg <= 0;
            error_reg <= 0;
            humidity_reg <= 0;
            temperature_reg <= 0;
        end else begin
            c_state <= n_state;
            dht11_io_control_reg <= dht11_io_control_next;
            dht11_io_reg <= dht11_io_next;
            tick_cnt_reg <= tick_cnt_next;
            bit_cnt_reg <= bit_cnt_next;
            data_reg <= data_next;
            valid_reg <= valid_next;
            error_reg <= error_next;
            humidity_reg <= humidity_next;
            temperature_reg <= temperature_next;
        end
    end

    // Clock-enable based minimum start-to-start interval. Count down in us.
    // Load at reset too, so a real DHT11 has >=1s power-up settling time.
    always @(posedge clk or posedge rst) begin
        if (rst)
            period_cnt_reg <= MIN_PERIOD_US;
        else if (start_accept)
            period_cnt_reg <= MIN_PERIOD_US;
        else if (us_tick && period_cnt_reg != 0)
            period_cnt_reg <= period_cnt_reg - 1'b1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dht_meta <= 1'b1;
            dht_sync <= 1'b1;
            dht_prev <= 1'b1;
        end else begin
            dht_meta <= dht11_io;
            dht_sync <= dht_meta;
            dht_prev <= dht_sync;
        end
    end

    always @(*) begin
        n_state = c_state;
        dht11_io_control_next = dht11_io_control_reg;
        dht11_io_next = dht11_io_reg;
        tick_cnt_next = tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        data_next = data_reg;
        valid_next = valid_reg;
        error_next = error_reg;
        humidity_next = humidity_reg;
        temperature_next = temperature_reg;
        start_accept = 1'b0;

        case (c_state)
            IDLE: begin
                dht11_io_next = 1'b1;
                dht11_io_control_next = 1'b0;
                if (dht11_start && period_cnt_reg == 0 && dht_sync) begin
                    start_accept = 1'b1;
                    tick_cnt_next = 0;
                    bit_cnt_next = 0;
                    data_next = 0;
                    valid_next = 0;
                    error_next = 0;
                    n_state = START;
                end
            end
            START: begin
                dht11_io_next = 1'b0;
                dht11_io_control_next = 1'b1;
                if (us_tick) begin
                    if (tick_cnt_reg == 19_000-1) begin
                        tick_cnt_next = 0;
                        dht11_io_control_next = 1'b0;
                        n_state = WAIT;
                    end else
                        tick_cnt_next = tick_cnt_reg + 1'b1;
                end
            end
            WAIT: begin
                dht11_io_control_next = 1'b0;
                if (dht_fall) begin
                    tick_cnt_next = 0;
                    n_state = SYNC_L;
                end else if (us_tick) begin
                    if (tick_cnt_reg >= TIMEOUT_US-1) begin
                        tick_cnt_next = 0;
                        valid_next = 0;
                        error_next = 1;
                        n_state = IDLE;
                    end else tick_cnt_next = tick_cnt_reg + 1'b1;
                end
            end
            SYNC_L: begin
                dht11_io_control_next = 1'b0;
                if (dht_rise) begin
                    tick_cnt_next = 0;
                    n_state = SYNC_H;
                end else if (us_tick) begin
                    if (tick_cnt_reg >= TIMEOUT_US-1) begin
                        tick_cnt_next = 0;
                        valid_next = 0;
                        error_next = 1;
                        n_state = IDLE;
                    end else tick_cnt_next = tick_cnt_reg + 1'b1;
                end
            end
            SYNC_H: begin
                dht11_io_control_next = 1'b0;
                if (dht_fall) begin
                    tick_cnt_next = 0;
                    n_state = DATA_SYNC;
                end else if (us_tick) begin
                    if (tick_cnt_reg >= TIMEOUT_US-1) begin
                        tick_cnt_next = 0;
                        valid_next = 0;
                        error_next = 1;
                        n_state = IDLE;
                    end else tick_cnt_next = tick_cnt_reg + 1'b1;
                end
            end
            DATA_SYNC: begin
                dht11_io_control_next = 1'b0;
                if (dht_rise) begin
                    tick_cnt_next = 0;
                    n_state = DATA_BIT;
                end else if (us_tick) begin
                    if (tick_cnt_reg >= TIMEOUT_US-1) begin
                        tick_cnt_next = 0;
                        valid_next = 0;
                        error_next = 1;
                        n_state = IDLE;
                    end else tick_cnt_next = tick_cnt_reg + 1'b1;
                end
            end
            DATA_BIT: begin
                dht11_io_control_next = 1'b0;
                if (dht_fall) begin
                    data_next = {data_reg[38:0], (tick_cnt_reg >= 40)};
                    tick_cnt_next = 0;
                    if (bit_cnt_reg == 39)
                        n_state = STOP;
                    else begin
                        bit_cnt_next = bit_cnt_reg + 1'b1;
                        n_state = DATA_SYNC;
                    end
                end else if (us_tick) begin
                    if (tick_cnt_reg >= TIMEOUT_US-1) begin
                        tick_cnt_next = 0;
                        valid_next = 0;
                        error_next = 1;
                        n_state = IDLE;
                    end else tick_cnt_next = tick_cnt_reg + 1'b1;
                end
            end
            STOP: begin
                dht11_io_control_next = 1'b0;
                if (dht_rise) begin
                    if (checksum_ok) begin
                        humidity_next = data_reg[39:24];
                        temperature_next = data_reg[23:8];
                        valid_next = 1;
                        error_next = 0;
                    end else begin
                        valid_next = 0;
                        error_next = 1;
                    end
                    tick_cnt_next = 0;
                    n_state = IDLE;
                end else if (us_tick) begin
                    if (tick_cnt_reg >= TIMEOUT_US-1) begin
                        tick_cnt_next = 0;
                        valid_next = 0;
                        error_next = 1;
                        n_state = IDLE;
                    end else tick_cnt_next = tick_cnt_reg + 1'b1;
                end
            end
            default: begin
                dht11_io_control_next = 1'b0;
                tick_cnt_next = 0;
                valid_next = 0;
                error_next = 1;
                n_state = IDLE;
            end
        endcase
    end
endmodule


```

---

## `sources_1/imports/new/fifo.v`

```verilog
`timescale 1ns / 1ps


module fifo #(
    parameter DEPTH = 4,
    A_BIT_WIDTH = $clog2(DEPTH),
    D_BIT_WIDTH = 8
) (
    input                    clk,
    input                    rst,
    input                    push,
    input                    pop,
    input  [D_BIT_WIDTH-1:0] push_data,
    output [D_BIT_WIDTH-1:0] pop_data,
    output                   full,
    output                   empty
);
    wire [A_BIT_WIDTH-1:0] w_wptr, w_rptr;
    register_file #(
        .DEPTH(DEPTH),
        .D_BIT_WIDTH(D_BIT_WIDTH)
    ) U_REG_FILE (
        .clk  (clk),
        .we   ((~full&push)),
        .wdata(push_data),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .rdata(pop_data)
    );

    fifo_control_unit #(
        .A_BIT_WIDTH(A_BIT_WIDTH)
    ) U_CONTROL_UNIT (
        .clk  (clk),
        .rst  (rst),
        .push (push),
        .pop  (pop),
        .wptr (w_wptr),
        .rptr (w_rptr),
        .full (full),
        .empty(empty)
    );



endmodule


module register_file #(
    parameter DEPTH = 4,
    A_BIT_WIDTH = $clog2(DEPTH),
    D_BIT_WIDTH = 8
) (
    input                      clk,
    input                      we,
    input  [ D_BIT_WIDTH -1:0] wdata,
    input  [A_BIT_WIDTH - 1:0] waddr,
    input  [A_BIT_WIDTH - 1:0] raddr,
    output [ D_BIT_WIDTH -1:0] rdata
);

    //ram
    reg [D_BIT_WIDTH-1:0] register_file[0:DEPTH-1];


    // write SL
    always @(posedge clk) begin
        if (we) begin
            register_file[waddr] <= wdata;
        end
    end
    // read CL
    assign rdata = register_file[raddr];
endmodule


module fifo_control_unit #(
    parameter A_BIT_WIDTH = 2
) (
    input                      clk,
    input                      rst,
    input                      push,
    input                      pop,
    output [A_BIT_WIDTH-1 : 0] wptr,
    output [A_BIT_WIDTH-1 : 0] rptr,
    output                     full,
    output                     empty
);

    reg [A_BIT_WIDTH-1 : 0] wptr_reg, wptr_next;
    reg [A_BIT_WIDTH-1 : 0] rptr_reg, rptr_next;

    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            wptr_reg  <= 1'b0;
            rptr_reg  <= 1'b0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end


    //next, output
    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        //concatenation operator
        case ({
            push, pop
        })  //2bit state를 결합연산자로 생성

            2'b00: begin
                //초기상태
                if (rst) begin
                    full_next  = 1'b0;
                    empty_next = 1'b1;
                    wptr_next  = 1'b0;
                    rptr_next  = 1'b0;
                end
            end
            2'b01: begin
                //pop only
                if (!empty_reg) begin
                    full_next = 1'b0;
                    rptr_next = rptr_reg + 1;
                    if (rptr_next == wptr_reg) begin
                        empty_next = 1'b1;
                    end
                end
            end

            2'b10: begin
                // push only
                if (!full_reg) begin
                    empty_next = 1'b0;
                    wptr_next  = wptr_reg + 1;
                    if (wptr_next == rptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end

            2'b11: begin
                //push,pop
                if (full_reg) begin
                    rptr_next = rptr_reg + 1;
                    full_next = 0;
                end else if (empty_reg) begin
                    wptr_next  = wptr_reg + 1;
                    empty_next = 0;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end
        endcase
    end


endmodule

```

---

## `sources_1/imports/new/fnd_controller_stopwatch_watch.v`

```verilog
`timescale 1ns / 1ps

module fnd_controller_stopwatch_watch #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input sw_display_mode,
    input [MSEC_BIT_WIDTH-1:0] msec,
    input [SEC_BIT_WIDTH-1:0] sec,
    input [MIN_BIT_WIDTH-1:0] min,
    input [HOUR_BIT_WIDTH-1:0] hour,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    wire [2:0] w_ds_sel;
    //wire w_clk_800hz;
    wire w_clk_1600hz;
    // msec, sec, min, hour
    wire [3:0] w_msec_ds1, w_msec_ds10;
    wire [3:0] w_sec_ds1, w_sec_ds10;
    wire [3:0] w_min_ds1, w_min_ds10;
    wire [3:0] w_hour_ds1, w_hour_ds10;
    wire [3:0] w_mux_out, w_msec_sec_mux_out, w_min_hour_mux_out;
    wire w_dot_onoff;

    // clk_div_800hz U_CLK_DIV_800HZ (
    //     .clk(clk),
    //     .rst(rst),
    //     .o_clk_800hz(w_clk_800hz)

    // );


    // counter_8 U_COUNTER_8 (
    //     .clk(w_clk_800hz),
    //     .rst(rst),
    //     .ds_sel(w_ds_sel)
    // );

    clk_div_1600hz U_CLK_DIV_1600HZ (
        .clk(clk),
        .rst(rst),
        .o_clk_1600hz(w_clk_1600hz)
    );

    counter_8 U_COUNTER_8 (
        .clk(w_clk_1600hz),
        .rst(rst),
        .ds_sel(w_ds_sel)
    );
    decoder_2x4 U_DECODER_2x4 (
        .ds_sel (w_ds_sel[1:0]),
        .fnd_com(fnd_com)
    );


    // msec ds
    digit_splitter #(
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_DIGIT_SPLITTER (
        .dsin(msec),
        .ds1 (w_msec_ds1),  //digit 1
        .ds10(w_msec_ds10)  //digit 10

    );
    // sec ds
    digit_splitter #(
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_DIGIT_SPLITTER (
        .dsin(sec),
        .ds1 (w_sec_ds1),  //digit 1
        .ds10(w_sec_ds10)  //digit 10

    );

    // min ds
    digit_splitter #(
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_DIGIT_SPLITTER (
        .dsin(min),
        .ds1 (w_min_ds1),  //digit 1
        .ds10(w_min_ds10)  //digit 10

    );
    // hour ds
    digit_splitter #(
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_DIGIT_SPLITTER (
        .dsin(hour),
        .ds1 (w_hour_ds1),  //digit 1
        .ds10(w_hour_ds10)  //digit 10

    );

    dot_comparator U_DOT_COMP (
    .msec(msec),
    .dot_onoff(w_dot_onoff)
);



    mux_8x1 U_MSEC_SEC_MUX_8x1 (
        .sel(w_ds_sel),
        .in0(w_msec_ds1),
        .in1(w_msec_ds10),
        .in2(w_sec_ds1),
        .in3(w_sec_ds10),
        .in4(4'hf),
        .in5(4'hf),
        .in6({3'b111,w_dot_onoff}), //dot display
        .in7(4'hf),
        .mux_out(w_msec_sec_mux_out)
    );
    mux_8x1 U_MIN_HOUR_MUX_8x1 (
        .sel(w_ds_sel),
        .in0(w_min_ds1),
        .in1(w_min_ds10),
        .in2(w_hour_ds1),
        .in3(w_hour_ds10),
        .in4(4'hf),
        .in5(4'hf),
        .in6({3'b111,w_dot_onoff}),//dot display
        .in7(4'hf),
        .mux_out(w_min_hour_mux_out)
    );

    mux_2x1 U_MUX_DISPLAY_MODE (
        .sel(sw_display_mode),
        .in0(w_msec_sec_mux_out),
        .in1(w_min_hour_mux_out),
        .mux_out(w_mux_out)
    );

    bcd U_BCD (
        .bin(w_mux_out),
        .fnd_font(fnd_font)
    );

endmodule

module dot_comparator (
    input  [6:0] msec,
    output       dot_onoff
);

    // true : 1 off, 0 dot on
    assign dot_onoff = ( msec >= 50 );

endmodule


module mux_2x1 (
    input sel,
    input [3:0] in0,
    input [3:0] in1,
    output [3:0] mux_out
);

    assign mux_out = (sel) ? in1 : in0;


endmodule


// module clk_div_800hz (
//     input clk,
//     input rst,
//     output reg o_clk_800hz
// );
//     reg [$clog2(62_500)-1:0] counter_reg;
//     always @(posedge clk, posedge rst) begin
//         if (rst) begin
//             counter_reg <= 16'd0;
//             o_clk_800hz <= 1'b0;
//         end else begin
//             counter_reg <= counter_reg + 1;
//             if (counter_reg == (62_500 - 1)) begin
//                 counter_reg <= 16'd0;
//                 o_clk_800hz <= ~o_clk_800hz;
//             end
//         end
//     end

// endmodule


module clk_div_1600hz (
    input clk,
    input rst,
    output reg o_clk_1600hz
);

    // 100MHz -> 1600Hz
    // Half Period = 100,000,000 / (1600 * 2)
    parameter HALF_PERIOD = 31_250;

    reg [$clog2(HALF_PERIOD)-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_clk_1600hz <= 1'b0;
        end
        else begin
            if (counter_reg == HALF_PERIOD - 1) begin
                counter_reg <= 0;
                o_clk_1600hz <= ~o_clk_1600hz;
            end
            else begin
                counter_reg <= counter_reg + 1'b1;
            end
        end
    end

endmodule


// module clk_div_800hz (

//     input  clk,
//     input  reset,
//     output reg o_clk_800hz

// );

//     reg [$clog2(100_000)-1:0] counter_reg;

//     always @(posedge clk, posedge reset) begin
//         if (reset) begin
//             counter_reg <= 0;
//             o_clk_800hz <= 1'b0;
//         end
//         else begin

//             // LOW : 100,000 clk
//             if ((o_clk_800hz == 1'b0) &&
//                 (counter_reg == (100_000-1))) begin

//                 counter_reg <= 0;
//                 o_clk_800hz <= 1'b1;

//             end

//             // HIGH : 25,000 clk
//             else if ((o_clk_800hz == 1'b1) &&
//                      (counter_reg == (25_000-1))) begin

//                 counter_reg <= 0;
//                 o_clk_800hz <= 1'b0;

//             end

//             else begin
//                 counter_reg <= counter_reg + 1;
//             end
//         end
//     end

// endmodule

module counter_8 (
    input        clk,
    input        rst,
    output [2:0] ds_sel
);
    reg [2:0] counter_reg;

    assign ds_sel = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            // reset : 1'b1
            counter_reg <= 3'b0;
        end else begin
            // operation
            counter_reg <= counter_reg + 1;
        end
    end


endmodule

module decoder_2x4 (
    input      [1:0] ds_sel,
    output reg [3:0] fnd_com

);

    always @(ds_sel) begin
        case (ds_sel)
            2'b00:   fnd_com = 4'b1110;
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1111;
        endcase
    end
endmodule


module mux_8x1 (
    input [2:0] sel,
    input [3:0] in0,
    input [3:0] in1,
    input [3:0] in2,
    input [3:0] in3,
    input [3:0] in4,
    input [3:0] in5,
    input [3:0] in6,
    input [3:0] in7,
    output reg [3:0] mux_out

);

    always @(*) begin  // * : all input을 sensitivity list에 넣어라
        case (sel)
            3'b000:   mux_out = in0;
            3'b001:   mux_out = in1;
            3'b010:   mux_out = in2;
            3'b011:   mux_out = in3;
            3'b100:   mux_out = in4;
            3'b101:   mux_out = in5;
            3'b110:   mux_out = in6;
            3'b111:   mux_out = in7;
            default: mux_out = in0;
        endcase

    end



endmodule





module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] dsin,
    output [3:0] ds1,  //digit 1
    output [3:0] ds10  //digit 10

);

    assign ds1  = dsin % 10;  // 나머지 연산자 %, digit 1
    assign ds10 = (dsin / 10) % 10;  // digit10

endmodule


module bcd (
    input      [3:0] bin,
    output reg [7:0] fnd_font

);

    always @(bin) begin //always 구문에서는 왼쪽이 출력, 오른쪽이 입력, 따라서 fnd font는 reg 여야 한다.
        case (bin)
            4'b0000: fnd_font = 8'hc0;
            4'b0001: fnd_font = 8'hf9;
            4'b0010: fnd_font = 8'ha4;
            4'b0011: fnd_font = 8'hb0;
            4'b0100: fnd_font = 8'h99;
            4'b0101: fnd_font = 8'h92;
            4'b0110: fnd_font = 8'h82;
            4'b0111: fnd_font = 8'hf8;
            4'b1000: fnd_font = 8'h80;
            4'b1001: fnd_font = 8'h90;
            4'b1010: fnd_font = 8'h88;
            4'b1011: fnd_font = 8'h83;
            4'b1100: fnd_font = 8'hc6;
            4'b1101: fnd_font = 8'ha1;
            4'b1110: fnd_font = 8'h7f;  // : segment dot only on
            4'b1111: fnd_font = 8'hff;  // : segment off
            default: fnd_font = 8'hff;
        endcase
    end

endmodule

```

---

## `sources_1/imports/new/integrated_control_unit.v`

```verilog

`timescale 1ns / 1ps

module integrated_control_unit (
    input [2:0] sw_mode,

    // Debounced button pulses
    input btn_r,
    input btn_l,
    input btn_u,
    input btn_d,

    // UART ASCII Decoder pulses
    input cmd_r,
    input cmd_c,
    input cmd_u,
    input cmd_s,

    // Stopwatch control
    output reg sw_run_stop,
    output reg sw_clear,
    output reg sw_mode_btn,
    output reg sw_lap,

    // Watch control
    output reg watch_right,
    output reg watch_left,
    output reg watch_up,
    output reg watch_down,

    // Sensor control
    output reg sr04_start,
    output reg dht11_start,

    // UART status request
    output reg status_request
);

    localparam STOPWATCH = 3'b000,
               WATCH     = 3'b001,
               SR04      = 3'b010,
               DHT11     = 3'b011;

    reg uart_r, uart_c, uart_u, uart_s;

    // UART command priority: R > C > U > S
    always @(*) begin
        uart_r = 1'b0;
        uart_c = 1'b0;
        uart_u = 1'b0;
        uart_s = 1'b0;

        if (cmd_r)
            uart_r = 1'b1;
        else if (cmd_c)
            uart_c = 1'b1;
        else if (cmd_u)
            uart_u = 1'b1;
        else if (cmd_s)
            uart_s = 1'b1;
    end

    // Mode-based command distribution
    always @(*) begin
        sw_run_stop    = 1'b0;
        sw_clear       = 1'b0;
        sw_mode_btn    = 1'b0;
        sw_lap         = 1'b0;

        watch_right    = 1'b0;
        watch_left     = 1'b0;
        watch_up       = 1'b0;
        watch_down     = 1'b0;

        sr04_start     = 1'b0;
        dht11_start    = 1'b0;
        status_request = 1'b0;

        case (sw_mode)
            STOPWATCH: begin
                sw_run_stop    = btn_r | uart_r;
                sw_clear       = btn_l | uart_c;
                sw_mode_btn    = btn_u | uart_u;
                sw_lap         = btn_d;
                status_request = uart_s;
            end

            WATCH: begin
                watch_right    = btn_r | uart_r;
                watch_left     = btn_l | uart_c;
                watch_up       = btn_u | uart_u;
                watch_down     = btn_d;
                status_request = uart_s;
            end

            SR04: begin
                sr04_start     = btn_r | uart_r;
                status_request = uart_s;
            end

            DHT11: begin
                dht11_start    = btn_r | uart_r;
                status_request = uart_s;
            end

            default: begin
                // Reserved modes: no action
            end
        endcase
    end

endmodule

```

---

## `sources_1/imports/new/lap_time.v`

```verilog
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

```

---

## `sources_1/imports/new/reset_controller.v`

```verilog
`timescale 1ns / 1ps

// Two-FF synchronization + stable-level qualification.
// A new value must be stable for STABLE_CYCLES clock cycles.
// For Basys3 100 MHz, 1_000_000 cycles = 10 ms.
module reset_input_filter #(
    parameter integer STABLE_CYCLES = 1_000_000
) (
    input  wire clk,
    input  wire raw_in,
    output reg  stable_out = 1'b0
);
    localparam integer CNT_WIDTH = (STABLE_CYCLES <= 1) ? 1 : $clog2(
        STABLE_CYCLES
    );

    reg sync_ff1 = 1'b0;
    reg sync_ff2 = 1'b0;
    reg [CNT_WIDTH-1:0] stable_count = 0;

    always @(posedge clk) begin
        sync_ff1 <= raw_in;
        sync_ff2 <= sync_ff1;

        if (sync_ff2 == stable_out) begin
            stable_count <= 0;
        end else if (stable_count == STABLE_CYCLES - 1) begin
            stable_out   <= sync_ff2;
            stable_count <= 0;
        end else begin
            stable_count <= stable_count + 1'b1;
        end
    end
endmodule

// Reset policy:
// BTNC (btn_reset): one press resets the mode selected by stable SW0.
// SW15: active-high, LEVEL-sensitive global reset (ON=hold both in reset).
// SW0 changes alone NEVER generate a reset.
// A short FPGA power-up reset initializes both modes after configuration.
// All reset outputs change on clk falling edges so asynchronous reset release
// occurs away from the downstream modules' clk rising edges.
module reset_controller #(
    parameter integer SW_STABLE_CYCLES  = 1_000_000,
    parameter integer BTN_STABLE_CYCLES = 1_000_000,
    parameter integer POWERUP_CYCLES    = 16,

    parameter integer SW0_STABLE_CYCLES = SW_STABLE_CYCLES,
    parameter integer USE_RESET_ENABLE  = 0
) (
    input  wire clk,
    input  wire btn_reset,      // Physical BTNC (formerly shared rst)
    input  wire reset_enable,   // 신규: Selected Reset 허용
    input  wire sw0,            // Physical SW0: 0=Watch, 1=Stopwatch
    input  wire sw15,           // Physical SW15: 1=global reset
    output wire sw0_clean,      // Stabilized mode used throughout the Top
    output wire rst_watch,
    output wire rst_stopwatch,
    output wire rst_shared      // Global reset only: shared debouncers, FND
);
    wire sw15_clean;
    wire btn_reset_clean;

    reset_input_filter #(
        .STABLE_CYCLES(SW0_STABLE_CYCLES)
    ) U_FILTER_SW0 (
        .clk(clk),
        .raw_in(sw0),
        .stable_out(sw0_clean)
    );
    reset_input_filter #(
        .STABLE_CYCLES(SW_STABLE_CYCLES)
    ) U_FILTER_SW15 (
        .clk(clk),
        .raw_in(sw15),
        .stable_out(sw15_clean)
    );
    reset_input_filter #(
        .STABLE_CYCLES(BTN_STABLE_CYCLES)
    ) U_FILTER_BTNC (
        .clk(clk),
        .raw_in(btn_reset),
        .stable_out(btn_reset_clean)
    );

    // FPGA initial values are implemented by the Xilinx configuration/GSR.
    // This ensures Watch starts at 12:00 even when SW15 is initially OFF.
    localparam integer POR_WIDTH = (POWERUP_CYCLES <= 1) ? 1 : $clog2(
        POWERUP_CYCLES + 1
    );
    reg [POR_WIDTH-1:0] por_count = 0;
    wire por_active = (por_count < POWERUP_CYCLES);

    always @(posedge clk) begin
        if (por_active) por_count <= por_count + 1'b1;
    end

    reg  btn_reset_previous = 1'b0;
    reg  pulse_watch = 1'b0;
    reg  pulse_stopwatch = 1'b0;
    wire global_request = por_active | sw15_clean;
    wire selected_reset_enable;

    assign selected_reset_enable =
    (USE_RESET_ENABLE == 0) ? 1'b1 : reset_enable;

    always @(posedge clk) begin
        btn_reset_previous <= btn_reset_clean;
        pulse_watch        <= 1'b0;
        pulse_stopwatch    <= 1'b0;
        // One mode-specific reset pulse per BTNC press; the selected mode
        // is latched by this pulse. Holding BTNC and switching SW0 does not
        // reset the other mode.
        if (btn_reset_clean && !btn_reset_previous && !global_request && selected_reset_enable) begin
            if (sw0_clean) pulse_stopwatch <= 1'b1;
            else pulse_watch <= 1'b1;
        end
    end

    reg rst_shared_reg = 1'b1;
    reg rst_watch_reg = 1'b1;
    reg rst_stopwatch_reg = 1'b1;

    always @(negedge clk) begin
        rst_shared_reg    <= global_request;
        rst_watch_reg     <= global_request | pulse_watch;
        rst_stopwatch_reg <= global_request | pulse_stopwatch;
    end

    assign rst_shared    = rst_shared_reg;
    assign rst_watch     = rst_watch_reg;
    assign rst_stopwatch = rst_stopwatch_reg;
endmodule

```

---

## `sources_1/imports/new/sensor_fnd_controller.v`

```verilog

`timescale 1ns / 1ps

module sensor_fnd_controller (
    input clk,
    input rst,

    input [2:0] sw_mode,
    input sw_display_mode,

    input [8:0] distance,
    input [15:0] humidity,
    input [15:0] temperature,
    input dht_valid,
    input dht_error,

    output reg [3:0] fnd_com,
    output reg [7:0] fnd_font
);

    // ========================================
    // 1. Sensor Data MUX
    // ========================================

    reg [8:0] display_value;
    reg [7:0] prefix_font;
    reg show_wait;
    reg show_error;

    always @(*) begin
        display_value = 9'd0;
        prefix_font   = 8'hFF;
        show_wait     = 1'b0;
        show_error    = 1'b0;

        case (sw_mode)
            3'b010: begin
                // HC-SR04: d + 3-digit distance
                display_value = distance;
                prefix_font = 8'hA1;  // d
            end

            3'b011: begin
                // DHT11
                if (dht_error) begin
                    show_error = 1'b1;
                end
                else if (!dht_valid) begin
                    show_wait = 1'b1;
                end
                else if (sw_display_mode == 1'b0) begin
                    // Humidity integer part
                    display_value = {1'b0, humidity[15:8]};
                    prefix_font = 8'h89;  // H
                end
                else begin
                    // Temperature integer part
                    display_value = {1'b0, temperature[15:8]};
                    prefix_font = 8'h87;  // t
                end
            end

            default: begin
                // No sensor display
            end
        endcase
    end


    // ========================================
    // 2. Decimal Digit Splitter
    // ========================================

    wire [3:0] digit_100;
    wire [3:0] digit_10;
    wire [3:0] digit_1;

    assign digit_100 = display_value / 9'd100;
    assign digit_10  = (display_value % 9'd100) / 9'd10;
    assign digit_1   = display_value % 9'd10;


    // ========================================
    // 3. BCD to 7-Segment
    // ========================================

    wire [7:0] font_100;
    wire [7:0] font_10;
    wire [7:0] font_1;

    bcd U_BCD_100 (
        .bin(digit_100),
        .fnd_font(font_100)
    );

    bcd U_BCD_10 (
        .bin(digit_10),
        .fnd_font(font_10)
    );

    bcd U_BCD_1 (
        .bin(digit_1),
        .fnd_font(font_1)
    );


    // ========================================
    // 4. FND Scan Counter
    // ========================================

    // 100MHz Clock
    // 25,000 cycles / digit = 250us
    // 4 digits = 1ms (1kHz refresh)

    reg [14:0] scan_cnt_reg;
    reg [1:0] digit_sel_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_cnt_reg <= 0;
            digit_sel_reg <= 0;
        end
        else begin
            if (scan_cnt_reg == 15'd24999) begin
                scan_cnt_reg <= 0;
                digit_sel_reg <= digit_sel_reg + 1'b1;
            end
            else begin
                scan_cnt_reg <= scan_cnt_reg + 1'b1;
            end
        end
    end


    // ========================================
    // 5. FND Digit MUX
    // ========================================

    always @(*) begin
        fnd_com  = 4'b1111;
        fnd_font = 8'hFF;

        if ((sw_mode == 3'b010) ||
            (sw_mode == 3'b011)) begin

            case (digit_sel_reg)
                2'b00: begin
                    fnd_com  = 4'b1110;
                    fnd_font = font_1;
                end

                2'b01: begin
                    fnd_com  = 4'b1101;
                    fnd_font = font_10;
                end

                2'b10: begin
                    fnd_com  = 4'b1011;
                    fnd_font = font_100;
                end

                2'b11: begin
                    fnd_com  = 4'b0111;
                    fnd_font = prefix_font;
                end

                default: begin
                    fnd_com  = 4'b1111;
                    fnd_font = 8'hFF;
                end
            endcase

            // DHT11: waiting / measuring
            if (show_wait) begin
                fnd_font = 8'hBF;  // '-'
            end

            // DHT11: communication error
            else if (show_error) begin
                case (digit_sel_reg)
                    2'b00: fnd_font = 8'hFF; // blank
                    2'b01: fnd_font = 8'hAF; // r
                    2'b10: fnd_font = 8'hAF; // r
                    2'b11: fnd_font = 8'h86; // E
                    default: fnd_font = 8'hFF;
                endcase
            end
        end
    end

endmodule

```

---

## `sources_1/imports/new/sr04_top.v`

```verilog
`timescale 1ns / 1ps


module sr04_top #(
    parameter integer MIN_PERIOD_US = 60_000
) (
    input clk,
    input rst,
    input start,
    input echo,
    output trigger,
    output [8:0] distance,
    output [2:0] debug_state
);

    wire w_us_tick;
    wire w_enable;
    wire w_clear;



    SR04_sensor #(
        .MIN_PERIOD_US(MIN_PERIOD_US),
        .CLOCKS_PER_US(100)
    ) U_SR04_SENSOR (
        .clk(clk),
        .start(start),
        .rst(rst),
        .us_tick(w_us_tick),
        .echo(echo),
        .trigger(trigger),
        .enable(w_enable),
        .clear(w_clear),
        .distance(distance),
        .debug_state(debug_state)
    );

    baud_tick_gen_sr04 #(
        .F_COUNT(100)
    ) U_BAUD_TICK_GEN_SR04 (
        .clk(clk),
        .rst(rst),
        .enable(w_enable),
        .clear(w_clear),
        .b_tick(w_us_tick)


    );
endmodule

```

---

## `sources_1/imports/new/stopwatch.v`

```verilog
`timescale 1ns / 1ps



module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                       clk,
    input                       rst,
    input                       run_stop,
    input                       clear,
    input                       mode,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [ SEC_BIT_WIDTH-1:0] sec,
    output [ MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour
);


    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;

    tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_hour),
        .clear     (clear),
        .mode      (mode),
        .time_count(hour),
        .o_tick    ()
    );

    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_min),
        .clear     (clear),
        .mode      (mode),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_sec),
        .clear     (clear),
        .mode      (mode),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_10ms),
        .clear     (clear),
        .mode      (mode),
        .time_count(msec),
        .o_tick    (w_tick_sec)
    );

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(run_stop),
        .clear   (clear),
        .o_tick  (w_tick_10ms)  // 100hz tick
    );

endmodule


module tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input clk,
    input rst,
    input i_tick,
    input clear,
    input mode,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick

);

    reg [$clog2(TIMES)-1:0] counter_reg;

    assign time_count = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (mode) begin
                // downcount
                if (i_tick) begin
                    counter_reg <= counter_reg - 1;
                    if (counter_reg == 0) begin
                        counter_reg <= TIMES - 1;
                        o_tick <= 1'b1;
                    end

                end else begin
                    o_tick <= 1'b0;

                end
            end else begin
                //upcount
                if (i_tick) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg == TIMES - 1) begin
                        counter_reg <= 0;
                        o_tick <= 1'b1;
                    end
                end else begin
                    o_tick <= 1'b0;
                end
            end
        end
    end

    //     always @(posedge clk, posedge rst) begin
    //     if (rst | clear) begin
    //         counter_reg <= 0;
    //         o_tick <= 1'b0;
    //     end
    //     else begin
    //         o_tick <= 1'b0;  // 기본값

    //         if (i_tick) begin
    //             if (mode) begin
    //                 // DOWN Count
    //                 if (counter_reg == 0) begin
    //                     counter_reg <= TIMES - 1;
    //                     o_tick <= 1'b1;
    //                 end
    //                 else begin
    //                     counter_reg <= counter_reg - 1;
    //                 end
    //             end
    //             else begin
    //                 // UP Count
    //                 if (counter_reg == TIMES - 1) begin
    //                     counter_reg <= 0;
    //                     o_tick <= 1'b1;
    //                 end
    //                 else begin
    //                     counter_reg <= counter_reg + 1;
    //                 end
    //             end
    //         end
    //     end
    // end


endmodule

module tick_gen_100hz (
    input clk,
    input rst,
    input run_stop,
    input clear,
    output reg o_tick  // 100hz tick
);

    //100Mhz -> 100Hz
    parameter F_COUNTER = 100_000_000 / 100;
    reg [$clog2(F_COUNTER)-1:0] counter_reg;


    always @(posedge clk, posedge rst) begin

        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNTER - 1)) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                // run_stop이 1이고 o_tick이 1일때 run_stop이 0으로 바뀌면,
                // 계속 o_tick이 1로 남는 경우를 해결하기 위함.
                o_tick <= 1'b0;
            end
        end
    end


endmodule






```

---

## `sources_1/imports/new/uart.v`

```verilog
`timescale 1ns / 1ps

module uart_fifo_loopback (
    input clk,
    input rst,
    input fifo_rx_pop,
    input rx,           // from PC

    input        fifo_tx_push,
    input  [7:0] fifo_tx_push_data,
    output       fifo_tx_full,
    output       tx,                 //to pc
    output [7:0] rx_pop_data,
    output       rx_empty
);
    wire w_b_tick;
    wire w_rx_done;
    wire [7:0] w_rx_data, w_fifo_rx_pop_data, w_fifo_tx_pop_data;
    wire w_fifo_tx_full, w_fifo_rx_empty, w_fifo_tx_empty, w_tx_busy;

    assign rx_pop_data = w_fifo_rx_pop_data;
    assign rx_empty = ~w_fifo_rx_empty;
    assign fifo_tx_full = w_fifo_tx_full;
    wire w_tx_start;
    reg  tx_start_hold_reg;

    assign w_tx_start = !w_fifo_tx_empty && !w_tx_busy && !tx_start_hold_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_start_hold_reg <= 1'b0;
        end else begin
            if (w_tx_start) tx_start_hold_reg <= 1'b1;
            else if (w_tx_busy) tx_start_hold_reg <= 1'b0;
        end
    end
    // uart rx
    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick),
        .rx(rx),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)

    );
    fifo #(
        .DEPTH(16)
    ) U_FIFO_RX (
        .clk      (clk),
        .rst      (rst),
        .push     (w_rx_done),           //from integrated ASCII Sender
        .pop      (fifo_rx_pop),
        .push_data(w_rx_data),
        .pop_data (w_fifo_rx_pop_data),
        .full     (),
        .empty    (w_fifo_rx_empty)
    );

    fifo U_FIFO_TX (
        .clk      (clk),
        .rst      (rst),
        .push     (fifo_tx_push),        //from integrated ASCII Sender
        .pop      (w_tx_start),
        .push_data(fifo_tx_push_data),
        .pop_data (w_fifo_tx_pop_data),
        .full     (w_fifo_tx_full),
        .empty    (w_fifo_tx_empty)
    );


    //uart TX
    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_tx_start),
        .tx_data(w_fifo_tx_pop_data),
        .b_tick(w_b_tick),
        .tx(tx),
        .tx_busy(w_tx_busy)
    );



    baud_tick_gen U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule



module baud_tick_gen (
    input      clk,
    input      rst,
    output reg b_tick
);
    //100MHz -> 9600Hz
    parameter F_COUNT = 100_000_000 / (9600 * 16);
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin

            counter_reg <= counter_reg + 1;

            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end


endmodule



```

---

## `sources_1/imports/new/uart_ascii_decoder.v`

```verilog
`timescale 1ns / 1ps


// module uart_ascii_decoder (
//     input clk,
//     input rst,
//     input rx,
//     output tx,
//     //fnd
//     output [3:0] fnd_com,
//     output [7:0] fnd_font
// );

//     wire w_rx_done;
//     wire [7:0] w_rx_data;
//     wire [3:0] w_bin;

//     uart_fifo_loopback UART_FIFO_LOOPBACK (
//         .clk(clk),
//         .rst(rst),
//         // .rx_done(w_rx_done),
//         // .rx_data(w_rx_data),
//         .rx(rx),  // from PC
//         .tx(tx)  //to pc
//     );

//     ascii_decoder U_ASCII_DECODER (
//         .clk(clk),
//         .rst(rst),
//         .enable(w_rx_done),
//         .ascii(w_rx_data),
//         .bin(w_bin)

//     );
//     fnd_controller FND_CNT (
//         .clk(clk),
//         .rst(rst),
//         .fnd_data(w_bin),
//         .fnd_com(fnd_com),
//         .fnd_font(fnd_font)
//     );


// endmodule

module ascii_decoder (
    input            clk,
    input            rst,
    input            enable,
    input      [7:0] ascii,
    output           run_stop,
    output           clear,
    output           mode,
    output           status,
    output reg [3:0] bin,
    output reg       pop,
    output reg       mode_sel_valid,
    output reg [2:0] mode_sel


);



    reg [7:0] data_reg, data_next;  //0~f 까지 처리 
    reg edge_run_stop_reg, edge_clear_reg, edge_mode_reg, edge_status_reg;

    assign run_stop = edge_run_stop_reg;
    assign clear = edge_clear_reg;
    assign mode = edge_mode_reg;
    assign status = edge_status_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            data_reg <= 0;
        end else begin
            data_reg <= data_next;
        end
    end

    always @(*) begin
        bin = 4'h0;
        pop = 1'b0;
        data_next = data_reg;
        if (enable) begin
            data_next = ascii;
            pop = 1'b1;
        end else begin
            case (data_reg)
                8'h30: bin = 4'h0;
                8'h31: bin = 4'h1;
                8'h32: bin = 4'h2;
                8'h33: bin = 4'h3;
                8'h34: bin = 4'h4;
                8'h35: bin = 4'h5;
                8'h36: bin = 4'h6;
                8'h37: bin = 4'h7;
                8'h38: bin = 4'h8;
                8'h39: bin = 4'h9;
                8'h41, 8'h61: bin = 4'ha;
                8'h42, 8'h62: bin = 4'hb;
                8'h43, 8'h63: bin = 4'hc;
                8'h44, 8'h64: bin = 4'hd;
                8'h45, 8'h65: bin = 4'he;
                8'h46, 8'h66: bin = 4'hf;

            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            edge_run_stop_reg <= 1'b0;
            edge_clear_reg    <= 1'b0;
            edge_mode_reg     <= 1'b0;
            edge_status_reg   <= 1'b0;
            mode_sel_valid    <= 1'b0;
            mode_sel          <= 3'b000;
        end else begin
            edge_run_stop_reg <= 1'b0;
            edge_clear_reg <= 1'b0;
            edge_mode_reg <= 1'b0;
            edge_status_reg <= 1'b0;
            mode_sel_valid <= 1'b0;
            if (enable) begin
                case (ascii)
                    8'h52, 8'h72: edge_run_stop_reg <= 1'b1;
                    8'h43, 8'h63: edge_clear_reg <= 1'b1;
                    8'h55, 8'h75: edge_mode_reg <= 1'b1;
                    8'h53, 8'h73: edge_status_reg <= 1'b1;

                    // UART Remote Mode Selection
                    8'h31: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b000;
                    end
                    8'h32: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b001;
                    end
                    8'h33: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b010;
                    end
                    8'h34: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b011;
                    end
                endcase
            end
        end
    end



endmodule

```

---

## `sources_1/imports/new/uart_rx.v`

```verilog
`timescale 1ns / 1ps

module uart_rx (
    input clk,
    input rst,
    input b_tick,
    input rx,
    output [7:0] rx_data,
    output rx_done

);

    localparam [2:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;


    reg [1:0] c_state, n_state;
    reg [2:0] bit_cnt, bit_cnt_next;
    reg [3:0] b_tick_cnt, b_tick_cnt_next;
    reg [7:0] data_reg, data_next;
    reg rx_done_reg, rx_done_next;

    //output
    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    // state SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            b_tick_cnt <= 4'h0;
            bit_cnt <= 3'b000;
            data_reg <= 8'h00;
            rx_done_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            b_tick_cnt <= b_tick_cnt_next;
            bit_cnt <= bit_cnt_next;
            data_reg <= data_next;
            rx_done_reg <= rx_done_next;
        end

    end

    // next, output
    always @(*) begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt;
        bit_cnt_next    = bit_cnt;
        data_next       = data_reg;
        rx_done_next    = rx_done_reg;

        case (c_state)
            IDLE: begin
                b_tick_cnt_next  = 0;
                rx_done_next = 1'b0;
                if (b_tick) begin
                    if (!rx) begin
                        n_state = START;
                    end
                end
            end

            START: begin
                if (b_tick) begin
                    if (b_tick_cnt == 7) begin
                        bit_cnt_next = 0;
                        b_tick_cnt_next = 0;
                        data_next = 8'h00;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end

            DATA: begin

                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        b_tick_cnt_next = 0;
                        // shift right
                        data_next = {rx, data_reg [7:1]};
                        if (bit_cnt == 7) begin
                            n_state = STOP;
                        end else begin
                            // DATA state
                            bit_cnt_next = bit_cnt + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt == 15) begin
                        rx_done_next = 1'b1;
                        n_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt + 1;
                    end
                end
            end
        endcase
    end

endmodule

```

---

## `sources_1/imports/new/uart_tx.v`

```verilog
`timescale 1ns / 1ps


module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx,
    output       tx_busy

);

    localparam [1:0] IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] c_state, n_state;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [7:0] data_reg, data_next;
    reg tx_reg, tx_next;
    reg tx_busy_reg, tx_busy_next;

    //output
    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    // state SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            bit_count_reg <= 3'b0;
            //b_tick_cnt_reg <= b_tick_cnt_next;
            b_tick_cnt_reg <= 0;
            data_reg <= 8'h0;
            tx_reg <= 1'b1;
            tx_busy_reg <= 1'b0;  // no busy
        end else begin
            c_state <= n_state;
            bit_count_reg <= bit_count_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            data_reg <= data_next;
            tx_reg <= tx_next;
            tx_busy_reg <= tx_busy_next;
        end
    end

    // next, output
    always @(*) begin
        n_state         = c_state;
        bit_count_next  = bit_count_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        data_next       = data_reg;
        tx_next         = tx_reg;
        tx_busy_next    = tx_busy_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    bit_count_next  = 3'b0;
                    b_tick_cnt_next = 0;
                    data_next       = tx_data;
                    n_state         = START;
                end
            end
            START: begin
                tx_busy_next = 1'b1;
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            data_next = {1'b0, data_reg[7:1]};
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) n_state = IDLE;
                    else b_tick_cnt_next = b_tick_cnt_reg + 1;
                end
            end
        endcase
    end

endmodule




```

---

## `sources_1/imports/new/watch_control_unit.v`

```verilog
`timescale 1ns / 1ps

// Watch Control Unit - NORMAL phase (time-setting is deferred).
// Buttons are already debounced and routed to this module when SW0=0.
// They are reserved for SW2 time adjustment and do not alter time yet.
module watch_control_unit (
    input wire clk,
    input wire rst,
    input wire sw0,
    input wire sw2,
    input wire sw_display_mode,
    input wire btn_right,
    input wire btn_left,
    input wire btn_up,
    input wire btn_down,

    output wire       watch_select,
    output wire       edit_enable,
    output wire       count_enable,
    output wire [1:0] edit_field,
    output wire       inc_pulse,
    output wire       dec_pulse,
    output wire       blink_enable,
    output wire       fnd_display_mode
);
    // The clock itself is always running in watch_datapath.
    // For now this Control Unit only selects the Watch display path.
    // Watch / Stopwatch 선택
    assign watch_select = ~sw0;

    // Watch 시간 설정 FSM
    watch_setting_fsm U_WATCH_SETTING_FSM (
        .clk(clk),
        .rst(rst),
        .sw0(sw0),
        .sw2(sw2),
        .sw_display_mode(sw_display_mode),

        .btn_right(btn_right),
        .btn_left(btn_left),
        .btn_up(btn_up),
        .btn_down(btn_down),

        .edit_enable(edit_enable),
        .count_enable(count_enable),
        .digit_sel(edit_field),
        .inc_pulse(inc_pulse),
        .dec_pulse(dec_pulse),
        .blink_enable(blink_enable),
        .fnd_display_mode(fnd_display_mode)
    );

endmodule

```

---

## `sources_1/imports/new/watch_datapath_sw2.v`

```verilog
`timescale 1ns / 1ps

// Watch Datapath with SW2 manual time-setting support.
// Intentionally uses a NEW module name so the board-verified
// watch_datapath.v can remain untouched during independent development.
// tick_gen_100hz is reused UNCHANGED from the professor's stopwatch.v.
// The professor's tick_counter and all Stopwatch modules are UNCHANGED.
//
// edit_field: 0=MSEC (0~99), 1=SEC (0~59),
//             2=MIN  (0~59), 3=HOUR(0~23).
// Time-setting increments/decrements affect ONE field only, with wrap;
// no carry/borrow to other fields during editing.
module watch_datapath_sw2 #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       count_enable,
    input  wire                       edit_enable,
    input  wire [1:0]                 edit_field,
    input  wire                       inc_pulse,
    input  wire                       dec_pulse,
    output wire [MSEC_BIT_WIDTH-1:0]  msec,
    output wire [ SEC_BIT_WIDTH-1:0]  sec,
    output wire [ MIN_BIT_WIDTH-1:0]  min,
    output wire [HOUR_BIT_WIDTH-1:0]  hour
);

    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;
    wire w_edit_msec = edit_enable && (edit_field == 2'd0);
    wire w_edit_sec  = edit_enable && (edit_field == 2'd1);
    wire w_edit_min  = edit_enable && (edit_field == 2'd2);
    wire w_edit_hour = edit_enable && (edit_field == 2'd3);

    // Existing 100 MHz -> 100 Hz generator. While paused it holds the
    // divider phase and forces o_tick low. On resume it continues normally.
    tick_gen_100hz U_WATCH_TICK_GEN_100HZ (
        .clk      (clk),
        .rst      (rst),
        .run_stop (count_enable),
        .clear    (1'b0),
        .o_tick   (w_tick_10ms)
    );

    // Watch-only editable counters, unlike the professor's tick_counter,
    // support individual field writes without changing Stopwatch RTL.
    watch_editable_counter #(
        .TIMES(100), .BIT_WIDTH(MSEC_BIT_WIDTH), .RESET_VALUE(0)
    ) U_WATCH_MSEC_COUNTER (
        .clk(clk), .rst(rst), .count_enable(count_enable),
        .i_tick(w_tick_10ms),
        .edit_inc(w_edit_msec && inc_pulse),
        .edit_dec(w_edit_msec && dec_pulse),
        .time_count(msec), .o_tick(w_tick_sec)
    );

    watch_editable_counter #(
        .TIMES(60), .BIT_WIDTH(SEC_BIT_WIDTH), .RESET_VALUE(0)
    ) U_WATCH_SEC_COUNTER (
        .clk(clk), .rst(rst), .count_enable(count_enable),
        .i_tick(w_tick_sec),
        .edit_inc(w_edit_sec && inc_pulse),
        .edit_dec(w_edit_sec && dec_pulse),
        .time_count(sec), .o_tick(w_tick_min)
    );

    watch_editable_counter #(
        .TIMES(60), .BIT_WIDTH(MIN_BIT_WIDTH), .RESET_VALUE(0)
    ) U_WATCH_MIN_COUNTER (
        .clk(clk), .rst(rst), .count_enable(count_enable),
        .i_tick(w_tick_min),
        .edit_inc(w_edit_min && inc_pulse),
        .edit_dec(w_edit_min && dec_pulse),
        .time_count(min), .o_tick(w_tick_hour)
    );

    watch_editable_counter #(
        .TIMES(24), .BIT_WIDTH(HOUR_BIT_WIDTH), .RESET_VALUE(12)
    ) U_WATCH_HOUR_COUNTER (
        .clk(clk), .rst(rst), .count_enable(count_enable),
        .i_tick(w_tick_hour),
        .edit_inc(w_edit_hour && inc_pulse),
        .edit_dec(w_edit_hour && dec_pulse),
        .time_count(hour), .o_tick()
    );

endmodule

// Counter with separate automatic-tick and manual-edit paths.
// Automatic counting: 0 -> TIMES-1 -> 0, generating a 1-clock carry.
// Manual editing:   increment/decrement selected field only, no carry.
// All time registers hold when paused and there is no manual edit pulse.
module watch_editable_counter #(
    parameter integer TIMES       = 100,
    parameter integer BIT_WIDTH   = 7,
    parameter integer RESET_VALUE = 0
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 count_enable,
    input  wire                 i_tick,
    input  wire                 edit_inc,
    input  wire                 edit_dec,
    output wire [BIT_WIDTH-1:0] time_count,
    output reg                  o_tick
);
    reg [BIT_WIDTH-1:0] counter_reg;
    assign time_count = counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= RESET_VALUE;
            o_tick      <= 1'b0;
        end else begin
            // In particular, no old carry pulse may survive a pause/edit.
            o_tick <= 1'b0;

            // Manual writes have priority over any normal time tick.
            if (edit_inc) begin
                if (counter_reg == TIMES - 1)
                    counter_reg <= 0;
                else
                    counter_reg <= counter_reg + 1'b1;
            end else if (edit_dec) begin
                if (counter_reg == 0)
                    counter_reg <= TIMES - 1;
                else
                    counter_reg <= counter_reg - 1'b1;
            end else if (count_enable && i_tick) begin
                if (counter_reg == TIMES - 1) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    counter_reg <= counter_reg + 1'b1;
                end
            end
        end
    end
endmodule

```

---

## `sources_1/imports/new/watch_fnd_blink.v`

```verilog
`timescale 1ns / 1ps

// Watch-only two-digit blink overlay, AFTER the shared FND Controller.
// Does not modify the Stopwatch or the shared FND Controller.
//
// System clock: 100 MHz on Basys3.
// HALF_PERIOD_CYCLES=50_000_000 -> 0.5 s visible / 0.5 s hidden.
// For simulation, override HALF_PERIOD_CYCLES to a small number.
//
// edit_field: 0=MSEC (right pair), 1=SEC (left pair),
//             2=MIN  (right pair), 3=HOUR(left pair).
// FND COM is active LOW, from right to left:
//   AN0=1110, AN1=1101, AN2=1011, AN3=0111.
//
// Only the seven numeric segments (font[6:0]) are hidden.
// DP (font[7]) is passed through unchanged, including a separate
// dot-only scan slot from an 8-phase FND Controller.
// All COM signals are passed through unchanged.
module watch_fnd_blink #(
    parameter integer HALF_PERIOD_CYCLES = 50_000_000
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       watch_select,  // 1: Watch selected by SW0
    input  wire       blink_enable,  // 1: Watch setting FSM editing
    input  wire [1:0] edit_field,    // 0=MSEC, 1=SEC, 2=MIN, 3=HOUR
    input  wire [3:0] fnd_com_in,
    input  wire [7:0] fnd_font_in,
    output wire [3:0] fnd_com_out,
    output wire [7:0] fnd_font_out
);

    localparam integer COUNTER_WIDTH =
        (HALF_PERIOD_CYCLES <= 1) ? 1 : $clog2(HALF_PERIOD_CYCLES);

    reg [COUNTER_WIDTH-1:0] blink_counter;
    reg blink_on;   // 1: numeric segments visible; 0: selected pair hidden

    // Start each Watch setting session with the digits visible.
    // Reset phase while not editing, or while Stopwatch is selected.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            blink_counter <= 0;
            blink_on      <= 1'b1;
        end else if (!watch_select || !blink_enable) begin
            blink_counter <= 0;
            blink_on      <= 1'b1;
        end else if (blink_counter == HALF_PERIOD_CYCLES - 1) begin
            blink_counter <= 0;
            blink_on      <= ~blink_on;
        end else begin
            blink_counter <= blink_counter + 1'b1;
        end
    end

    // HOUR and SEC occupy AN3/AN2 (left pair);
    // MIN and MSEC occupy AN1/AN0 (right pair).
    wire pair_is_left = edit_field[0];
    wire active_left  = !fnd_com_in[3] || !fnd_com_in[2];
    wire active_right = !fnd_com_in[1] || !fnd_com_in[0];
    wire active_selected_pair = pair_is_left ? active_left : active_right;
    wire hide_numbers = watch_select && blink_enable &&
                        !blink_on && active_selected_pair;

    assign fnd_com_out  = fnd_com_in;
    assign fnd_font_out = hide_numbers ? {fnd_font_in[7], 7'b1111111}
                                       : fnd_font_in;

endmodule

```

---

## `sources_1/imports/new/watch_setting.v`

```verilog
`timescale 1ns / 1ps

// SW2 time-setting FSM for the Watch (OPTION).
// This module is independent of the existing Stopwatch control_unit.
// Button inputs must be debounced 1-clock pulses (100MHz system clock).
// SW0=0: Watch selected, SW2=1: time-setting enabled.
// digit_sel: 0=rightmost, 3=leftmost FND numeric digit.
// The FND digit flash oscillator and the time write datapath are separate.
module watch_setting_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       sw0,
    input  wire       sw2,
    input  wire       btn_right,
    input  wire       btn_left,
    input  wire       btn_up,
    input  wire       btn_down,
    input  wire       sw_display_mode,
    output wire       edit_enable,
    output wire       count_enable,
    output reg  [1:0] digit_sel,
    output wire       inc_pulse,
    output wire       dec_pulse,
    output wire       blink_enable,
    output wire       fnd_display_mode
);

    // localparam [2:0] NORMAL = 3'd0,
    //                  SET_D0 = 3'd1,
    //                  SET_D1 = 3'd2,
    //                  SET_D2 = 3'd3,
    //                  SET_D3 = 3'd4;
    parameter NORMAL = 3'd0;
    parameter SET_msec = 3'd1;
    parameter SET_sec = 3'd2;
    parameter SET_min = 3'd3;
    parameter SET_hour = 3'd4;

    reg [2:0] c_state, n_state;
    wire setting_request;

    assign setting_request = (~sw0) & sw2;

    // 1. State register
    always @(posedge clk or posedge rst) begin
        if (rst) c_state <= NORMAL;
        else c_state <= n_state;
    end

    // 2. Next-state combinational logic
    // Navigation priority: RIGHT > LEFT. Other buttons preserve the state.
    always @(*) begin
        n_state = c_state;
        if (!setting_request) begin
            n_state = NORMAL;
        end else begin
            case (c_state)
                NORMAL: begin
                    if (sw_display_mode) n_state = SET_min;
                    else n_state = SET_msec;
                end
                SET_msec: begin
                    if (btn_right) n_state = SET_hour;
                    else if (btn_left) n_state = SET_sec;
                end
                SET_sec: begin
                    if (btn_right) n_state = SET_msec;
                    else if (btn_left) n_state = SET_min;
                end
                SET_min: begin
                    if (btn_right) n_state = SET_sec;
                    else if (btn_left) n_state = SET_hour;
                end
                SET_hour: begin
                    if (btn_right) n_state = SET_min;
                    else if (btn_left) n_state = SET_msec;
                end
                default: n_state = NORMAL;
            endcase
        end
    end

    // 3. Outputs
    always @(*) begin
        case (c_state)
            SET_msec: digit_sel = 2'd0;
            SET_sec:  digit_sel = 2'd1;
            SET_min:  digit_sel = 2'd2;
            SET_hour: digit_sel = 2'd3;
            default:  digit_sel = 2'd0;
        endcase
    end

    assign edit_enable = setting_request && (c_state != NORMAL);
    assign count_enable = ~setting_request;   // Proposed: pause the watch while editing.
    assign blink_enable = edit_enable;    // Actual blink phase is generated elsewhere.

    assign fnd_display_mode = edit_enable ?
    ((c_state == SET_hour) || (c_state == SET_min))
    : sw_display_mode;

    // Edit command priority: RIGHT > LEFT > UP > DOWN.
    // These outputs are 1-clock pulses if button inputs are 1-clock pulses.
    assign inc_pulse = edit_enable && btn_up && !btn_right && !btn_left;
    assign dec_pulse = edit_enable && btn_down
                       && !btn_right && !btn_left && !btn_up;

endmodule

```

---

## `sim_1/new/tb_sr04_top.v`

```verilog
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

```

