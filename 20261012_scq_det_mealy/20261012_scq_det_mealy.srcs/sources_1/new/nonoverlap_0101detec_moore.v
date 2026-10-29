`timescale 1ns / 1ps



module nonoverlap_0101detec_moore(
    input  clk,
    input  rst,
    input  din_bit,
    output dout_bit_mo
    );

    reg [2:0] state_reg, next_state;

    parameter s0 = 3'b000;
    parameter s1 = 3'b001;
    parameter s2 = 3'b010;
    parameter s3 = 3'b011;
    parameter s4 = 3'b100;

    always @(posedge clk, posedge rst) begin
        if (rst == 1) state_reg <= s0;
        else state_reg <= next_state;
    end

    always @(state_reg or din_bit) begin
        case (state_reg)
            s0:
            if (din_bit == 0) next_state = s1;
            else if (din_bit == 1) next_state = s0;
            else next_state = s0;
            s1:
            if (din_bit == 0) next_state = s1;
            else if (din_bit == 1) next_state = s2;
            else next_state = s0;
            s2:
            if (din_bit == 0) next_state = s3;
            else if (din_bit == 1) next_state = s0;
            else next_state = s0;
            s3:
            if (din_bit == 0) next_state = s0;
            else if (din_bit == 1) next_state = s4;
            else next_state = s0;
            s4:
            if (din_bit == 0) next_state = s1;
            else if (din_bit == 1) next_state = s0;
            else next_state = s0;
            default: next_state = s0;
        endcase

    end

    // moore
    assign dout_bit_mo = (state_reg == s4 ) ? 1 : 0;


endmodule
