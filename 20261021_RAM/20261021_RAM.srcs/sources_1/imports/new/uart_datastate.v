`timescale 1ns / 1ps

module uart_datastate (
    input  clk,
    input  rst,
    input  btnR,
    output led,   //tx_busy
    output tx

);

    wire w_b_tick, w_b_16tick;
    wire w_tx_start;

    btn_debounce U_BD_TX_START (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_tx_start)
    );

    uart_tx_datastate U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(w_tx_start),
        .tx_data(8'h30),
        .b_tick(w_b_tick),
        .tx(tx),
        .tx_busy(led)
    );


    baud_tick_gen_datastate U_BAUD_TICK_GEN (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule


module uart_tx_datastate (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx,
    output       tx_busy
);

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;

    reg [1:0] c_state, n_state;
    reg [2:0] bit_count_reg, bit_count_next;
    reg [7:0] data_reg, data_next;
    reg tx_reg, tx_next;   // 조합회로로 출력이 가능하지만 순차회로로 설계
    reg tx_busy_reg, tx_busy_next;
    reg [$clog2(16)-1:0] b_tick_cnt, b_tick_cnt_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state       <= IDLE;
            data_reg      <= 8'h0;
            bit_count_reg <= 3'b0;
            tx_reg        <= 1'b1;
            tx_busy_reg   <= 1'b0;
            b_tick_cnt    <= 0;
        end else begin
            c_state       <= n_state;
            data_reg      <= data_next;
            bit_count_reg <= bit_count_next;
            tx_reg        <= tx_next;
            tx_busy_reg   <= tx_busy_next;
            b_tick_cnt    <= b_tick_cnt_next;
        end
    end

    always @(*) begin
        n_state         = c_state;
        bit_count_next  = bit_count_reg;
        data_next       = data_reg;
        tx_next         = tx_reg;
        tx_busy_next    = tx_busy_reg;
        b_tick_cnt_next = b_tick_cnt;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 0;
                tx_next = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    b_tick_cnt_next = 0;
                    data_next = tx_data;
                    n_state   = START;
                end
            end
            START: begin
                tx_next = 1'b0;
                tx_busy_next = 1'b1; // 이출력을 위에 if 문안에 넣어서 한차례빠르게 출력가능
                if (b_tick == 1) begin
                    if (b_tick_cnt == 15) begin
                        bit_count_next = 3'b0;
                        n_state = DATA;
                        b_tick_cnt_next = 0;
                    end else b_tick_cnt_next = b_tick_cnt + 1;
                end
            end
            DATA: begin
                tx_next = data_reg[0];  //인덱스에 0 대신 bit_count_reg도 가능 ( 밑에 시프트 레지스터 지우고 )
                if (b_tick == 1) begin
                    if (b_tick_cnt == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_count_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            data_next = {1'b0, data_reg[7:1]};  // data_next = data_reg >>1;
                            bit_count_next = bit_count_reg + 1;
                        end
                    end else b_tick_cnt_next = b_tick_cnt + 1;
                end
            end
            STOP: begin
                tx_next = 1;
                // bit_count_next = 0;
                if (b_tick == 1) begin
                    if (b_tick_cnt == 15) n_state = IDLE;
                    else b_tick_cnt_next = b_tick_cnt + 1;
                end
            end
        endcase
    end

endmodule



module baud_tick_gen_datastate (
    input clk,
    input rst,
    output reg b_tick
);

    //100Mhz -> 9600hz
    parameter F_COUNT = 100_000_000 / (9600 * 16);
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
