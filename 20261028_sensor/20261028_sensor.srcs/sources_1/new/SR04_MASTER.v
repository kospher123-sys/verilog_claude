`timescale 1ns / 1ps

module SR04_MASTER (
    input clk,
    input rst,
    input sr04_start,
    input echo,
    output trig,
    // output [8:0] distance,  //585cm
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    wire w_enable, w_b_tick, w_echo, w_start;
    wire [8:0] w_distance;

    btn_debounce U_NTB_DEBOUNCER (
        .clk  (clk),
        .reset(rst),
        .i_btn(sr04_start),
        .o_btn(w_start)
    );

    controll_unit_sr04 U_CONTROLL_UNIT (
        .clk(clk),
        .rst(rst),
        .start(w_start),
        .echo(echo),
        .b_tick(w_b_tick),
        .enable(w_enable),
        .trig(trig),
        .distance(w_distance)
    );

    tick_gen_us U_TICK_GEN_US (
        .clk(clk),
        .rst(rst),
        .enable(w_enable),
        .b_tick(w_b_tick)
    );

    fnd_controller U_FND_CONTROLLER (
        .clk     (clk),
        .reset   (rst),
        .fnd_data({5'b00000, w_distance}),
        .fnd_com (fnd_com),
        .fnd_font(fnd_font)
    );

endmodule

module echo_debouncer (
    input  clk,
    input  rst,
    input  i_echo,
    input  b_tick,
    output o_echo
);
    reg [7:0] register;
    assign o_echo = &register;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else begin
            if (b_tick) begin
                register <= {i_echo, register[7:1]};
            end
        end

    end

endmodule

module controll_unit_sr04 (
    input clk,
    input rst,
    input start,
    input echo,
    input b_tick,
    output reg enable,
    output trig,
    output [8:0] distance  //585cm
);

    localparam IDLE =3'b000, START =3'b001, WAIT =3'b010, DISTANCE =3'b011, STOP =3'b100;
    localparam FRAME_COUNT = 1000 * 59, MS_COUNT = 11;

    reg [2:0] c_state, n_state;
    reg [$clog2(MS_COUNT)-1:0] ms_count, ms_count_next;
    reg [$clog2(FRAME_COUNT)-1:0] frame_cnt, frame_cnt_next;  //for 70 count
    reg [14:0] b_tick_cnt, b_tick_cnt_next;  //32000 count
    reg [8:0] centi_reg, centi_next;
    reg trig_reg, trig_next;


    ila_0 U_ILA (
        .clk(clk),
        .probe0(trig),
        .probe1(echo),
        .probe2(c_state)
    );



    assign trig = trig_reg;
    assign distance = centi_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            ms_count <= 0;
            b_tick_cnt <= 0;
            centi_reg <= 0;
            frame_cnt <= 0;
            trig_reg <= 0;
        end else begin
            c_state <= n_state;
            ms_count <= ms_count_next;
            b_tick_cnt <= b_tick_cnt_next;
            frame_cnt <= frame_cnt_next;
            centi_reg <= centi_next;
            trig_reg <= trig_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        ms_count_next = ms_count;
        b_tick_cnt_next = b_tick_cnt;
        frame_cnt_next = frame_cnt;
        centi_next = centi_reg;
        trig_next = trig_reg;
        enable = 0;
        case (c_state)
            IDLE: begin
                if (start) begin
                    n_state = START;
                    enable = 1;
                    ms_count_next = 0;
                end
            end
            START: begin
                trig_next = 1;
                enable = 1;
                if (b_tick) begin
                    if (ms_count == MS_COUNT - 1) begin
                        ms_count_next = 0;
                        n_state = WAIT;

                    end else ms_count_next = ms_count + 1;
                end
            end
            WAIT: begin
                enable = 1;
                trig_next = 0;
                if (echo && b_tick) begin
                    n_state = DISTANCE;
                    centi_next = 0;
                    b_tick_cnt_next = 0;
                end
            end
            DISTANCE: begin
                enable = 1;
                if (b_tick) begin
                    b_tick_cnt_next = b_tick_cnt + 1;
                    if (!echo) begin
                        centi_next = b_tick_cnt_next / 58;
                        b_tick_cnt_next = 0;
                        n_state = STOP;
                    end else begin
                        if (b_tick_cnt >= 36_000 - 1) begin
                            centi_next = 400;
                            b_tick_cnt_next = 0;
                            n_state = STOP;
                        end
                    end
                end
            end
            STOP: begin
                enable = 1;
                if (b_tick) begin
                    if (frame_cnt >= 10_000) begin
                        frame_cnt_next = 0;
                        n_state = IDLE;
                    end else frame_cnt_next = frame_cnt + 1;
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
                if (count_reg == F_COUNT - 2) begin
                    count_reg <= 0;
                    b_tick <= 1;
                end else begin
                    count_reg <= count_reg + 1;
                    b_tick <= 0;
                end
            end else begin
                b_tick <= 0;
                count_reg <= 0;
            end
        end
    end

endmodule
