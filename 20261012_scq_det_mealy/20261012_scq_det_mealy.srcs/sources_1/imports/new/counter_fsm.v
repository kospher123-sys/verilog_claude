`timescale 1ns / 1ps


module counter_fsm (
    input clk,
    input reset,
    input [1:0] sw,
    output reg clear,
    output reg run_stop
);


    parameter STOP = 2'b00, CLEAR = 2'b01, RUN = 2'b10;
    reg [1:0] current_state, next_state;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= STOP;
        end else begin
            current_state <= next_state;
        end

    end




    always @(*) begin
        case (current_state)
            STOP: begin
                casex(sw)
                2'bx1 :next_state = RUN;
                2'b10 :next_state = CLEAR;
                default : next_state = current_state;
            endcase
            end
            CLEAR: begin
                casex(sw)
                2'bx1 :next_state = RUN;
                2'b00 :next_state = STOP;
                default : next_state = current_state;
            endcase
            end
            RUN: begin
                casex(sw)
                2'b00 :next_state = STOP;
                2'b10 :next_state = CLEAR;
                default : next_state = current_state;
            endcase
            end
            default: next_state = current_state;
        endcase

    end

    always @(*) begin
        case (current_state)
            STOP: begin
                run_stop = 0;
                clear = 0;
            end
            CLEAR:begin
                run_stop = 0;
                clear = 1;
            end
            RUN: begin
                run_stop = 1;
                clear = 0;
            end

            default: begin
                run_stop = 0;
                clear = 0;
            end
        endcase
    end
endmodule
