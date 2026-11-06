`timescale 1ns / 1ps

interface reg_interface (
    input clk
);  //클럭은 외부에서 넣어줌 
    logic reset;
    logic [7:0] d;
    logic [7:0] q;
endinterface

class transaction;
    bit reset;
    rand bit [7:0] d;
    logic [7:0] q;

    function debug_ptint(string name);
        $display("%t : [%s] reset : %d, d : %d, q : %d", $time, name, reset, d,
                 q);
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

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.debug_ptint("GEN");
            @(gen_next_evt);
        end
    endtask

endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual reg_interface reg_vif;
    event mon_next_evt;

    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_evt,
                 virtual reg_interface reg_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.reg_vif = reg_vif;
        this.mon_next_evt = mon_next_evt;
    endfunction

    task run();
        forever begin
            tr = new();
            @(negedge reg_vif.clk);  //여기서 negede쓴게 중요
            gen2drv_mbox.get(tr);
            reg_vif.reset = 0;
            reg_vif.d = tr.d;
            tr.debug_ptint("DRV - AFTER POSEDGE");
            ->mon_next_evt;
        end
    endtask

    task reset();
        reg_vif.reset = 1;
        @(posedge reg_vif.clk);
        @(posedge reg_vif.clk);
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual reg_interface reg_vif;
    event mon_next_evt;

    function new(mailbox#(transaction) mon2scb_mbox, event mon_next_evt,
                 virtual reg_interface reg_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.mon_next_evt = mon_next_evt;
        this.reg_vif = reg_vif;
    endfunction

    task run();
        forever begin
            tr = new;
            @(mon_next_evt);
            @(posedge reg_vif.clk);
            tr.reset = reg_vif.reset;
            tr.d = reg_vif.d;
            tr.q = reg_vif.q;
            tr.debug_ptint("MON - AFTER POSEDGE");
            mon2scb_mbox.put(tr);
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

    int pass_cnt = 0, fail_cnt = 0;
    logic [7:0] expected_q;
    bit first_flag = 1;
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_ptint("SCB");

            if (first_flag) begin
                first_flag = 0;
            end else if (expected_q == tr.q) begin
                $display("pass");
                pass_cnt++;
            end else begin
                $display("fail");
                fail_cnt++;
            end

            expected_q = tr.d;

            ->gen_next_evt;
        end
    endtask
endclass

class enviroment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboad scb;
    // virtual reg_interface reg_vif;   //클래스내부에 선언은 필요없음 와이?
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_evt;
    event mon_next_evt;

    function new(virtual reg_interface reg_vif);
        // this.reg_vif=reg_vif;
        mon2scb_mbox = new;
        gen2drv_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, mon_next_evt, reg_vif);
        mon = new(mon2scb_mbox, mon_next_evt, reg_vif);
        scb = new(mon2scb_mbox, gen_next_evt);
    endfunction

    task run(int run_cnt);
        drv.reset();
        fork
            gen.run(run_cnt);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;

        $display("%t : end register 8bit verification program", $time);
        $display("**************************************************");
        $display("*******  register 8bit verification test *********");
        $display("**************************************************");
        $display("**          pass count : %d            **", scb.pass_cnt);
        $display("**          fail count : %d            **", scb.fail_cnt);
        $display("**************************************************");
    endtask
endclass

module tb_egister8 ();
    logic clk;
    reg_interface reg_if (clk);
    enviroment env;


    register8 DUT (
        .clk(clk),
        .reset(reg_if.reset),
        .d(reg_if.d),
        .q(reg_if.q)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(reg_if);
        env.run(20);

        $finish;
    end

endmodule
