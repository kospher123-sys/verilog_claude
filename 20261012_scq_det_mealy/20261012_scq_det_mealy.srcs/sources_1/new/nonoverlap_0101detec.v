`timescale 1ns / 1ps

module nonoverlap_0101detec (
    input clk,
    input rst,
    input din_bit,
    output dout_bit_me
);

    reg [1:0] state_reg, next_state;

    parameter s0 = 2'b00;
    parameter s1 = 2'b01;
    parameter s2 = 2'b10;
    parameter s3 = 2'b11;

    always @(posedge clk, posedge rst) begin
        if (rst == 1) state_reg <= s0;
        else state_reg <= next_state;
    end

    always @(state_reg, din_bit) begin

        case (state_reg)
            s0: begin
                if (din_bit == 0) next_state = s1;
                else if (din_bit == 1) next_state = s0;
                else next_state = s0;
            end
            s1: begin

                if (din_bit == 0) next_state = s1;
                else if (din_bit == 1) next_state = s2;
                else next_state = s0;
            end
            s2: begin

                if (din_bit == 0) next_state = s3;
                else if (din_bit == 1) next_state = s0;
                else next_state = s0;
            end
            s3:
            if (din_bit == 0)  next_state = s1;
            else if (din_bit == 1) next_state = s0;
            else next_state = s0;

            default: next_state = s0;
        endcase

    end

    // mealy
    assign dout_bit_me = ((state_reg == s3) && (din_bit == 1)) ? 1 : 0;

endmodule
