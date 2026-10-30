`timescale 1ns / 1ps


module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0] c_state, n_state;

    reg [2:0] bit_cnt, bit_cnt_next;
    reg rx_done_reg, rx_done_next;
    reg [7:0] data_reg, data_next;
    reg [$clog2(16)-1:0] b_tick_cnt, b_tick_cnt_next;

    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state     <= IDLE;
            bit_cnt     <= 0;
            b_tick_cnt  <= 0;
            rx_done_reg <= 0;
            data_reg    <= 0;
        end else begin
            c_state     <= n_state;
            bit_cnt     <= bit_cnt_next;
            rx_done_reg <= rx_done_next;
            data_reg    <= data_next;
            b_tick_cnt  <= b_tick_cnt_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        bit_cnt_next = bit_cnt;
        rx_done_next = rx_done_reg;
        data_next = data_reg;
        b_tick_cnt_next = b_tick_cnt;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 0;
                rx_done_next = 1'b0;
                if (b_tick == 1 && rx == 0) n_state = START;
            end
            START: begin
                if (b_tick == 1) begin
                    if (b_tick_cnt == 7) begin
                        n_state         = DATA;
                        data_next       = 8'h00;
                        bit_cnt_next    = 0;
                        b_tick_cnt_next = 0;
                    end else b_tick_cnt_next = b_tick_cnt + 1;
                end
            end
            DATA: begin
                if (b_tick == 1) begin
                    if (b_tick_cnt == 15) begin
                        b_tick_cnt_next = 0;
                        data_next = {rx, data_reg[7:1]};
                        if (bit_cnt == 7) n_state = STOP;
                        else begin
                            bit_cnt_next = bit_cnt + 1;
                        end
                    end else b_tick_cnt_next = b_tick_cnt + 1;
                end
            end
            STOP: begin
                if (b_tick == 1) begin
                    if (b_tick_cnt == 15) begin
                        n_state = IDLE;
                        rx_done_next = 1'b1;
                    end else b_tick_cnt_next = b_tick_cnt + 1;
                end
            end
        endcase
    end


endmodule


// module baud_tick_gen_datastate (
//     input clk,
//     input rst,
//     output reg b_tick
// );

//     //100Mhz -> 9600hz
//     parameter F_COUNT = (100_000_000 / 9600 * 16);
//     reg [$clog2(F_COUNT)-1:0] counter_reg;

//     always @(posedge clk, posedge rst) begin
//         if (rst) begin
//             counter_reg <= 0;
//             b_tick      <= 0;
//         end else begin
//             counter_reg <= counter_reg + 1;
//             b_tick <= 0;
//             if (counter_reg == F_COUNT - 1) begin
//                 counter_reg <= 0;
//                 b_tick <= 1;
//             end
//         end
//     end

// endmodule
