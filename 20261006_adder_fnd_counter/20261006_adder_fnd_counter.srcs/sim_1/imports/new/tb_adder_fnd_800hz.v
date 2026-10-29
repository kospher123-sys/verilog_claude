`timescale 1ns / 1ps


module tb_adder_fnd_800hz ();
    reg clk;
    reg reset;
    reg [7:0] a;
    reg [7:0] b;
    wire [7:0] fnd_font;
    wire [3:0] fnd_com;
    integer i, j;

    adder_fnd UDT (
        .clk(clk),
        .reset(reset),
        .a(a),
        .b(b),
        .fnd_font(fnd_font),
        .fnd_com(fnd_com)
    );

    always #5 clk = ~clk;


    initial begin
        clk   = 0;
        reset = 1;
        #10;
        reset = 0;
        for (i = 0; i < 10; i = i + 1) begin
            for (j = 0; j < 10; j = j + 1) begin

            a = i;
            b = j;

            #(250_000 * 20);


            end
        end

        #100;
        $finish;
    end



endmodule
