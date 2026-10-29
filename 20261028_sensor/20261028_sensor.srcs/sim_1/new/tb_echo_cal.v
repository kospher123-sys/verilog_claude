`timescale 1ns / 1ps
module tb_echo_cal ();

    parameter PUSH_TIME = 1000 *9;
    parameter US = 100;

    reg clk;
    reg rst;
    reg sr04_start;
    reg echo;
    wire trig;
    wire [8:0] distance;

    SR04_MASTER DUT (
        .clk(clk),
        .rst(rst),
        .sr04_start(sr04_start),
        .echo(echo),
        .trig(trig)
    );


    always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;
        echo = 0;
        sr04_start = 0;

        #10;
        rst = 0;
        #10;
        @(negedge clk);
        sr04_start = 1;
        @(posedge trig);
        sr04_start = 0;


        @(negedge trig);

        #(2000);

        echo = 1;
        #(600 * 1_0000);
        echo = 0;

        #(10_000_000);
        #(2000);
        $stop;

    end




endmodule
