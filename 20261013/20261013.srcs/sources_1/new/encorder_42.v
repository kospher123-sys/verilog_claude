`timescale 1ns / 1ps

module encorder_42 (
    input      [3:0] enc_in,
    output reg       valid,
    output reg [1:0] enc_out
);

    // reg valid;
    // reg [1:0] enc_out;

    always @(enc_in) begin
        valid = 1'b1;
        if (enc_in[3]) enc_out = 2'b11;
        else if (enc_in[2]) enc_out = 2'b10;
        else if (enc_in[1]) enc_out = 2'b01;
        else if (enc_in[0]) enc_out = 2'b00;
        else begin
            valid   = 1'b0;
            enc_out = 2'bxx;
        end
    end



endmodule

module if_else_if(
    input sela,
    input selb,
    input selc,
    input seld,
    input [3:0] dinA,
    input [3:0] dinB,
    input [3:0] dinC,
    input [3:0] dinD,
    input [3:0] dinE,
    output reg [3:0] dout
);

    always @(*) begin
        if (sela) dout = dinA;
        else if (selb) dout = dinB;
        else if (selc) dout = dinC;
        else if (seld) dout = dinD;
        else  dout = dinE;
    end

endmodule



