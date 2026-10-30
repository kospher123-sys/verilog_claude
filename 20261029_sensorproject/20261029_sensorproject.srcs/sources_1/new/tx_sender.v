`timescale 1ns / 1ps

// 0.5초마다 FND 8자리를 ASCII로 UART 전송
// 전송 형식: [hour10 hour1 min10 min1] ' ' [sec10 sec1 msec10 msec1] '\r' '\n'  (11바이트)
//   예) 시계 "1234 5678", 거리 "d123 d123", 습온도 "t025 H045"
module tx_sender #(
    parameter PERIOD = 50_000_000  // 100MHz 기준 0.5s
) (
    input       clk,
    input       rst,
    // input       start,      // 1이면 주기 전송 동작
    input       baud_tick,
    input [3:0] w_msec_ds1,
    input [3:0] w_msec_ds10,
    input [3:0] w_sec_ds1,
    input [3:0] w_sec_ds10,
    input [3:0] w_min_ds1,
    input [3:0] w_min_ds10,
    input [3:0] w_hour_ds1,
    input [3:0] w_hour_ds10,
    output      tx
);

    localparam IDLE = 2'd0, SEND = 2'd1, WAIT = 2'd2;
    localparam LAST_BYTE = 10;  // 0~10 : 11바이트

    reg [1:0] c_state, n_state;
    reg [3:0] byte_cnt, byte_cnt_next;
    reg [31:0] snap_reg, snap_next;  // 전송 시작 시점의 8자리 저장
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_busy;

    // 0.5초 주기 펄스
    reg [$clog2(PERIOD)-1:0] period_cnt;
    reg period_tick;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            period_cnt  <= 0;
            period_tick <= 1'b0;
        end else begin
            period_tick <= 1'b0;
            if (period_cnt == PERIOD - 1) begin
                period_cnt  <= 0;
                period_tick <= 1'b1;
            end else period_cnt <= period_cnt + 1;
        end
    end

    // 4비트 자리값 -> ASCII (BCD 폰트와 같은 매핑)
    function [7:0] to_ascii(input [3:0] digit);
        case (digit)
            4'hA:    to_ascii = "A";
            4'hB:    to_ascii = "H";
            4'hC:    to_ascii = "t";
            4'hD:    to_ascii = "d";
            4'hE:    to_ascii = ".";
            4'hF:    to_ascii = " ";
            default: to_ascii = 8'h30 + digit;  // '0'~'9'
        endcase
    endfunction

    always @(*) begin
        case (byte_cnt)
            4'd0:    tx_data = to_ascii(snap_reg[31:28]);  // hour10
            4'd1:    tx_data = to_ascii(snap_reg[27:24]);  // hour1
            4'd2:    tx_data = to_ascii(snap_reg[23:20]);  // min10
            4'd3:    tx_data = to_ascii(snap_reg[19:16]);  // min1
            4'd4:    tx_data = " ";
            4'd5:    tx_data = to_ascii(snap_reg[15:12]);  // sec10
            4'd6:    tx_data = to_ascii(snap_reg[11:8]);   // sec1
            4'd7:    tx_data = to_ascii(snap_reg[7:4]);    // msec10
            4'd8:    tx_data = to_ascii(snap_reg[3:0]);    // msec1
            4'd9:    tx_data = 8'h0D;  // \r
            default: tx_data = 8'h0A;  // \n
        endcase
    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state  <= IDLE;
            byte_cnt <= 0;
            snap_reg <= 0;
        end else begin
            c_state  <= n_state;
            byte_cnt <= byte_cnt_next;
            snap_reg <= snap_next;
        end
    end

    always @(*) begin
        n_state       = c_state;
        byte_cnt_next = byte_cnt;
        snap_next     = snap_reg;
        tx_start      = 1'b0;
        case (c_state)
            IDLE: begin
                if (period_tick) begin
                    snap_next = {
                        w_hour_ds10, w_hour_ds1, w_min_ds10, w_min_ds1,
                        w_sec_ds10, w_sec_ds1, w_msec_ds10, w_msec_ds1
                    };
                    byte_cnt_next = 0;
                    n_state = SEND;
                end
            end
            SEND: begin  // uart_tx가 비어 있으면 1클럭 start
                if (!tx_busy) begin
                    tx_start = 1'b1;
                    n_state  = WAIT;
                end
            end
            WAIT: begin  // start 다음 클럭부터 busy=1, 전송 끝나면 0
                if (!tx_busy) begin
                    if (byte_cnt == LAST_BYTE) n_state = IDLE;
                    else begin
                        byte_cnt_next = byte_cnt + 1;
                        n_state = SEND;
                    end
                end
            end
        endcase
    end

    uart_tx_datastate U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .b_tick  (baud_tick),
        .tx      (tx),
        .tx_busy (tx_busy)
    );

endmodule
