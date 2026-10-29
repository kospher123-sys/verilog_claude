`timescale 1ns / 1ps


module tb_tick_gen ();

    parameter PUSH_TIME = 10 * 100;
    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;

    reg clk, rst, rx;
    wire          tx;
    integer i;





    UART_FIFO_ASCII DUT (
        .clk     (clk),
        .rst     (rst),
        .rx      (rx),
        .tx      (tx)

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




    initial begin
        clk = 0;
        rst = 1;
        rx = 1;


        #10 rst = 0;

        sender_uart("r");
        sender_uart("c");
        sender_uart("u");
        sender_uart("s");
        sender_uart("s");
        sender_uart("s");
        

        #(1_000_000);

        $stop;


    end



endmodule
