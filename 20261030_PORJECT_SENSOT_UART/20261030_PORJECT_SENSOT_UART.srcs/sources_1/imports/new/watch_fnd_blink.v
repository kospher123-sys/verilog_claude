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
