`timescale 1ns / 1ps


module tb_rx(

    );
    reg        clk;
    reg        rst;
    reg        rx;
    reg [7:0] 
    wire tx;

    uart DUT(
    input  clk,
    input  rst,
    input  rx,   //from PC
    output tx    //to PC
);
always #5 clk=~clk;

initial begin
    

end 

endmodule
