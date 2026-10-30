`timescale 1ns / 1ps


module top_dht11_MASTER (
    input        clk,
    input        rst,
    input        btnR,
    output [3:0] fnd_com,
    output [7:0] fnd_font,
    inout        dh11_io
);



    dht11_controller_MASTER U_DHT11_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .dht11_start(btnR),
        .us_tick(),
        .valid(),
        .humidity(),
        .temperature(),
        .dh11_io(dh11_io)
    );


endmodule


module dht11_controller_MASTER (
    input         clk,
    input         rst,
    input         dht11_start,
    input         us_tick,
    output        valid,
    output [15:0] humidity,
    output [15:0] temperature,
    inout         dh11_io
);

    localparam IDLE = 0,
              START = 1,
               WAIT = 2,
              SYNCL = 3,
              SYNCH = 4,
          DATA_SYNC = 5,
           DATA_BIT = 6,
       BIT_DECISION = 7,
          CHECK_SUM = 8,
               STOP = 9;
    reg [3:0] c_start, n_state;
    reg dht11_io_control_reg, dht11_io_control_next;
    reg dht11_io_reg, dht11_io_next;
    reg [$clog2(19_000)-1 : 0] tick_cnt_reg, tick_cnt_next;
    reg valid_reg, valid_next;
    reg [$clog2(40)-1:0] data_cnt, data_cnt_next;

    assign valid = valid_reg;
    assign dht11_io = (dht11_io_control_reg) ? dht11_io_reg : 1'bz;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_start <= IDLE;
            dht11_io_control_reg <= 1'b1;
            dht11_io_reg <= 1'b1;
            tick_cnt_reg    <=0;
            valid_reg <=1;
        end else begin
            c_start <= n_state;
            dht11_io_control_reg <= dht11_io_control_next;
            dht11_io_reg <= dht11_io_next;
            tick_cnt_reg <= tick_cnt_next;
            valid_reg <= valid_next;
        end
    end

    always @(*) begin
        n_state = c_start;
        dht11_io_control_next = dht11_io_control_reg;
        dht11_io_next = dht11_io_reg;
        tick_cnt_next = tick_cnt_reg;
        valid_next = valid_reg;
        case (c_start)
            IDLE: begin
                dht11_io_next = 1'b1;
                dht11_io_control_next = 1'b1;
                if (dht11_start) begin
                    tick_cnt_next = 0;
                    n_state = START;
                end
            end
            START: begin
                dht11_io_next = 1'b0;
                dht11_io_control_next = 1'b1;
                if (us_tick) begin
                    if (tick_cnt_reg == 19_000) begin
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin
                dht11_io_next = 1'b1;
                if (us_tick) begin
                    if (tick_cnt_reg == 30 - 1) begin
                        // change output to high impedence
                        dht11_io_control_next = 1'b0;
                        tick_cnt_next = 0;
                        n_state = SYNCL;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            SYNCL: begin //wait에서 sync로 넘어갈때가 중요 예외 처리 필수
                if (us_tick) begin
                    if (tick_cnt_reg >= 90) begin
                        // change output to high impedence
                        dht11_io_control_next = 1'b1;
                        tick_cnt_next = 0;
                        n_state = IDLE;
                        valid_next = 0;
                    end else if (dht11_io && tick_cnt_reg >= 20-1) begin
                        n_state = SYNCH;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            SYNCH: begin        //싱크로 넘어가는 구간은 출력 단자가 바뀌는 구간이기도 해서 메타스테리블이 빈번해 값을 읽지 안도록 그냥 시간을 보내야함
                if (us_tick) begin
                    if (tick_cnt_reg >= 90) begin
                        dht11_io_control_next = 1'b1;
                        tick_cnt_next = 0;
                        n_state = IDLE;
                        valid_next = 0;
                    end else if (!dht11_io && tick_cnt_reg >= 20-1) begin
                        n_state = DATA_SYNC;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            DATA_SYNC: begin
                if (us_tick) begin
                    if (dht11_io) begin
                        // change output to high impedence
                        dht11_io_control_next = 1'b0;
                        tick_cnt_next = 0;
                        n_state = DATA_BIT;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            DATA_BIT: begin

            end
            BIT_DECISION: begin

            end
            CHECK_SUM: begin

            end
            STOP: begin
                if (us_tick) begin
                    if (tick_cnt_reg == 60 - 1) begin
                        dht11_io_control_next = 1'b1;
                        tick_cnt_next = 0;
                        n_state = IDLE;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end

        endcase
    end


endmodule
