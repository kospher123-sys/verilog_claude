
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
