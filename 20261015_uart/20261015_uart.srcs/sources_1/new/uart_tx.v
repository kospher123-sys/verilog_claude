`timescale 1ns / 1ps



module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx,
    output       tx_busy
);

    localparam IDLE = 0, START = 1, BIT0 = 2, BIT1 = 3, BIT2 = 4, BIT3 = 5;
    localparam BIT4 = 6, BIT5 = 7, BIT6 = 8, BIT7 = 9, STOP = 10, WAIT =11;

    reg [3:0] c_state, n_state;
    reg tx_reg, tx_next;   // 조합회로로 출력이 가능하지만 순차회로로 설계
    reg tx_busy_reg, tx_busy_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            tx_reg <= 1'b1;
            tx_busy_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            tx_reg <= tx_next;
            tx_busy_reg <= tx_busy_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        tx_next = tx_reg;
        tx_busy_next = tx_busy_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) n_state = WAIT;
            end
            WAIT: begin
                tx_next = 1'b1;
                tx_busy_next = 1'b1;
                if (b_tick) n_state = START;
            end
            START: begin
                tx_next = 1'b0;
                tx_busy_next = 1'b1; // 이출력을 위에 if 문안에 넣어서 한차례빠르게 출력가능
                if (b_tick) n_state = BIT0;
            end
            BIT0: begin
                tx_next = tx_data[0];
                if (b_tick) n_state = BIT1;
            end
            BIT1: begin
                tx_next = tx_data[1];
                if (b_tick) n_state = BIT2;
            end
            BIT2: begin
                tx_next = tx_data[2];
                if (b_tick) n_state = BIT3;
            end
            BIT3: begin
                tx_next = tx_data[3];
                if (b_tick) n_state = BIT4;
            end
            BIT4: begin
                tx_next = tx_data[4];
                if (b_tick) n_state = BIT5;
            end
            BIT5: begin
                tx_next = tx_data[5];
                if (b_tick) n_state = BIT6;
            end
            BIT6: begin
                tx_next = tx_data[6];
                if (b_tick) n_state = BIT7;
            end
            BIT7: begin
                tx_next = tx_data[7];
                if (b_tick) n_state = STOP;
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) n_state = IDLE;
            end
        endcase
    end

endmodule


module baud_tick_gen (
    input clk,
    input rst,
    output reg b_tick
);

    //100Mhz -> 9600hz
    parameter F_COUNT = 100_000_000 / 9600;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick      <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            b_tick <= 0;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1;
            end
        end
    end

endmodule
