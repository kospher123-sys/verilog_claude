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
    bit            rst;
    rand bit       mode;
    rand bit       run_stop;
    rand bit       clear;
    logic    [7:0] counter;

    function debug_ptint(string name);
        $display(
            "%t [%s]: rst = %4d, mode = %4d, run_stop = %4d, clear = %4d, counter = %4d ",
            $time, name, rst, mode, run_stop, clear, counter);
    endfunction

    constraint mode_dist {
        mode dist {
            0 :/ 9,
            1 :/ 1
        };
    }

    static int hold_cnt = 0;  // 남은 유지 클럭 수 (객체 간 공유)

    constraint mode_hold {(hold_cnt > 0) -> (mode == 1);}

    function void post_randomize();  // randomize() 직후 자동 호출
        if (hold_cnt > 0) hold_cnt--;
        else if (mode) hold_cnt = 2;  // 이번 1 + 이후 2번 = 3클럭
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

    bit enable = 1;

    task run();

        while (enable) begin
            tr = new;
            tr.randomize();
            tr.rst = 0;
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
            tr.debug_ptint("DRV");
            cnt_ifv.rst = tr.rst;
            cnt_ifv.mode = tr.mode;
            cnt_ifv.run_stop = tr.run_stop;
            cnt_ifv.clear = tr.clear;
            ->gen_next_evt;
        end
    endtask

    task preset();
        cnt_ifv.rst      = 1;
        cnt_ifv.mode     = 0;
        cnt_ifv.run_stop = 0;
        cnt_ifv.clear    = 0;
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
            #1;
            tr = new;
            tr.rst = cnt_ifv.rst;
            tr.mode = cnt_ifv.mode;
            tr.run_stop = cnt_ifv.run_stop;
            tr.clear = cnt_ifv.clear;
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

            tr.debug_ptint("SCB");

            if (!(tr.rst || tr.clear)) begin
                total_cnt++;
                $display("%t : ecpected_count = %d", $time, expected_count);
                if (tr.run_stop) begin
                    if (tr.mode) begin
                        expected_count--;
                    end else begin
                        expected_count++;
                    end
                end else begin
                    expected_count = expected_count;
                end

                if (expected_count === tr.counter) begin
                    $display("%t : PASS", $time);
                    pass_cnt++;
                end else begin
                    $display("%t : fail", $time);
                    fail_cnt++;
                end

            end else begin
                expected_count = 0;
            end
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

    task run();
        drv.preset();
        gen.enable = 1;
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
        #3000;
        gen.enable = 0;
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
        env.run();

        #100;
        $finish;
    end
endmodule
