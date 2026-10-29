`timescale 1ns / 1ps

module stopwatch (
    input        clk,
    input        rst,
    input        btnR,
    input        btnL,
    input        btnU,
    input        btnD,
    output       led,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [4:0] hour
);

    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;

    wire w_btn_run_stop, w_btn_clear, w_btn_mode;
    wire w_run_stop, w_clear, w_mode;
    wire w_btnR_STW, w_btnL_STW, w_btnU_STW;

    wire [MSEC_BIT_WIDTH-1:0] w_msec;
    wire [ SEC_BIT_WIDTH-1:0] w_sec;
    wire [ MIN_BIT_WIDTH-1:0] w_min;
    wire [HOUR_BIT_WIDTH-1:0] w_hour;


    controll_unit_btn U_STOPWATCH_CONTROLL_UNIT (
        .clk     (clk),
        .reset   (rst),
        .btnR    (btnR),
        .btnL    (btnL),
        .btnU    (btnU),
        .run_stop(w_run_stop),
        .clear   (w_clear),
        .mode    (w_mode)
    );


    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk     (clk),
        .rst     (rst),
        .run_stop(w_run_stop),
        .clear   (w_clear),
        .mode    (w_mode),
        .led     (led),
        .btnD    (btnD),
        .msec    (msec),
        .sec     (sec),
        .min     (min),
        .hour    (hour)
    );


endmodule

module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input run_stop,
    input clear,
    input mode,
    input btnD,
    output led,
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

    lap_block U_LAP_BLOCK (
        .clk(clk),
        .rst(rst),
        .i_msec(w_msec),
        .i_sec(w_sec),
        .i_min(w_min),
        .i_hour(w_hour),
        .btnD(btnD),
        .led(led),
        .o_msec(msec),
        .o_sec(sec),
        .o_min(min),
        .o_hour(hour)
    );

    tick_counter_stopwatch #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_HOUR_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_hour),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_hour),
        .o_tick    ()
    );
    tick_counter_stopwatch #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)
    ) U_MIN_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_min),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_min),
        .o_tick    (w_tick_hour)
    );
    tick_counter_stopwatch #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_sec),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_sec),
        .o_tick    (w_tick_min)
    );
    tick_counter_stopwatch #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)
    ) U_MSEC_COUNTER (
        .clk       (clk),
        .rst       (rst),
        .i_tick    (w_tick_10ms),
        .clear     (clear),
        .mode      (mode),
        .time_count(w_msec),
        .o_tick    (w_tick_sec)
    );
    tick_gen_100hz_stw U_TICK_GEN_100HZ (
        .clk     (clk),
        .rst     (rst),
        .run_stop(run_stop),
        .clear   (clear),
        .o_tick  (w_tick_10ms)  // 100hz tick
    );
endmodule

module lap_block #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input                            clk,
    input                            rst,
    input      [MSEC_BIT_WIDTH -1:0] i_msec,
    input      [SEC_BIT_WIDTH  -1:0] i_sec,
    input      [MIN_BIT_WIDTH  -1:0] i_min,
    input      [HOUR_BIT_WIDTH -1:0] i_hour,
    input                            btnD,
    output reg                       led,
    output reg [MSEC_BIT_WIDTH -1:0] o_msec,
    output reg [SEC_BIT_WIDTH  -1:0] o_sec,
    output reg [MIN_BIT_WIDTH  -1:0] o_min,
    output reg [HOUR_BIT_WIDTH -1:0] o_hour
);

    reg [MSEC_BIT_WIDTH -1:0] lap_msec;
    reg [SEC_BIT_WIDTH  -1:0] lap_sec;
    reg [MIN_BIT_WIDTH  -1:0] lap_min;
    reg [HOUR_BIT_WIDTH -1:0] lap_hour;

    parameter LIVE = 1'b0, LAP = 1'b1;
    reg c_state, n_state;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state  <= LIVE;
            lap_sec  <= 0;
            lap_min  <= 0;
            lap_hour <= 0;
            lap_msec <= 0;
        end else if (c_state == LIVE && btnD) begin
            lap_msec <= i_msec;
            lap_sec  <= i_sec;
            lap_min  <= i_min;
            lap_hour <= i_hour;
            c_state  <= n_state;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        n_state = c_state;
        case (c_state)
            LIVE: begin
                if (btnD) begin
                    n_state = LAP;
                end
            end
            LAP: begin
                if (btnD) n_state = LIVE;
            end

        endcase
    end

    always @(*) begin
        if (c_state == LAP) begin
            o_msec = lap_msec;
            o_sec = lap_sec;
            o_min = lap_min;
            o_hour = lap_hour;
            led = 1;
        end else begin
            o_msec = i_msec;
            o_sec = i_sec;
            o_min = i_min;
            o_hour = i_hour;
            led = 0;
        end
    end
endmodule

module tick_counter_stopwatch #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input clk,
    input rst,
    input i_tick,
    input clear,
    input mode,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;
    assign time_count = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            o_tick <= 1'b0;
            if (mode) begin
                //down count
                if (i_tick) begin
                    counter_reg <= counter_reg - 1;
                    if (counter_reg == 0) begin
                        counter_reg <= TIMES - 1;
                        o_tick      <= 1'b1;
                    end
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                //up count
                if (i_tick) begin
                    counter_reg <= counter_reg + 1;
                    if (counter_reg == TIMES - 1) begin
                        counter_reg <= 0;
                        o_tick      <= 1'b1;
                    end
                end else begin // 틱이 아니라 clk에 마춰서 초기화가 될 수 있도록 if(i_tick) 밖으로 꺼냄
                    o_tick <= 1'b0;
                end
            end
        end
    end
endmodule

module tick_gen_100hz_stw (
    input      clk,
    input      rst,
    input      run_stop,
    input      clear,
    output reg o_tick     //100 hz tick
);

    //  100M hz  ->  100 hz

    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] counter_reg;


    always @(posedge clk or posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick      <= 1'b0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNT - 1)) begin
                    counter_reg <= 0;
                    o_tick      <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                // run_stop이 0으로 바뀌면 o_tick을 0으로 내림.
                o_tick <= 1'b0;
            end
        end
    end

endmodule
