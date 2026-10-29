`timescale 1ns / 1ps


module tb_adder ();
    reg a, b;
    wire s;
    wire c;
integer  i,j;

half_adder UDT(
    .a(a),
    .b(b),
    .s(s),
    .c(c)
);
    initial begin

        for (i = 0; i < 2; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                a = i;
                b = j;
                #10;
            end
        end
        #20
        $finish;
    end

endmodule
