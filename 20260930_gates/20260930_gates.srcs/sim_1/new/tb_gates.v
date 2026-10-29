`timescale 1ns / 1ps



module tb_gates ();

    reg a, b;  // 값을 드라이브할 변수
    wire y0, y1, y2, y3, y4, y5, y6;  //값을 출력할 qustn


    gates DUT (
        .a (a),
        .b (b),
        .y0(y0),
        .y1(y1),
        .y2(y2),
        .y3(y3),
        .y4(y4),
        .y5(y5),
        .y6(y6)
    );


    initial begin
        a = 0;
        b = 0;

        #1;  //1ns delay

        a = 1;
        b = 0;

        #1 
        a = 0;
        b = 1;

        #1;

        a = 1;
        b = 1;

        #1;

        $stop;


    end

endmodule
