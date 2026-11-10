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
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_evt;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_evt);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_evt = gen_next_evt;
        this.gen2scb_mbox = gen2scb_mbox;
    endfunction

    task run(int gen_cnt);
        repeat (gen_cnt) begin
            tr = new;
            tr.randomize();
            gen2drv_mbox.put(tr);
            gen2scb_mbox.put(tr);
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
            wait (mon_next_evt.triggered);
            @(posedge ram_vif.clk);
            #1;
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
    transaction tr_mon, tr_gen;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_evt;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_evt);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_evt = gen_next_evt;
        this.gen2scb_mbox = gen2scb_mbox;
    endfunction

    int
        total_cnt = 0,
        read_pass = 0,
        read_fail = 0,
        write_pass = 0,
        write_fail = 0;

    logic [7:0] expected_buf[0:63];
    task run();
        forever begin
            mon2scb_mbox.get(tr_mon);
            gen2scb_mbox.get(tr_gen);
            total_cnt++;
            if (tr_mon.we) begin
                // store for expected buffer
                expected_buf[tr_gen.addr] = tr_gen.wdata;
                if (tr_gen.wdata === tr_mon.rdata) begin
                    $display("expected = %d", tr_gen.wdata);
                    $display("write_pass");
                    write_pass++;
                end else begin
                    $display("write_fail");
                    $display("expected = %d", tr_gen.wdata);
                    write_fail++;
                end
            end else begin
                // if (tr.rdata >= 1) begin
                if (expected_buf[tr_gen.addr] === tr_mon.rdata) begin
                    $display("expected = %d", tr_gen.wdata);
                    $display("read_pass");
                    read_pass++;
                end else begin
                    $display("read_fail");
                    $display("expected = %d", tr_gen.wdata);
                    read_fail++;
                end
                // end
            end
            ->gen_next_evt;
        end
    endtask

    task report();
        $display("***********************************");
        $display("** ram size 64 write / read test **");
        $display("**       total test = %4d       **", total_cnt);
        $display("***********************************");
        $display("** read  pass  test = %4d       **", read_pass);
        $display("** read  fail  test = %4d       **", read_fail);
        $display("** write pass  test = %4d       **", write_pass);
        $display("** write fail  test = %4d       **", write_fail);
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
    mailbox #(transaction) gen2scb_mbox;
    event gen_next_evt;
    event mon_next_evt;

    function new(virtual ram_inreface ram_vif);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen2scb_mbox = new;
        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_evt);
        drv = new(gen2drv_mbox, ram_vif, mon_next_evt);
        mon = new(mon2scb_mbox, ram_vif, mon_next_evt);
        scb = new(mon2scb_mbox, gen2scb_mbox, gen_next_evt);

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
