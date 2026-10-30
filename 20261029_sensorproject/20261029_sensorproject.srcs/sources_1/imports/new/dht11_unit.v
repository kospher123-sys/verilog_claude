`timescale 1ns / 1ps
//타이밍을 위에 bit_desison상태가 필요함 ? , 싱크로 나이저 필요함

module dht11_controller (
    input             clk,
    input             rst,
    input             dht11_start,
    input             us_tick,
    output            valid,
    output     [15:0] humidity,
    output     [15:0] temperature,
    output reg        enable,
    inout             dht11_io      // inout port is always be wire type
);

    localparam IDLE = 0, START = 1, WAIT = 2, SYNCL = 3, SYNCH = 4, DATA_SYNC = 5, DATA_BIT = 6,CHECK_SUM=7, STOP=8;
    reg [3:0] c_start, n_state;
    reg dht11_io_control_reg, dht11_io_control_next;
    reg dht11_io_reg, dht11_io_next;
    reg [$clog2(19_000)-1 : 0] tick_cnt_reg, tick_cnt_next;
    reg valid_reg, valid_next;
    reg [$clog2(40)-1:0] data_cnt, data_cnt_next;
    reg [39:0] data_reg, data_next;  //{humidity, temperature}
    wire [7:0] check_sum;
    wire [7:0] check_sum_debug;

    assign check_sum_debug = humidity[7:0] + humidity[15:8] +temperature[7:0] + temperature[15:8];
    assign humidity = data_reg[39:24];
    assign temperature = data_reg[23:8];
    assign check_sum = data_reg[7:0];
    assign valid = valid_reg;
    assign dht11_io = (dht11_io_control_reg) ? dht11_io_reg : 1'bz;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_start <= IDLE;
            dht11_io_control_reg <= 1'b1;
            dht11_io_reg <= 1'b1;
            tick_cnt_reg    <=0;
            valid_reg <=0;
            data_cnt <=0;
            data_reg <=0;
        end else begin
            c_start <= n_state;
            dht11_io_control_reg <= dht11_io_control_next;
            dht11_io_reg <= dht11_io_next;
            tick_cnt_reg <= tick_cnt_next;
            valid_reg <= valid_next;
            data_cnt <= data_cnt_next;
            data_reg <= data_next;
        end
    end

    always @(*) begin
        n_state = c_start;
        dht11_io_control_next = dht11_io_control_reg;
        dht11_io_next = dht11_io_reg;
        tick_cnt_next = tick_cnt_reg;
        valid_next = valid_reg;
        data_cnt_next = data_cnt;
        data_next = data_reg;
        enable = 0;
        case (c_start)
            IDLE: begin  //0
                dht11_io_next = 1'b1;
                dht11_io_control_next = 1'b1;
                if (dht11_start) begin
                    tick_cnt_next = 0;
                    n_state = START;
                    enable = 1;
                end
            end
            START: begin  //1
                dht11_io_next = 1'b0;
                dht11_io_control_next = 1'b1;
                enable = 1;
                if (us_tick) begin
                    if (tick_cnt_reg == 19_000) begin
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin  //2
                dht11_io_next = 1'b1;
                dht11_io_control_next = 1'b1;
                enable = 1;
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
            SYNCL: begin    //3  //wait에서 sync로 넘어갈때가 중요 예외 처리 필수
                dht11_io_control_next = 1'b0;
                enable = 1;
                if (us_tick) begin
                    if (tick_cnt_reg >= 90) begin
                        dht11_io_control_next = 1'b1;
                        tick_cnt_next = 0;
                        n_state = IDLE;
                        valid_next = 0;
                    end else if (dht11_io && tick_cnt_reg >= 30 - 1) begin
                        n_state = SYNCH;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            SYNCH: begin  //4
                dht11_io_control_next = 1'b0;
                enable = 1;
                if (us_tick) begin
                    if (tick_cnt_reg >= 90) begin
                        dht11_io_control_next = 1'b1;
                        tick_cnt_next = 0;
                        n_state = IDLE;
                        valid_next = 0;
                    end else if (!dht11_io && tick_cnt_reg >= 30 - 1) begin
                        n_state = DATA_SYNC;
                        tick_cnt_next = 0;
                        data_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            DATA_SYNC: begin  //5
                dht11_io_control_next = 1'b0;
                enable = 1;
                if (us_tick) begin
                    if (dht11_io) begin
                        n_state = DATA_BIT;
                        tick_cnt_next = 0;
                    end else if (tick_cnt_reg == 60 - 1) begin
                        n_state = DATA_BIT;
                        tick_cnt_next = 0;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            DATA_BIT: begin  //6
                dht11_io_control_next = 1'b0;
                enable = 1;
                if (us_tick) begin
                    if (!dht11_io && tick_cnt_reg >= 40) begin
                        data_next = {data_next[38:0], 1'b1};
                        tick_cnt_next = 0;
                        data_cnt_next = data_cnt + 1;
                        if (data_cnt < 39) begin
                            n_state = DATA_SYNC;
                        end else begin
                            n_state = CHECK_SUM;
                        end
                    end else if (!dht11_io && tick_cnt_reg >= 20) begin
                        data_next = {data_next[38:0], 1'b0};
                        tick_cnt_next = 0;
                        data_cnt_next = data_cnt + 1;
                        if (data_cnt < 39) begin
                            n_state = DATA_SYNC;
                        end else begin
                            n_state = CHECK_SUM;
                            data_cnt_next = 0;
                        end
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            CHECK_SUM: begin
                enable = 1;
                // if (us_tick) begin // 혹시 타이밍 안나오면 해보기
                if(check_sum == humidity[7:0] + humidity[15:8] + temperature[7:0] + temperature[15:8])begin
                    n_state = STOP;
                    valid_next = 1;
                end else begin
                    n_state = IDLE;
                    valid_next = 0;
                end
                // end
            end
            STOP: begin  //7
                enable = 1;
                dht11_io_control_next = 1'b0;
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
