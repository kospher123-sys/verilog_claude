`timescale 1ns / 1ps


module tb_counter_10000(

    );
    parameter BD_PUSH_TIME = 1000;

    reg clk, reset,btnL,btnU,btnR;
  
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;



    counter_10000 UDT(
        .clk(clk),
        .reset(reset),
        .btnL(btnL),
        .btnR(btnR),
        .btnU(btnU),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );


    always #5 clk = ~clk;


    initial begin
        clk = 0;
        reset = 1;
        btnL = 0;
        btnR = 0;
        btnU = 0;
        
        #10 ;
        reset = 0;

        btnR=1;
        repeat(BD_PUSH_TIME) @(posedge clk);  // up run

        btnR=0;

        repeat(3) #(10_000_000 *10);

        btnU = 1;
        repeat(BD_PUSH_TIME) @(posedge clk);  // down run

        btnU=0;

        repeat(5) #(10_000_000 *10);

        btnR=1;
        repeat(BD_PUSH_TIME) @(posedge clk); // stop

        btnR=0;

        btnL=1;
        repeat(BD_PUSH_TIME) @(posedge clk); // CLEAR
        btnL = 0;

        repeat(1) #(10_000_000 *10);
        
        

    

        
        #100;
        $stop;
    end


endmodule
