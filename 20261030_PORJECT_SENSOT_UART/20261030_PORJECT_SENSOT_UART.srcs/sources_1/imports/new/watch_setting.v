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
