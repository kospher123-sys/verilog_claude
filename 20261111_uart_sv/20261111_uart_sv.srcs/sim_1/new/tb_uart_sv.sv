`timescale 1ns / 1ps

interface uart_interface (
    input clk
);
    logic       rst;
    logic       start;
    logic [7:0] tx_data;
    logic       tx_busy;
    logic       tx;
endinterface

class transaction;
    bit                     rst;
    bit                     start;
    rand logic        [7:0] tx_data;
    rand int unsigned       interval;
    logic                   tx_busy;
    logic                   tx;
    //for mon,scb
    bit                     start_bit_error;
    bit                     stop_bit_error;
    bit                     frame_time_error;


    constraint interval_range {
        interval < 1000;
        }

    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d, start = %d, tx_data = %d,interval = %d, tx = %d, tx_busy = %d",
            $time, name, rst, start, tx_data, interval, tx, tx_busy);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run(int gen_cnt);
        repeat (gen_cnt) begin

            tr = new;
            tr.randomize();
            tr.rst   = 0;
            tr.start = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);

        end
    endtask

endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_interface uart_vif;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_interface uart_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_vif = uart_vif;
    endfunction

    int busy_check_count = 0;

    task run();
        forever begin
            @(negedge uart_vif.clk);
            busy_check_count = 0;
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            //check tx_busy
            while (uart_vif.tx_busy) begin  //dut는 전송이끝나고 바로 busy를 내리지 않고 1,2clk뒤에 내려 필요함
                @(negedge uart_vif.clk);
                busy_check_count++;
                if (busy_check_count > 10416 * 10) begin
                    $display("tx_busy high was too long........ !");
                    break;
                end
            end
            if (!uart_vif.tx_busy) begin
                repeat (tr.interval+1) @(negedge uart_vif.clk);
                uart_vif.rst     = 0;
                uart_vif.start   = 1;
                uart_vif.tx_data = tr.tx_data;
                @(negedge uart_vif.clk);
                uart_vif.start   = 0;
                uart_vif.tx_data = 8'hxx;
            end else begin

            end
        end
    endtask

    task preset();
        uart_vif.rst     = 1;
        uart_vif.start   = 0;
        uart_vif.tx_data = 0;
        @(negedge uart_vif.clk);
        @(negedge uart_vif.clk);
        uart_vif.rst = 0;
    endtask

endclass

class monitor;
    transaction tr_in, tr_out;
    mailbox #(transaction) mon2scb_in_mbox;
    mailbox #(transaction) mon2scb_out_mbox;
    virtual uart_interface uart_vif;
    parameter BAUD_TIME = 10416 * 10;  //10416 clock *10nsec
    parameter FRAME_TIME = BAUD_TIME * 10;

    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox,
                 virtual uart_interface uart_vif);
        this.mon2scb_in_mbox = mon2scb_in_mbox;
        this.mon2scb_out_mbox    = mon2scb_out_mbox;
        this.uart_vif = uart_vif;
    endfunction

    time frame_start_time;
    time start_time, c_time;

    task uart_receive(output logic [7:0] receive_data);
        @(!uart_vif.tx);
        // check start bit error 
        start_time = $time;
        frame_start_time = start_time;
        c_time = start_time;
        // #(BAUD_TIME / 2);  // baud의 가운데 지점

        while (uart_vif.tx == 0 & (c_time - start_time) <= BAUD_TIME) begin
            @(posedge uart_vif.clk);
            c_time = $time;
        end
        if ((c_time - start_time) >= (BAUD_TIME - BAUD_TIME / 16)) begin
            tr_out.start_bit_error = 0;  //pass
        end else begin
            tr_out.start_bit_error = 1;  //fail
        end

        $display("START bit TIME");
        $display("%t : c_time - start_time = %d", $time, c_time - start_time);
        //check start bit
        for (int i = 0; i < 8; i++) begin
            #(BAUD_TIME / 2);
            receive_data[i] = uart_vif.tx;
            #(BAUD_TIME / 2);
        end


        start_time = $time;
        c_time = start_time;
        while ((!uart_vif.tx) && ((c_time - start_time) <= BAUD_TIME / 2)) begin
            @(posedge uart_vif.clk);
            c_time = $time;
        end

        if ((c_time - start_time) >= BAUD_TIME / 2) begin
            tr_out.stop_bit_error = 1;
        end else begin
            // stop bit check
            start_time = $time;
            c_time = start_time;

            while ((uart_vif.tx == 1) &&(uart_vif.tx_busy)&& ((c_time - start_time) <= BAUD_TIME)) begin
                @(posedge uart_vif.clk);
                c_time = $time;
            end

            if ((c_time - start_time) > (BAUD_TIME - BAUD_TIME / 16)) begin
                tr_out.stop_bit_error = 0;  //pass
            end else begin
                tr_out.stop_bit_error = 1;  //fail
            end
            $display("STOP bit TIME");
            $display("%t : c_time - start_time = %d", $time,
                     c_time - start_time);
        end
        //frame time check
        c_time = $time;
        if ((c_time - frame_start_time) <= (FRAME_TIME + (BAUD_TIME / 2)) && 
            (c_time - frame_start_time) >= (FRAME_TIME - (BAUD_TIME / 2))) begin
            tr_out.frame_time_error = 0;
        end else begin
            tr_out.frame_time_error = 1;
        end
        $display("%t : frame TIME = %d ", $time, c_time - frame_start_time);

    endtask

    time start_interval=0, c_time_interval =0 ;
    int interval_cnt =0;

    task run();
        forever begin
            //1. check start ==1
            // @(posedge uart_vif.clk);    //forever 시간지연 + 2,3 번에 값을 읽는 타이밍 맞춤
            while (!uart_vif.start) begin  //start 틱신호가 0 일때 붙잡고있음 1이되면 아래로 넘어갑
                @(posedge uart_vif.clk);
            end
            c_time_interval = $time;
            //2. mon2scb_in_mbox put
            tr_in = new;
            tr_in.tx_data = uart_vif.tx_data;
            tr_in.interval = (c_time_interval - start_interval)/10;
            mon2scb_in_mbox.put(tr_in);
            tr_in.debug_print("MON_in");

            //3. baud_time*10 , mon2scb_out_mbox put
            //receive task
            tr_out = new;
            uart_receive(tr_out.tx_data);
            tr_out.rst = uart_vif.rst;
            tr_out.tx  = uart_vif.tx;
            start_interval = $time;
            mon2scb_out_mbox.put(tr_out);
            tr_out.debug_print("MON_out");
        end

    endtask

endclass

class scoreboad;
    transaction tr_in, tr_out;
    mailbox #(transaction) mon2scb_in_mbox;
    mailbox #(transaction) mon2scb_out_mbox;
    event gen_next_evt;

    // coverage
    covergroup cg_uart;
        option.per_instance = 1;

        cp_tx_data : coverpoint tr_in.tx_data{
            bins coner[] = {8'haa, 8'h55};
            bins data[] = {[0:255]};
        }
        cp_interval : coverpoint tr_in.interval{
            bins interval_coner = {0};
            bins interval_time [] = {[1:1041]};
        }
    endgroup

    function new(mailbox#(transaction) mon2scb_in_mbox,
                 mailbox#(transaction) mon2scb_out_mbox, event gen_next_evt);
        this.mon2scb_in_mbox = mon2scb_in_mbox;
        this.mon2scb_out_mbox = mon2scb_out_mbox;
        this.gen_next_evt = gen_next_evt;
        this.cg_uart=new();
    endfunction

    int total_cnt;
    int tx_data_pass = 0, tx_data_fail = 0;
    int tx_start_bit_pass = 0, tx_start_bit_fail = 0;
    int tx_stop_bit_pass = 0, tx_stop_bit_fail = 0;
    int tx_frame_time_bit_pass = 0, tx_frame_time_bit_fail = 0;


    task run();
        forever begin
            mon2scb_in_mbox.get(tr_in);
            tr_in.debug_print("SCB_in");
            mon2scb_out_mbox.get(tr_out);
            tr_out.debug_print("SCB_out");

            total_cnt++;
            if (!tr_out.start_bit_error) begin
                tx_start_bit_pass++;
                $display(" tx start bit pass !!!");
            end else begin
                tx_start_bit_fail++;
                $display(" tx start bit fail !!!");
            end

            if (tr_in.tx_data == tr_out.tx_data) begin
                tx_data_pass++;
                $display(" tx_data Pass !!!");
            end else begin
                tx_data_fail++;
                $display(" tx_data Fail !!!");
            end
            if (!tr_out.stop_bit_error) begin
                tx_stop_bit_pass++;
                $display(" tx stop bit pass !!!");
            end else begin
                tx_stop_bit_fail++;
                $display(" tx stop bit fail !!!");
            end
            if (!tr_out.frame_time_error) begin
                tx_frame_time_bit_pass++;
                $display(" tx frame time pass !!!");
            end else begin
                tx_frame_time_bit_fail++;
                $display(" tx frmae time fail !!!");
            end
            cg_uart.sample();
            ->gen_next_evt;
        end
    endtask

    task report();
        $display("*****************************************");
        $display("**      UART TX Verification Test      **");
        $display("*****************************************");
        $display("**         total count num = %4d      **", total_cnt);
        $display("*****************************************");
        $display("**      start bit pass num = %4d      **",
                 tx_start_bit_pass);
        $display("**      start bit fail num = %4d      **",
                 tx_start_bit_fail);
        $display("*****************************************");
        $display("**      tx_data   pass num = %4d      **", tx_data_pass);
        $display("**      tx_data   fail num = %4d      **", tx_data_fail);
        $display("*****************************************");
        $display("**      stop  bit pass num = %4d      **", tx_stop_bit_pass);
        $display("**      start bit fail num = %4d      **", tx_stop_bit_fail);
        $display("*****************************************");
        $display("**     frame time pass num = %4d      **",
                 tx_frame_time_bit_pass);
        $display("**     frame time fail num = %4d      **",
                 tx_frame_time_bit_fail);
        $display("*****************************************");
        $display("**           UART TX Coveragr          **");
        $display("*****************************************");
        $display("**          tx_data   = %6.2f%%        **", cg_uart.cp_tx_data.get_coverage());
        $display("**         interval   = %6.2f%%        **", cg_uart.cp_interval.get_coverage());
        $display("*****************************************");
        $display("**    END UART TX Verification Test    **");
        $display("*****************************************");

    endtask

endclass

class enviroment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboad              scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_in_mbox;
    mailbox #(transaction) mon2scb_out_mbox;

    event                  gen_next_evt;

    function new(virtual uart_interface uart_vif);
        gen2drv_mbox     = new;
        mon2scb_in_mbox  = new;
        mon2scb_out_mbox = new;
        gen              = new(gen2drv_mbox, gen_next_evt);
        drv              = new(gen2drv_mbox, uart_vif);
        mon              = new(mon2scb_in_mbox, mon2scb_out_mbox, uart_vif);
        scb              = new(mon2scb_in_mbox, mon2scb_out_mbox, gen_next_evt);
    endfunction

    task run(int gen_cnt);
        drv.preset();
        fork
            gen.run(gen_cnt);
            drv.run();
            mon.run();
            scb.run();
        join_any
        $display("end fork join");
        scb.report();
    endtask
endclass

module tb_uart_sv ();
    parameter BAUD_TIME = (100_000_000 / 9600) * 10;
    logic clk = 0;
    uart_interface uart_if (clk);
    enviroment env;

    uart DUT (
        .clk    (clk),
        .rst    (uart_if.rst),
        .start  (uart_if.start),
        .tx_data(uart_if.tx_data),
        .tx_busy(uart_if.tx_busy),
        .tx     (uart_if.tx)
    );

    always #5 clk = ~clk;

    initial begin
        env = new(uart_if);
        env.run(1000);
        $finish;
    end
endmodule
