`timescale 1ns / 1ps


module tb_blk_nblk(

    );

reg a,b,c,d,clk;

initial begin
    a=0;
    b=1;
    c=0;
    d=1;
    clk=0;
end

always clk = #5 ~clk;

always @(posedge clk) begin
    a=b;
    b=a;
end


always @(posedge clk) begin
    c<=d;
    d<=c;
end

endmodule
