`timescale 1ns / 1ps

module watch_adder_datapath #(
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
    wire [MSEC_BIT_WIDTH -1:0] w_msec;
    wire [SEC_BIT_WIDTH  -1:0] w_sec;
    wire [MIN_BIT_WIDTH  -1:0] w_min;
    wire [HOUR_BIT_WIDTH -1:0] w_hour;

    watch_counter_adder #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk    (clk),
        .rst    (rst),
        .i_tick (w_tick_hour),
        .c_count(w_hour),
        .n_count(hour),
        .o_tick ()
    );
    count_reg #(
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_COUNTER_REG_HOUR (
        .c_count  (hour),
        .rst_count(rst_hour),
        .setting  (setting),
        .n_count  (w_hour)
    );
    watch_counter_adder #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk    (clk),
        .rst    (rst),
        .i_tick (w_tick_min),
        .c_count(w_min),
        .n_count(min),
        .o_tick (w_tick_hour)
    );
    count_reg #(
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_COUNTER_REG_MIN (
        .c_count  (min),
        .rst_count(rst_min),
        .setting  (setting),
        .n_count  (w_min)
    );
    watch_counter_adder #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk    (clk),
        .rst    (rst),
        .i_tick (w_tick_sec),
        .c_count(w_sec),
        .n_count(sec),
        .o_tick (w_tick_min)
    );
    count_reg #(
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_COUNTER_REG_SEC (
        .c_count  (sec),
        .rst_count(rst_sec),
        .setting  (setting),
        .n_count  (w_sec)
    );
    watch_counter_adder #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk    (clk),
        .rst    (rst),
        .i_tick (w_tick_10ms),
        .c_count(w_msec),
        .n_count(msec),
        .o_tick (w_tick_sec)
    );
    count_reg #(
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_COUNTER_REG_MSEC (
        .c_count  (msec),
        .rst_count(rst_msec),
        .setting  (setting),
        .n_count  (w_msec)
    );


    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk    (clk),
        .rst    (rst),
        .setting(setting),
        .o_tick (w_tick_10ms)  // 100hz tick
    );
endmodule

module count_reg #(
    BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] c_count,
    input [BIT_WIDTH-1:0] rst_count,
    input setting,
    output reg [BIT_WIDTH-1:0] n_count
);

    always @(*) begin
        if (setting) n_count = rst_count;
        else n_count = c_count;
    end

endmodule

module watch_counter_adder #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input clk,
    input rst,
    input i_tick,
    input [BIT_WIDTH-1:0] c_count,
    output [BIT_WIDTH-1:0] n_count,
    output reg o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;

    assign n_count = counter_reg;



    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            o_tick <= 1'b0;
            //up count
            if (i_tick) begin
                counter_reg <= c_count + 1;
                if (counter_reg == TIMES - 1) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end
            end else begin // 틱이 아니라 clk에 마춰서 초기화가 될 수 있도록 if(i_tick) 밖으로 꺼냄
                o_tick <= 1'b0;
            end

        end
    end
endmodule
