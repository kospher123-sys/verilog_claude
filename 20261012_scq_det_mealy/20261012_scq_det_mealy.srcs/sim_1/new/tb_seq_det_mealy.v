`timescale 1ns / 1ps

module tb_seq_det_mealy ();
    // 입력 신호 선언
    reg  clk;
    reg  rst;
    reg  din_bit;

    // 출력 신호 선언
    wire dout_bit_me;
    wire dout_bit_mo;

    // MEALY
    nonoverlap_0101detec uut (
        .clk(clk),
        .rst(rst),
        .din_bit(din_bit),
        .dout_bit_me(dout_bit_me)
    );

    //MOORE
    nonoverlap_0101detec_moore udt (
        .clk(clk),
        .rst(rst),
        .din_bit(din_bit),
        .dout_bit_mo(dout_bit_mo)
    );

    // 클럭 생성 (예: 10ns 주기)
    always #5 clk = ~clk;

    initial begin
        // 초기값 설정
        clk = 0;
        rst = 1;
        din_bit = 0;

        // 리셋 신호
        #15 rst = 0;

        // 입력 신호 패턴 (예시)
        #5 din_bit = 1;
        #30 din_bit = 0;
        #10 din_bit = 1;
        #20 din_bit = 0;
        #40 din_bit = 1;
        #30 din_bit = 0;
        
        #10 din_bit = 1;
        #10 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;

        #30 din_bit = 1;
        #40 din_bit = 0;
        #10 din_bit = 1;
        #10 din_bit = 0;
        #30 din_bit = 1;
        #20 din_bit = 0;
        // 시뮬레이션 종료
        #100 $finish;
    end
endmodule
