`timescale 1ns / 1ps



interface counter_interface (
    input clk
);
    logic       rst;
    logic       mode;
    logic       run_stop;
    logic       clear;
    logic [7:0] counter;
endinterface

class transaction;
    bit         rst;
    bit         mode;
    bit         run_stop;
    bit         clear;
    logic [7:0] counter;

    function debug_ptint(string name);
        $display(
            "%t [%s]: rst = %4d, mode = %4d, run_stop = %4d, clear = %4d, counter = %4d ",
            $time, name, rst, mode, run_stop, clear, counter);
    endfunction

endclass

class generator;
    transaction            tr;
    mailbox #(transaction) gen2drv_mbox;
    event                  gen_next_evt;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run(int rst_count);
        for (int i = 0; i < rst_count; i++) begin
            tr = new;
            if (i < (rst_count/4)*2) begin
                tr.run_stop = 1;
                if (i < (rst_count/4)) begin
                    tr.mode = 0;
                end else if (i < (rst_count/4)) begin
                    tr.mode = 1;
                end
            end else if (i < (rst_count/4)*3) begin
                tr.run_stop = 0;
            end else tr.clear = 1;

            gen2drv_mbox.put(tr);
            tr.debug_ptint("GEN");
            @(gen_next_evt);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual counter_interface cnt_ifv;
    event gen_next_evt;

    function new(virtual counter_interface cnt_ifv,
                 mailbox#(transaction) gen2drv_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.cnt_ifv = cnt_ifv;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run();
        forever begin
            @(negedge cnt_ifv.clk);
            gen2drv_mbox.get(tr);
            cnt_ifv.rst = tr.rst;
            tr.debug_ptint("DRV");
            @(posedge cnt_ifv.clk);
            ->gen_next_evt;
        end
    endtask

    task preset();
        cnt_ifv.rst = 1;
        @(negedge cnt_ifv.clk);
        @(negedge cnt_ifv.clk);
        cnt_ifv.rst = 0;
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual counter_interface cnt_ifv;


    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual counter_interface cnt_ifv);
        this.mon2scb_mbox = mon2scb_mbox;
        this.cnt_ifv = cnt_ifv;

    endfunction

    task run();
        forever begin
            @(posedge cnt_ifv.clk);
            // #1;
            tr = new;
            tr.rst = cnt_ifv.rst;
            tr.counter = cnt_ifv.counter;

            mon2scb_mbox.put(tr);
            tr.debug_ptint("MON");

        end
    endtask
endclass

class scoreboad;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction

    logic [7:0] expected_count = 0;
    int pass_cnt = 0, fail_cnt = 0, total_cnt = 0;
    task run();
        forever begin
            tr = new;
            mon2scb_mbox.get(tr);
            total_cnt++;

            tr.debug_ptint("SCB");
            if (tr.rst) begin
                expected_count = 0;
            end

            $display("%t : ecpected_count = %d", $time, expected_count);
            if (expected_count === tr.counter) begin
                $display("%t : PASS", $time);
                pass_cnt++;
            end else begin
                $display("%t : fail", $time);
                fail_cnt++;
            end
            if (!tr.rst) expected_count++;

        end
    endtask

    task report();
        $display("***********************************");
        $display("***** counter 256 test progeam*****");
        $display("**       total test = %4d       **", total_cnt);
        $display("**       pass  test = %4d       **", pass_cnt);
        $display("**       fail  test = %4d       **", fail_cnt);
        $display("***********************************");
        $display("****** end counter 256 test *******");
        $display("***********************************");
    endtask

endclass

class enviroment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboad scb;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2drv_mbox;
    virtual counter_interface cnt_ifv;
    event gen_next_evt;


    function new(virtual counter_interface cnt_ifv);
        this.cnt_ifv = cnt_ifv;
        mon2scb_mbox = new;
        gen2drv_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(cnt_ifv, gen2drv_mbox, gen_next_evt);
        mon = new(mon2scb_mbox, cnt_ifv);
        scb = new(mon2scb_mbox);
    endfunction

    task run(int rst_count);
        drv.preset();
        fork
            gen.run(rst_count);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        scb.report();

        disable fork;
    endtask


endclass



module tb_counter_3mod ();
    logic clk = 0;
    counter_interface countr_if (clk);
    enviroment env;

    counter_256 DUT (
        .clk(clk),
        .rst(countr_if.rst),
        .mode(countr_if.mode),
        .run_stop(countr_if.run_stop),
        .clear(countr_if.clear),
        .counter(countr_if.counter)
    );

    always #5 clk = ~clk;

    initial begin
        env = new(countr_if);
        env.run(256);

        #100;
        $finish;
    end
endmodule
