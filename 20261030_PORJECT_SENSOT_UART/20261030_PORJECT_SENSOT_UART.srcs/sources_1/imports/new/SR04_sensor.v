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

    localparam integer PERIOD_CYCLES = MIN_PERIOD_US * CLOCKS_PER_US;

    localparam integer PERIOD_WIDTH = (PERIOD_CYCLES <= 1) ? 1 : $clog2(
        PERIOD_CYCLES
    );

    reg [PERIOD_WIDTH-1:0] period_cnt_reg;
    reg period_ready_reg;

    wire start_accept;

    assign start_accept =(c_state == IDLE) &&start &&!echo_sync &&period_ready_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            period_cnt_reg   <= 0;
            period_ready_reg <= 1'b1;
        end else if (start_accept) begin
            period_cnt_reg   <= 0;
            period_ready_reg <= 1'b0;
        end else if (!period_ready_reg) begin
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
            START: begin
                trigger = 1'b1;
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
            WAIT: begin
                clear = 1'b0;
                enable = 1'b1;

                echo_cm_next = 9'd0;
                echo_rem_next = 6'd0;

                if (us_tick) begin
                    if (echo_sync) begin
                        echo_cm_next = 9'd0;
                        echo_rem_next = 6'd1;
                        us_tick_cnt_next = 1;
                        n_state = DISTANCE;
                    end else if (us_tick_cnt_reg == TIMEOUT_TICKS - 1) begin
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

                if (!echo_sync) begin
                    data_next = echo_cm_reg;
                    us_tick_cnt_next = 0;
                    n_state = STOP;
                end else if (us_tick) begin

                    // Distance Counter
                    if (echo_rem_reg == 6'd57) begin
                        echo_rem_next = 6'd0;
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
