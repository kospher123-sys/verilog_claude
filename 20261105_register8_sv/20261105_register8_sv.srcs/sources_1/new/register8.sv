`timescale 1ns / 1ps

module register8 (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] d,
    output logic [7:0] q
);

    //logic타입으로 선언해 굳이 q_reg가 필요없음

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            q <= 0;
        end else begin
            q <= d;
        end
    end

endmodule
