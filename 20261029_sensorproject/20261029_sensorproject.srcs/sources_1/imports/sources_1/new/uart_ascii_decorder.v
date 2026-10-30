`timescale 1ns / 1ps

module ascii_decorder (
    input clk,
    input rst,
    input enable,
    input [7:0] ascii,
    output reg pop,
    output reg run_stop,
    output reg clear,
    output reg mode,
    output reg status,
    output reg mode1,
    output reg mode2,
    output reg mode3,
    output reg mode4
);
    // 상태 파라미터에 알파벳을 추가하고, 상태 변수 비트 크기 맞추고, 조합회로 초기화 하고, n_state 처리하고, 값출력 넣고
    localparam IDLE = 4'b0000, 
                   r = 4'b0001,
                   l = 4'b0010,
                   u = 4'b0011,
                   d = 4'b0100,
                 one = 4'b0101,
                 two = 4'b0110,
                tree = 4'b0111,
                four = 4'b1000;

    reg [3:0] c_btn_state, n_btn_state;
    reg [3:0] c_sw_state, n_sw_state;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_btn_state <= IDLE;
            c_sw_state  <= IDLE;
        end else begin
            c_btn_state <= n_btn_state;
            c_sw_state  <= n_sw_state;
        end
    end

    always @(*) begin
        n_btn_state = IDLE;
        n_sw_state = c_sw_state;
        pop = 1'b0;
        run_stop = 1'b0;
        clear = 1'b0;
        mode = 1'b0;
        status = 1'b0;
        mode1 = 1'b0;
        mode2 = 1'b0;
        mode3 = 1'b0;
        mode4 = 1'b0;

        if (enable) begin
            pop = 1'b1;
            case (ascii)
                8'h52, 8'h72: n_btn_state = r;
                8'h4c, 8'h6c: n_btn_state = l;
                8'h55, 8'h75: n_btn_state = u;
                8'h44, 8'h64: n_btn_state = d;
                8'h31: n_sw_state = one;
                8'h32: n_sw_state = two;
                8'h33: n_sw_state = tree;
                8'h34: n_sw_state = four;
            endcase
        end

        case (c_btn_state)
            r: run_stop = 1'b1;
            l: clear   = 1'b1;
            u: mode = 1'b1;
            d: status  = 1'b1;
        endcase

        case(n_sw_state)
            one:  mode1 = 1'b1;
            two:  mode2 = 1'b1;
            tree: mode3 = 1'b1;
            four: mode4 = 1'b1;
        endcase
    end

endmodule
