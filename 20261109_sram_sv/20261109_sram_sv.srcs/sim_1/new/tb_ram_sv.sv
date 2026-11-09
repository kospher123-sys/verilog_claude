`timescale 1ns / 1ps
interface ram_inreface (
    input clk
);
    logic [5:0] addr;
    logic [7:0] wdata;
    logic       we;
    logic [7:0] rdata;
endinterface

class transaction;
    rand bit [5:0] addr;
    rand bit [7:0] wdata;
    rand bit       we;
    logic    [7:0] rdata;

    function debug_print(string name);
        $display("%t [%s] : addr = %d, wdata = %d, we = %d, rdata = %d", $time,
                 name, addr, wdata, we, rdata);
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
            gen2drv_mbox.put(tr);
            tr.debug_print("GEN");
            @(gen_next_evt);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual ram_inreface ram_vif;
    event mon_next_evt;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual ram_inreface ram_vif, event mon_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.ram_vif      = ram_vif;
        this.mon_next_evt = mon_next_evt;
    endfunction

    task run();
        forever begin
            @(negedge ram_vif.clk);
            gen2drv_mbox.get(tr);
            ram_vif.addr  = tr.addr;
            ram_vif.wdata = tr.wdata;
            ram_vif.we    = tr.we;
            tr.debug_print("DRV");
            ->>mon_next_evt;
        end
    endtask
endclass

class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual ram_inreface ram_vif;
    event mon_next_evt;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual ram_inreface ram_vif, event mon_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.ram_vif = ram_vif;
        this.mon_next_evt = mon_next_evt;
    endfunction

    task run();
        forever begin
            wait(mon_next_evt.triggered);
            @(posedge ram_vif.clk);
            tr       = new;
            tr.addr  = ram_vif.addr;
            tr.wdata = ram_vif.wdata;
            tr.we    = ram_vif.we;
            tr.rdata = ram_vif.rdata;
            mon2scb_mbox.put(tr);
            tr.debug_print("MON");
        end
    endtask
endclass

class scorboad;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_evt;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_evt = gen_next_evt;
    endfunction

    logic [7:0] expected_buf[0:63];
    int pass_cnt=0, fail_cnt=0, total_cnt=0;
    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.debug_print("SCB");
            total_cnt++;
            if (tr.we)begin
                // store for expected buffer
                expected_buf[tr.addr] = tr.wdata;
            end else begin
                if (expected_buf[tr.addr] === tr.rdata) begin
                    $display("expected = %d", expected_buf[tr.addr]);
                    $display("pass");
                    pass_cnt ++;
                end else begin
                    $display("fail");
                    $display("expected = %d", expected_buf[tr.addr]);
                    fail_cnt ++;
                end
            end
            -> gen_next_evt;
        end
    endtask

    task report();
        $display("***********************************");
        $display("** ram size 64 write / read test **");
        $display("**       total test = %4d       **", total_cnt);
        $display("***********************************");
        $display("**       pass  test = %4d       **", pass_cnt);
        $display("**       fail  test = %4d       **", fail_cnt);
        $display("***********************************");
        $display("**   end ram write / read test   **");
        $display("***********************************");
    endtask
endclass

class enviroment;   // enviroment 에서는 클래스 내부 인터페이스 없음 / 메일 박스 객체생성 해줘야함
    generator gen;
    driver drv;
    monitor mon;
    scorboad scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_evt;
    event mon_next_evt;

    function new(virtual ram_inreface ram_vif);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, ram_vif, mon_next_evt);
        mon = new(mon2scb_mbox, ram_vif, mon_next_evt);
        scb = new(mon2scb_mbox, gen_next_evt);

    endfunction

    task run(int gen_cnt);
        fork
            gen.run(gen_cnt);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        scb.report();
    endtask


endclass

module tb_ram_sv ();
    logic clk = 0;
    ram_inreface ram_if (clk);
    enviroment env;

    ram_ip_sv DUT (
        .clk(clk),
        .addr(ram_if.addr),
        .wdata(ram_if.wdata),
        .we(ram_if.we),
        .rdata(ram_if.rdata)
    );

    always #5 clk = ~clk;

    initial begin
        env = new(ram_if);
        env.run(200);


        $finish;
    end
endmodule
