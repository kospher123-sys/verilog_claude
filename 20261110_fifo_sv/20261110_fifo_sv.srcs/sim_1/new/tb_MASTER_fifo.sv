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

    property p_rst_full;
        @(posedge clk) rst |-> (full === 1'b0);
    endproperty

    property p_rst_empty;
        @(posedge clk) rst |-> (empty === 1'b1);
    endproperty

    a_rst_full :
    assert property (p_rst_full)
    else $display(" %t : [assert] error full = %d", $time, full);
    a_rst_empty :
    assert property (p_rst_empty)
    else $display(" %t : [assert] error empty = %d", $time, empty);
endinterface

class transaction;

    bit            rst;
    rand bit       push;
    rand bit       pop;
    rand bit [7:0] push_data;
    logic    [7:0] pop_data;
    logic          full;
    logic          empty;
    int            scenario;

    constraint test_scenario {
        if (scenario == 1) {
            push dist {
                0 :/ 0,
                1 :/ 10
            };
            pop dist {
                0 :/ 10,
                1 :/ 0
            };
        } else
        if (scenario == 2) {
            push dist {
                0 :/ 10,
                1 :/ 0
            };
            pop dist {
                0 :/ 0,
                1 :/ 10
            };
        }
    }

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
        int push_only_count = 10, pop_only_count = 10;
        $display(
            "push only test num = %d //////////////////////////////////////////////////////////////////////////////////////////////////",
            gen_cnt);
        repeat (push_only_count) begin
            tr = new;
            tr.scenario = 1;
            tr.randomize();
            tr.rst = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
        $display(
            "pop only test num = %d //////////////////////////////////////////////////////////////////////////////////////////////////",
            gen_cnt);
        repeat (pop_only_count) begin
            tr = new;
            tr.scenario = 2;
            tr.randomize();
            tr.rst = 0;
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
        $display(
            "push/pop test num = %d //////////////////////////////////////////////////////////////////////////////////////////////////",
            gen_cnt);
        repeat (gen_cnt) begin
            tr = new;
            tr.scenario = 3;
            tr.randomize();
            tr.rst = 0;
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
        fifo_vif.pop = 0;
        fifo_vif.push = 0;
        fifo_vif.push_data = 0;
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

    int fifo_size = 0;
    //coverage
    covergroup cg_fifo;
        option.per_instance = 1;
        //fifo push data
        cp_push_data: coverpoint tr.push_data iff (tr.push) {
            bins full[] = {[0 : 255]};  //seed
        }
        // fifo push,pop :op
        cp_push_pop: coverpoint {
            tr.push, tr.pop
        } {
            bins idle = {2'b00};
            bins push_only = {2'b10};
            bins push_pop = {2'b11};
            bins pop_only = {2'b01};
        }
        // fifo push,pop :state
        cp_full_empty: coverpoint {
            tr.full, tr.empty
        } {
            bins normall = {2'b00}; bins full = {2'b10}; bins empty = {2'b01};

        }
        cp_depth: coverpoint fifo_size {bins size[] = {[0 : 4]};}

        cx_op_st : cross cp_push_pop, cp_full_empty;
        cx_op_fifo_dpth : cross cp_push_pop, cp_depth;
    endgroup

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_evt = gen_next_evt;
        this.cg_fifo = new;
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

    bit expected_full = 0, expected_empty = 0;
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");
            total_cnt++;
            if (!tr.rst) begin
                fifo_size = expected_fifo.size();
                if (fifo_size == 4) begin
                    expected_full = 1;
                end else expected_full = 0;
                if (fifo_size == 0) begin
                    expected_empty = 1;
                end else expected_empty = 0;


                if (expected_full == tr.full) begin
                    $display("pass : fifo full signal ");
                    full_pass++;
                end else begin
                    $display("fail : fifo full signal ");
                    full_fail++;
                end

                if (expected_empty == tr.empty) begin
                    $display("pass : fifo empty signal ");
                    empty_pass++;
                end else begin
                    $display("fail : fifo empty signal ");
                    empty_fail++;
                end


                if (!expected_full & tr.push) begin
                    expected_fifo.push_back(tr.push_data);
                end
                if (!expected_empty & tr.pop) begin
                    if (expected_fifo.pop_front() === tr.pop_data) begin
                        pass_cnt++;
                        $display("pass");
                    end else begin
                        fail_cnt++;
                        $display("fail");
                    end
                end
                // coberage 1 update
                cg_fifo.sample();
            end
            ->gen_next_evt;
        end
    endtask

    task report();
        $display("***********************************");
        $display("**          FIFO test            **");
        $display("**    total test num = %4d      **", total_cnt);
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
        $display("**     FIFO test coverage        **");
        $display("** coverage push data = %4.2f%%  **",
                 cg_fifo.cp_push_data.get_coverage());
        $display("**coverage push/pop op = %4.2f%% **",
                 cg_fifo.cp_push_pop.get_coverage());
        $display("**coverage full/empty st = %4.2f%%*",
                 cg_fifo.cp_full_empty.get_coverage());
        $display("**coverage     cp_depth = %4.2f%%**",
                 cg_fifo.cp_depth.get_coverage());
        $display("**coverage     cx_op_st = %4.2f%%**",
                 cg_fifo.cx_op_st.get_coverage());
        $display("**coverage cx_op_dpth = %4.2f%%  **",
                 cg_fifo.cx_op_fifo_dpth.get_coverage());
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


module tb_master_fifo ();

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
        env.run(10000);

        $finish;
    end
endmodule

