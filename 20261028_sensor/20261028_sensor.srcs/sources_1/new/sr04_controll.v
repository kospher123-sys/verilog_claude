`timescale 1ns / 1ps

module sr04_controll (
    input clk,
    input rst,
    input do_trig,
    input echo,
    output trig,
    output [9:0] centi  //585cm
);
    wire w_b_tick;

    tick_gen_us U_TICK_GEN_US (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );


    echo_cal U_ECHO_CAL (
        .clk(clk),
        .rst(rst),
        .echo(echo),
        .b_tick(w_b_tick),
        .centi(centi)
    );

    trig_controll U_TRIG_CONTROLL (
        .clk(clk),
        .rst(rst),
        .do_trig(do_trig),
        .b_tick(w_b_tick),
        .trig(trig)
    );
endmodule


module trig_controll (
    input clk,
    input rst,
    input do_trig,
    input b_tick,  //us
    output reg trig
);
    localparam FRAME_COUNT = 1000 * 59, MS_COUNT = 11;
    localparam IDLE = 2'b00, DOING = 2'b01, TICK = 2'b10;

    reg [1:0] c_state, n_state;
    reg [$clog2(FRAME_COUNT)-1:0] frame_cnt, frame_cnt_next;  //for 70 count
    reg [$clog2(MS_COUNT)-1:0] ms_count, ms_count_next;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state   <= IDLE;
            frame_cnt <= 0;
            ms_count  <= 0;
        end else begin
            c_state   <= n_state;
            frame_cnt <= frame_cnt_next;
            ms_count  <= ms_count_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        frame_cnt_next = frame_cnt;
        ms_count_next = ms_count;
        trig = 0;
        case (c_state)
            IDLE: begin
                if (do_trig) begin
                    n_state = TICK;
                end
            end
            TICK: begin
                trig = 1;
                if (b_tick) begin
                    if (ms_count == MS_COUNT - 1) begin
                        ms_count_next = 0;
                        n_state = DOING;
                    end else ms_count_next = ms_count + 1;
                end
            end
            DOING: begin
                if (b_tick) begin
                    if (frame_cnt == FRAME_COUNT - 1) begin
                        frame_cnt_next = 0;
                        n_state = IDLE;
                    end else frame_cnt_next = frame_cnt + 1;
                end
            end
        endcase
    end


endmodule


module echo_cal (
    input clk,
    input rst,
    input echo,
    input b_tick,  //일단 이거 때문에 FSM구성으로 설계함
    output [8:0] centi
);

    localparam IDLE = 1'b0, ECHO = 1'b1;
    reg c_state, n_state;
    reg [13:0] b_tick_cnt, b_tick_cnt_next;  //16,384count(us) -> 585.1428cm
    reg [8:0] centi_reg, centi_next;

    assign centi = centi_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            b_tick_cnt <= 0;
            centi_reg <= 0;
        end else begin
            c_state <= n_state;
            b_tick_cnt <= b_tick_cnt_next;
            centi_reg <= centi_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_cnt_next = b_tick_cnt;
        centi_next = centi_reg;
        case (c_state)
            IDLE: begin
                if (echo) begin
                    n_state = ECHO;
                    centi_next = 0;
                end
            end

            ECHO: begin
                if (b_tick) begin
                    b_tick_cnt_next = b_tick_cnt + 1;
                    if (!echo) begin
                        centi_next = b_tick_cnt_next / 58;
                        b_tick_cnt_next = 0;
                        n_state = IDLE;
                    end
                end
            end
        endcase
    end

endmodule


// 100_000_000hz -> 1_000_000hz = 1us
module tick_gen_us (
    input clk,
    input rst,
    input enable,
    output reg b_tick
);
    parameter F_COUNT = 100;
    reg [$clog2(F_COUNT)-1:0] count_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            count_reg <= 0;
            b_tick <= 0;
        end else begin
            if (enable) begin
                if (count_reg == F_COUNT - 1) begin
                    count_reg <= 0;
                    b_tick <= 1;
                end else begin
                    count_reg <= count_reg + 1;
                    b_tick <= 0;
                end
            end
        end
    end

endmodule
