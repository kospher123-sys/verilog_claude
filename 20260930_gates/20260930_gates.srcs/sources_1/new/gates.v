`timescale 1ns / 1ps


module gates (
    input  a,
    input  b,
    output y0,
    output y1,
    output y2,
    output y3,
    output y4,
    output y5,
    output y6
);

    assign y0 = a & b;  //a and b
    assign y1 = ~(a & b);  // a nand b
    assign y2 = a | b;  // a or b
    assign y3 = ~(a | b);  // a nor b
    assign y4 = a ^ b;  // a xor b
    assign y5 = ~(a ^ b);  // a xnor b
    assign y6 = ~a;  // not a


endmodule
