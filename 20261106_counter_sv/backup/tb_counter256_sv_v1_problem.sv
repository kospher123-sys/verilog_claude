`timescale 1ns / 1ps

interface counter_interface (
    input clk
);
    logic rst;
    logic [7:0] counter;
endinterface

class transaction;
    bit         rst;
    logic [7:0] counter;
endclass

class generator;
    transaction            tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;

    function new(mailbox#(transaction) gen2drv_mbox,event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run(int rst_count);
        repeat (rst_count) begin
            tr = new;
            tr.randomize();
            gen2drv_mbox.put(tr);
            @(gen_next_evt);
            #1;
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual counter_interface cnt_ifv;
    event gen_next_evt;

    function new(virtual counter_interface cnt_ifv,mailbox#(transaction) gen2drv_mbox,event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.cnt_ifv = cnt_ifv;
        this.gen_next_evt = gen_next_evt;
    endfunction

    task run();
        forever begin
            @(negedge cnt_ifv.clk);
            cnt_ifv.rst = tr.rst;
            @(posedge cnt_ifv.clk);
            ->gen_next_evt;
        end
    endtask

    task preset();
        cnt_ifv.rst = 1;
        @(negedge cnt_ifv.clk);
        @(negedge cnt_ifv.clk);
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual counter_interface cnt_ifv;
    event scb_next_evt;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual counter_interface cnt_ifv,event scb_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.cnt_ifv = cnt_ifv;
        this.scb_next_evt = scb_next_evt;
    endfunction

    task run();
        forever begin
            if (cnt_ifv.clk) begin
                tr = new;
                tr.rst = cnt_ifv.rst;
                tr.counter = cnt_ifv.counter;

                mon2scb_mbox.put(tr);
                ->scb_next_evt;
            end
        end
    endtask
endclass

class scoreboad;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event scb_next_evt;

    function new(mailbox#(transaction) mon2scb_mbox,event scb_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.scb_next_evt = scb_next_evt;
    endfunction

    task run();
        forever begin
            tr = new;
            @(scb_next_evt);
            mon2scb_mbox.get(tr);

            if (tr.counter == 0) begin
                $display("%t : PASS", $time);
            end else begin
                $display("%t : fail", $time);
            end

        end
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
    event scb_next_evt;

    function new(virtual counter_interface cnt_ifv);
        this.cnt_ifv = cnt_ifv;
        gen = new(gen2drv_mbox,gen_next_evt);
        drv = new(cnt_ifv,gen2drv_mbox,gen_next_evt);
        mon = new(mon2scb_mbox, cnt_ifv, scb_next_evt);
        scb = new(mon2scb_mbox, scb_next_evt);
    endfunction

    task run(int rst_count);
        drv.preset();
        fork
            gen.run(rst_count);
            drv.run();
            mon.run();
            scb.run();
        join_any
    endtask


endclass

module tb_counter256_sv ();
    logic clk = 0;
    counter_interface countr_if (clk);
    enviroment env;

    counter_256 DUT (
        .clk    (clk),
        .rst    (countr_if.rst),
        .counter(countr_if.counter)
    );

    always #5 clk = ~clk;

    initial begin
        env = new(countr_if);
        env.run(10);

        #100;
        $finish;
    end
endmodule
