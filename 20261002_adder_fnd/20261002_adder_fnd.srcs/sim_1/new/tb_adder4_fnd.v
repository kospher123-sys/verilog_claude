`timescale 1ns / 1ps


module tb_adder4_fnd ();

    reg [3:0] a, b;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;
    wire led;
    integer i;

    adder4_fnd UDT (
        .a(a),
        .b(b),
        .fnd_font(fnd_font),
        .fnd_com(fnd_com),
        .led(led)
    );

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            a = 4'b0000;
            b = i;
            #10;
        end
        $finish;

    end


endmodule
