`timescale 1ns / 1ps

module led_fsm (
    input clk,
    input reset,
    input [1:0] sw,
    output reg [2:0] led
);
    parameter S1 = 3'b000, S2 = 3'b001, S3 = 3'b010, S4 = 3'b011, S5 = 3'b100;
    reg [2:0] current_state, next_state;

    //설계는 state_resistor부터
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= S1;
        end else begin
            current_state <= next_state;
        end

    end

    //next,output cl
    always @(*) begin
        case (current_state)  // 커런트스테이트 경우의 수를모두 처리하지 않아 랙치가 생길 수 있음 -> 랫치가 생겨서 문제가됨 -> case 문 앞에 초기값을 선언하던가 default를 추가하면됨
            S1: begin
                if (sw == 2'b01) next_state = S2;
                else next_state = current_state;
            end
            S2: begin
                if (sw == 2'b10) next_state = S3;
                else next_state = current_state;
            end
            S3: begin
                if (sw == 2'b11) next_state = S4;
                else next_state = current_state;
            end
            S4: begin
                if (sw == 2'b00) next_state = S1;
                else if (sw == 2'b01) next_state = S2;
                else if (sw == 2'b10) next_state = S5;
                else next_state = current_state;
            end
            S5: begin
                if (sw == 2'b00) next_state = S1;
                else next_state = current_state;
            end
            default : begin 
                next_state = current_state;
            end
        endcase
    end


    always @(*) begin
        case (current_state)
            S1: led = 3'b000;
            S2: led = 3'b001;
            S3: led = 3'b010;
            S4: led = 3'b100;
            S5: led = 3'b111;
            default : led = 3'b101;
    endcase
    end


endmodule
