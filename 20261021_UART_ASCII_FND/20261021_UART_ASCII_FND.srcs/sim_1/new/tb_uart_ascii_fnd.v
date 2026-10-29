`timescale 1ns / 1ps

module tb_uart_ascii_fnd ();

    parameter BAUD_BIT_PERIOD = 100_000_000 / 9600 * 10;
    reg clk;
    reg rst;
    reg rx;
    wire tx;
    wire [3:0] fnd_com;
    wire [7:0] fnd_font;

    reg [7:0] result_data, expected_data;

    uart_ascii_fnd DUT (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
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
        expected_data = 8'h30;

        #10 rst = 0;
        expected_data = $random()%256;
        sender_uart(expected_data);
        receive_uart(result_data);


        #100;
        $stop;


    end

endmodule
