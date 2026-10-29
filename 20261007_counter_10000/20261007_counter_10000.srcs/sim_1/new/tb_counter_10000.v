`timescale 1ns / 1ps


module tb_counter_10000(

    );


    reg clk, reset;
    reg [2:0] sw;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;



    counter_10000 UDT(
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );


    always #5 clk = ~clk;


    initial begin
        clk = 0;
        reset = 1;
        sw=3'b000;
        #10 ;
        reset = 0;

        repeat(2)  //다음 세미콜론까지 의 코드를 반복
            # (10*10_000_000);  

        sw=3'b001;  //up run

        
        #100;
        $stop;
    end


endmodule
