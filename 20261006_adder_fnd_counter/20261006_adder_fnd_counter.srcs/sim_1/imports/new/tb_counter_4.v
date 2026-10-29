`timescale 1ns / 1ps


module tb_counter_4 ();
    reg clk, reset;
    wire o_clk_800hz;


    clk_div_800hz UDT (
        .clk(clk),
        .reset(reset),
        .o_clk_800hz(o_clk_800hz)
    );

    always #5 clk = ~clk;


    initial begin
        clk = 0;
        reset = 1;
        #10 ;
        reset = 0;

        # (250_000*30);  //(250_000 clk * 10nsec(1clock cycle))
        #100;

        

        $finish;
    end
endmodule
