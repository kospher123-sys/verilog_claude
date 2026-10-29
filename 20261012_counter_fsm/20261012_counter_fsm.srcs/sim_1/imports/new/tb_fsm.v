`timescale 1ns / 1ps

module tb_fsm(

    );

    reg clk;
    reg reset;
    reg [1:0] sw;
    wire [2:0] led;
    wire clear;
    wire run_stop;

led_fsm UDT_LED(
    .clk(clk),
    .reset(reset),
    .sw(sw),
    .led(led)
);

counter_fsm UDT_COUNTER_FSM(
    .clk(clk),
    .reset(reset),
    .sw(sw),
    .clear(clear),
    .run_stop(run_stop)
);


always #5 clk = ~clk;


always begin
    clk = 0;
    reset = 1;
    sw=2'b00;
    #20;
    reset = 0;

    sw = 2'b00;
    #20;

    sw = 2'b01; //s2, run
    #20;

    sw = 2'b10; //s3, stop -> clear
    #20;

    sw = 2'b11; //s4, run
    #20;

    sw = 2'b10; //s5, stop -> clear
    #20;

    sw = 2'b00; //s1, stop  ///1바꾸
    #20;

    sw = 2'b01; //s2
    #20;

    sw = 2'b10; //s3
    #20;

    sw = 2'b11; //s4
    #20;

    sw = 2'b01; //s2
    #20;

    sw = 2'b10; //s3
    #20;

    sw = 2'b11; //s4
    #20;

    sw = 2'b00; //s1
    #20;

    $stop;

end



endmodule
