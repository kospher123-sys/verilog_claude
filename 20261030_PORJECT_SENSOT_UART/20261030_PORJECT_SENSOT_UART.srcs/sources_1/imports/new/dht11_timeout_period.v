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

