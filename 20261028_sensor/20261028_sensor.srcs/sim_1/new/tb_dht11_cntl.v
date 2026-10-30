`timescale 1ns / 1ps
module tb_dht11_cntl ();

    parameter US = 1000, MS = 1_000_000;

    reg         clk;
    reg         rst;
    reg         dht11_start;
    reg         us_tick;
    wire        valid;
    wire [15:0] humidity;
    wire [15:0] temperature;

    wire        dht11_io;
    wire         tb_oe;
    reg         dht11_o;


    assign tb_oe = DUT.dht11_io_control_reg;
    assign dht11_io = (!tb_oe) ? dht11_o : 1'bz;

    dht11_controller DUT (
        .clk(clk),
        .rst(rst),
        .dht11_start(dht11_start),
        .us_tick(us_tick),
        .valid(valid),
        .humidity(humidity),
        .temperature(temperature),
        .dht11_io(dht11_io)
    );

    always #5 clk = ~clk;
    always begin
        #(1_000 - 5) us_tick = 1;
        #5 us_tick = 0;
    end

    task sendsync();
        begin
            dht11_o = 0;
            #(US * 80);
            dht11_o = 1;
            #(US * 80);
        end
    endtask

    task senddata0();
        begin
            dht11_o = 0;
            #(US * 50);
            dht11_o = 1;
            #(US * 30);
        end
    endtask
    task senddata1();
        begin
            dht11_o = 0;
            #(US * 50);
            dht11_o = 1;
            #(US * 60);
        end
    endtask


    initial begin
        clk = 0;
        rst = 1;
        dht11_start = 0;
        us_tick = 0;



        #10;
        rst = 0;
        dht11_start = 1;
        @(posedge clk);

        #(US * 19_000);  //start 0
        #(US * 30);  //wait 1

        sendsync();

        repeat (4) begin    //temperature
            senddata0();
            senddata1();
            senddata1();
            senddata1();
        end

        repeat (4) begin    //humidity
            senddata1();
            senddata0();
            senddata0();
            senddata0();
        end

        repeat (1) begin    //check_sum[7:0]
            senddata1();
            senddata1();
            senddata1();
            senddata1();
            senddata1();
            senddata1();
            senddata1();
            senddata0();
        end        


        dht11_o = 0;

        #(US * 50);


        $stop;




    end



endmodule
