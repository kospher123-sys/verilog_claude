`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////

interface adder_interface ();
    logic [7:0] a;
    logic [7:0] b;
    logic       mode;
    logic [7:0] s;
    logic       c;
endinterface

class transaction;
    // drive vaiable
    rand bit [7:0] a;
    rand bit [7:0] b;
    rand bit       mode;
    //monitor variable
    logic    [7:0] s;
    logic          c;

    constraint adder_limit {
        a > 128;
        b < 64;
    }
    constraint adder_inside {
        a inside {[128:200]};
        b inside{20,30,40,50,10};
    }
    constraint adder_distribute{
        mode dist {
            0: /80,
            1: /20
        };
    }

    function debug_ptint(string name);
        $display("%t : [%s] a = %d, b = %d, mode = %d, s = %d, c = %d", $stime,
                 name, a, b, mode, s, c);
    endfunction
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;

    function new(mailbox#(transaction) gen2drv_mbox_a);
        gen2drv_mbox = gen2drv_mbox_a;
    endfunction

    task run();
        begin
            tr = new;
            tr.randomize();
            tr.debug_ptint("GEN");
            gen2drv_mbox.put(tr);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual adder_interface ADDER_IF_v;
    event drv2mon_evt;

    function new(mailbox#(transaction) gen2drv_mbox, event drv2mon_evt,
                 virtual adder_interface ADDER_IF_v);
        this.gen2drv_mbox = gen2drv_mbox;
        this.ADDER_IF_v   = ADDER_IF_v;
        this.drv2mon_evt  = drv2mon_evt;
    endfunction

    task run();
        begin
            gen2drv_mbox.get(tr);
            tr.debug_ptint("DRV");

            ADDER_IF_v.a = tr.a;
            ADDER_IF_v.b = tr.b;
            ADDER_IF_v.mode = tr.mode;
            #10;
            ->drv2mon_evt;
        end
    endtask
endclass

class monitor;
    transaction tr;
    virtual adder_interface ADDER_IF_v;
    mailbox #(transaction) mon2scb_mbox;
    event drv2mon_evt;

    function new(mailbox#(transaction) mon2scb_mbox, event drv2mon_evt,
                 virtual adder_interface ADDER_IF_v);
        this.mon2scb_mbox = mon2scb_mbox;
        this.ADDER_IF_v = ADDER_IF_v;  // 이 클래스의 ADDER_IF_v = 아규먼트 ADDER_IF_v
        this.drv2mon_evt = drv2mon_evt;
    endfunction

    task run();
        begin
            //wait event
            // @(drv2mon_evt);  //wait(drv2mon_evt); 도 가능 
            //generatoe transaction
            tr = new;
            tr.a = ADDER_IF_v.a;
            tr.b = ADDER_IF_v.b;
            tr.mode = ADDER_IF_v.mode;
            tr.s = ADDER_IF_v.s;
            tr.c = ADDER_IF_v.c;
            tr.debug_ptint("MON");

            mon2scb_mbox.put(tr);
        end
    endtask
endclass

class scoreboad;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction

    bit [7:0] expected_s;
    bit expected_c;
    int fail_cnt=0,pass_cnt =0;
    task run();
        // tr = new;  // 지우면 monitor에서 만든 tr핸들러 객체를 그대로사용
        mon2scb_mbox.get(tr);

        {expected_c, expected_s} = (tr.mode) ? tr.a - tr.b : tr.a + tr.b;

        if ({expected_c, expected_s} == {tr.c,tr.s})begin
            $display("pass");
            pass_cnt++;
        end else begin
            $display("fail");
            fail_cnt++;
        end
            tr.debug_ptint("SCB");
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboad scb;
    mailbox #(transaction) gen2drv_mbox, mon2scb_mbox;
    event drv2mon_evt;

    function new(virtual adder_interface ADDER_IF_v);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox);
        drv = new(gen2drv_mbox, drv2mon_evt, ADDER_IF_v);
        mon = new(mon2scb_mbox, drv2mon_evt, ADDER_IF_v);
        scb = new(mon2scb_mbox);
    endfunction

    task run(int run_count);
        repeat (run_count) begin
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        end

        $display("pass count = %d", scb.pass_cnt);
        $display("fail count = %d", scb.fail_cnt);
    endtask
endclass


module tb_adder_sv ();

    adder_interface ADDER_IF ();
    environment env;

    adder DUT (
        .a   (ADDER_IF.a),
        .b   (ADDER_IF.b),
        .mode(ADDER_IF.mode),
        .s   (ADDER_IF.s),
        .c   (ADDER_IF.c)
    );

    initial begin
        env = new(ADDER_IF);
        env.run(20);
        $stop;
    end


endmodule
