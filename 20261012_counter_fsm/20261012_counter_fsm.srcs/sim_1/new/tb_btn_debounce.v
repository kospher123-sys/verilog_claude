`timescale 1ns / 1ps


module tb_btn_debounce ();
    reg clk, reset, i_btn;
    wire o_btn;

    btn_debounce UDT (
        .clk  (clk),
        .reset(reset),
        .i_btn(i_btn),
        .o_btn(o_btn)
    );

always #5 clk = ~clk;

initial begin
    clk =0;
    reset =1;
    i_btn =0;
    #10 reset = 0;

    #10 i_btn =1 ; //noise
    #10 i_btn =1 ;
    #10 i_btn =0 ;
    #10 i_btn =1 ;
    #10 i_btn =0 ;
    
    #10 i_btn =1 ;

    #100 i_btn =0;
    #10;
    $stop;
end

endmodule
