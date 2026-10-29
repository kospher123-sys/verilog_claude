`timescale 1ns / 1ps


module tb_tick_gen ();

    parameter PUSH_TIME = 10 * 100;
    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;

    reg clk, rst, rx;
    reg [7:0] result_data, expected_data;
    wire tx;
    integer i;
    integer pass_count, fail_count;

    uart_loopback_FIFO DUT (
        .clk(clk),
        .rst(rst),
        .rx (rx),   //from PC
        .tx (tx)    //to PC
    );

    always #5 clk = ~clk;
    // send data to rx
    task sender_uart(input [7:0] send_data);
        integer i;
        begin
            rx = 0;  //start bit
            #(BAUD_BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BAUD_BIT_PERIOD);
            end
            rx = 1;  //stop bit
            #(BAUD_BIT_PERIOD);
        end
    endtask

    //receive data to rx
    task receive_uart(output [7:0] rx_data);
        integer i;
        begin
            wait (~tx);  //edge는 이벤트르 놓칠 수있음
            #(BAUD_BIT_PERIOD / 2);
            if (tx != 0)
                $display("error start bit");  // start bit 오류 검사

            for (i = 0; i < 8; i = i + 1) begin
                #(BAUD_BIT_PERIOD);
                rx_data[i] = tx;
            end

            #(BAUD_BIT_PERIOD);
            if (!tx) $display("error stop bit");
        end
    endtask

    task score_board(input [7:0] result, expected);
    
        begin
            if (result_data == expected_data)begin
                $display("%t : pass!!!!", $time);  //시간은 ps단위 (테스트 벤치의 해석 단위)
                pass_count = pass_count +1;
            end
            else begin
                $display("%t : fail!!!!", $time);
                fail_count = fail_count +1;
            end
        end
    endtask

    
    initial begin
        clk = 0;
        rst = 1;
        rx = 1;
        pass_count =0;
        fail_count =0;
        expected_data = 8'h30;

        #10 rst = 0;
        for (i = 0; i < 256; i = i + 1) begin
            expected_data = 8'hx;
            sender_uart(expected_data);
            receive_uart(result_data);
            score_board(result_data, expected_data);
        end

        #(1_000_000);
        $display ("total test num = %d", i);
        $display("pass_count = %d", pass_count);
        $display("fail_count = %d", fail_count);
        $stop;


    end



endmodule
