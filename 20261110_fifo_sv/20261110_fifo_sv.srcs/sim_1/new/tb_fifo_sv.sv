`timescale 1ns / 1ps
interface fifo_interface (
    input clk
);
    logic       rst;
    logic       push;
    logic       pop;
    logic [7:0] push_data;
    logic [7:0] pop_data;
    logic       full;
    logic       empty;
endinterface

class transaction;

    bit            rst;
    rand bit       push;
    rand bit       pop;
    rand bit [7:0] push_data;
    logic    [7:0] pop_data;
    logic          full;
    logic          empty;

    function void debug_print(string name);
        $display(
            "%t : [%s] rst = %d, push = %d, pop = %d, push_data = %d, pop_data = %d, full = %d, empty = %d",
            $time, name, rst, push, pop, push_data, pop_data, full, empty);
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
            tr.rst = 0;
            // tr.push = 0;
            // tr.pop  = 1;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual fifo_interface fifo_vif;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_vif = fifo_vif;
    endfunction

    task run();
        forever begin
            @(posedge fifo_vif.clk);
            gen2drv_mbox.get(tr);
            tr.debug_print("DRV");
            #1;
            fifo_vif.rst = tr.rst;
            fifo_vif.push = tr.push;
            fifo_vif.pop = tr.pop;
            fifo_vif.push_data = tr.push_data;
        end
    endtask

    task preset();
        fifo_vif.rst = 1;
        @(posedge fifo_vif.clk);
        @(posedge fifo_vif.clk);
        fifo_vif.rst = 0;
    endtask
endclass


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual fifo_interface fifo_vif;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_vif = fifo_vif;
    endfunction

    task run();
        forever begin
            @(negedge fifo_vif.clk);
            tr           = new;
            tr.rst       = fifo_vif.rst;
            tr.push      = fifo_vif.push;
            tr.pop       = fifo_vif.pop;
            tr.push_data = fifo_vif.push_data;
            tr.pop_data  = fifo_vif.pop_data;
            tr.full      = fifo_vif.full;
            tr.empty     = fifo_vif.empty;

            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask
endclass

class scoreboad;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_evt;


    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    logic [7:0] expected_fifo[$:3];

    int total_cnt = 0;
    int pass_cnt = 0;
    int fail_cnt = 0;
    int full_pass = 0;
    int full_fail = 0;
    int empty_pass = 0;
    int empty_fail = 0;
    int push_cnt = 0;
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");
            if (!tr.rst) begin
                total_cnt++;
                if (tr.pop & tr.push) begin  //push & pop
                    if (tr.full) begin
                        if (expected_fifo.size() == 4) begin  //full pass/fail
                            full_pass++;
                            $display("%t : full pass", $time);
                        end else begin
                            full_fail++;
                            $display("%t : full fail", $time);
                        end

                        if (expected_fifo.pop_front() === tr.pop_data) begin //pop 
                            $display("%t : pop PASS", $time);
                            pass_cnt++;
                        end else begin
                            $display("%t : pop fail", $time);
                            fail_cnt++;
                        end
                    end else if (tr.empty) begin
                        if (expected_fifo.size() == 0) begin
                            empty_pass++;
                            $display("%t : empty pass", $time);
                        end else begin
                            empty_fail++;
                            $display("%t : empty fail", $time);
                        end

                        expected_fifo.push_back(tr.push_data);
                        push_cnt++;

                    end else begin
                        expected_fifo.push_back(tr.push_data);
                        push_cnt++;

                        if (expected_fifo.pop_front() === tr.pop_data) begin //pop 
                            $display("%t : pop PASS", $time);
                            pass_cnt++;
                        end else begin
                            $display("%t : pop fail", $time);
                            fail_cnt++;
                        end

                    end

                end else begin
                    if (tr.push) begin
                        if (!tr.full) begin  //  push
                            expected_fifo.push_back(tr.push_data);
                            push_cnt++;
                        end else if (tr.full) begin  //full & push
                            if (expected_fifo.size() == 4) begin
                                full_pass++;
                                $display("%t : full pass", $time);
                            end else begin
                                full_fail++;
                                $display("%t : full fail", $time);
                            end
                        end
                    end
                    if (tr.pop) begin
                        if (!tr.empty) begin  //pop   
                            if (expected_fifo.pop_front() === tr.pop_data) begin
                                $display("%t : pop PASS", $time);
                                pass_cnt++;
                            end else begin
                                $display("%t : pop fail", $time);
                                fail_cnt++;
                            end
                        end else if (tr.empty) begin  //empty & pop
                            if (expected_fifo.size() == 0) begin
                                empty_pass++;
                                $display("%t : empty pass", $time);
                            end else begin
                                empty_fail++;
                                $display("%t : empty fail", $time);
                            end
                        end
                    end
                end





            end
            ->gen_next_evt;
        end
    endtask

    task report();
        $display("***********************************");
        $display("**          FIFO test            **");
        $display("**       total test = %4d       **", total_cnt);
        $display("***********************************");
        $display("**       push count = %4d       **", push_cnt);
        $display("***********************************");
        $display("**     pop pass  test = %4d     **", pass_cnt);
        $display("**     pop fail  test = %4d     **", fail_cnt);
        $display("***********************************");
        $display("**    full pass  test = %4d     **", full_pass);
        $display("**    full fail  test = %4d     **", full_fail);
        $display("***********************************");
        $display("**    empty pass  test = %4d    **", empty_pass);
        $display("**    empty fail  test = %4d    **", empty_fail);
        $display("***********************************");
        $display("**        FIFO test end          **");
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

    event gen_next_evt;

    function new(virtual fifo_interface fifo_vif);
        mon2scb_mbox = new;
        gen2drv_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, fifo_vif);
        mon = new(mon2scb_mbox, fifo_vif);
        scb = new(mon2scb_mbox, gen_next_evt);
    endfunction

    task run(int gen_cnt);
        drv.preset();
        fork
            gen.run(gen_cnt);
            drv.run();
            mon.run();
            scb.run();
        join_any
        scb.report();
        #10;
        $display("end fifo test!!");
    endtask

endclass


module tb_fifo_sv ();
    logic clk = 0;
    fifo_interface fifo_if (clk);
    enviroment env;


    fifo_sv DUT (
        .clk(clk),
        .rst(fifo_if.rst),
        .push(fifo_if.push),
        .pop(fifo_if.pop),
        .push_data(fifo_if.push_data),
        .pop_data(fifo_if.pop_data),
        .full(fifo_if.full),
        .empty(fifo_if.empty)
    );

    always #5 clk = ~clk;


    initial begin
        env = new(fifo_if);
        env.run(200);

        $finish;
    end

endmodule
