`timescale 1ns / 1ps


module watch (
    input        clk,
    input        rst,
    input        btnR,
    input        btnL,
    input        btnU,
    input        btnD,
    input        sw_setting_mode,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour,
    output [1:0] setting_state
);
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;

    wire [MSEC_BIT_WIDTH -1:0] w_rst_msec;
    wire [SEC_BIT_WIDTH  -1:0] w_rst_sec;
    wire [MIN_BIT_WIDTH  -1:0] w_rst_min;
    wire [HOUR_BIT_WIDTH -1:0] w_rst_hour;


    setting_time U_SETTING_TIME (
        .clk     (clk),
        .rst     (rst),
        .setting (sw_setting_mode),
        .msec    (msec),
        .sec     (sec),
        .min     (min),
        .hour    (hour),
        .btnR    (btnR),
        .btnL    (btnL),
        .btnU    (btnU),
        .btnD    (btnD),
        .rst_msec(w_rst_msec),
        .rst_sec (w_rst_sec),
        .rst_min (w_rst_min),
        .rst_hour(w_rst_hour),
        .setting_state(setting_state)
    );


    watch_datapath U_WATCH_DATAPATH (
        .clk     (clk),
        .rst     (rst),
        .setting (sw_setting_mode),
        .rst_msec(w_rst_msec),
        .rst_sec (w_rst_sec),
        .rst_min (w_rst_min),
        .rst_hour(w_rst_hour),

        .msec(msec),
        .sec (sec),
        .min (min),
        .hour(hour)
    );



endmodule


module watch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input setting,
    input [MSEC_BIT_WIDTH -1:0] rst_msec,
    input [SEC_BIT_WIDTH  -1:0] rst_sec,
    input [MIN_BIT_WIDTH  -1:0] rst_min,
    input [HOUR_BIT_WIDTH -1:0] rst_hour,
    output [MSEC_BIT_WIDTH -1:0] msec,
    output [SEC_BIT_WIDTH  -1:0] sec,
    output [MIN_BIT_WIDTH  -1:0] min,
    output [HOUR_BIT_WIDTH -1:0] hour
);
    wire w_tick_10ms, w_tick_sec, w_tick_min, w_tick_hour;

    tick_counter_watch #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_hour),
        .setting   (setting),
        .rst_count (rst_hour),
        .time_count(hour),
        .o_tick    ()
    );

    tick_counter_watch #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_min),
        .setting   (setting),
        .rst_count (rst_min),
        .time_count(min),
        .o_tick    (w_tick_hour)
    );

    tick_counter_watch #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_sec),
        .setting   (setting),
        .rst_count (rst_sec),
        .time_count(sec),
        .o_tick    (w_tick_min)
    );

    tick_counter_watch #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_10ms),
        .setting   (setting),
        .rst_count (rst_msec),
        .time_count(msec),
        .o_tick    (w_tick_sec)
    );

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk    (clk),
        .rst    (rst),
        .setting(setting),
        .o_tick (w_tick_10ms)  // 100hz tick
    );
endmodule

module setting_time #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                            clk,
    input                            rst,
    input                            setting,
    input      [MSEC_BIT_WIDTH -1:0] msec,
    input      [SEC_BIT_WIDTH  -1:0] sec,
    input      [MIN_BIT_WIDTH  -1:0] min,
    input      [HOUR_BIT_WIDTH -1:0] hour,
    input                            btnR,
    input                            btnL,
    input                            btnU,
    input                            btnD,
    output reg [MSEC_BIT_WIDTH -1:0] rst_msec,
    output reg [SEC_BIT_WIDTH  -1:0] rst_sec,
    output reg [MIN_BIT_WIDTH  -1:0] rst_min,
    output reg [HOUR_BIT_WIDTH -1:0] rst_hour,
    output [1:0] setting_state
);
    parameter _1 = 2'b00, _10 = 2'b01, _100 = 2'b10, _1000 = 2'b11;
    reg [1:0] c_state, n_state;
    assign setting_state = c_state;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= _1;
        end else c_state <= n_state;
    end

    always @(*) begin
        if (setting) begin
            case (c_state)
                _1: begin
                    if (btnR) n_state = _1000;
                    else if (btnL) n_state = _10;
                    else n_state = c_state;
                end
                _10: begin
                    if (btnR) n_state = _1;
                    else if (btnL) n_state = _100;
                    else n_state = c_state;
                end
                _100: begin
                    if (btnR) n_state = _10;
                    else if (btnL) n_state = _1000;
                    else n_state = c_state;
                end
                _1000: begin
                    if (btnR) n_state = _100;
                    else if (btnL) n_state = _1;
                    else n_state = c_state;
                end
                default: n_state = _1;
            endcase
        end else n_state = c_state;

    end


    always @(*) begin
        rst_msec = msec;
        rst_sec  = sec;
        rst_min  = min;
        rst_hour = hour;
        if (setting) begin

            case (c_state)
                _1: begin
                    if (btnU) rst_msec = msec + 1;
                    else if (btnD && msec == 0) rst_msec = 99;
                    else if (btnD) rst_msec = msec - 1;
                end
                _10: begin
                    if (btnU) rst_sec = sec + 1;
                    else if (btnD && sec == 0) rst_sec = 59;
                    else if (btnD) rst_sec = sec - 1;
                end
                _100: begin
                    if (btnU) rst_min = min + 1;
                    else if (btnD && min == 0) rst_min = 59;
                    else if (btnD) rst_min = min - 1;
                end
                _1000: begin
                    if (btnU) rst_hour = hour + 1;
                    else if (btnD && hour == 0) rst_hour = 23;
                    else if (btnD) rst_hour = hour - 1;
                end
            endcase
        end

    end

endmodule

module tick_counter_watch #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input clk,
    input rst,
    input i_tick,
    input setting,
    input [$clog2(TIMES)-1:0] rst_count,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;

    assign time_count = counter_reg;



    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            o_tick <= 1'b0;
            if (setting) begin
                if (rst_count <= TIMES - 1) counter_reg <= rst_count;
                else counter_reg <= 0;
            end else begin
                //up count
                if (i_tick) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg >= TIMES - 1) begin
                        counter_reg <= 0;
                        o_tick      <= 1'b1;
                    end
                end
            end
        end
    end
endmodule

module tick_gen_100hz (
    input      clk,
    input      rst,
    input      setting,
    output reg o_tick    //100 hz tick
);

    //  100M hz  ->  100 hz

    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] counter_reg;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
            if (!setting) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNT - 1)) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                o_tick <= 1'b0;
                counter_reg <= 0;
            end
        end
    end

endmodule

