
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
