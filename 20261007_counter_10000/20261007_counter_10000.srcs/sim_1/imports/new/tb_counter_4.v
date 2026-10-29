`timescale 1ns / 1ps


module tb_counter_4 ();
    reg clk, reset;
    wire [13:0] counter;


    data_path DUT(
    .clk(clk),
    .reset(reset),
    .counter(counter)
);


    always #5 clk = ~clk;


    initial begin
        clk = 0;
        reset = 1;
        #10 ;
        reset = 0;

        repeat(3)  //다음 세미콜론까지 의 코드를 반복
            # (10*10_000_000);  //(250_000 clk * 10nsec(1clock cycle))
       
        #1000; 

        $stop;
    end
endmodule
