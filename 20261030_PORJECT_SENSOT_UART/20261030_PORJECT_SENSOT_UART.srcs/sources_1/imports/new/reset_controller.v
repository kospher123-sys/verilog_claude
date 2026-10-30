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
