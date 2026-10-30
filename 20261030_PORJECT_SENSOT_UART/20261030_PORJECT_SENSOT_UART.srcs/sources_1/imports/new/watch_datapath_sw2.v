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
