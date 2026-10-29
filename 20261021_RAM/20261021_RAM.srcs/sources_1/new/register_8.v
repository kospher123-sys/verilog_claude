`timescale 1ns / 1ps

module register_8 (
    input clk,
    input rst,
    input [7:0] din,
    output reg [7:0] q
);

    // reg [7:0] q_reg;

    // assign q = q_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            q <= 0;
        end else begin
            q <= din;
        end
    end

endmodule
