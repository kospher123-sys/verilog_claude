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
