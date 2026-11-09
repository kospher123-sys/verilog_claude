`timescale 1ns / 1ps

interface counter_interface (
    input clk
);
    logic       rst;
    logic       mode;
    logic       run_stop;
    logic       clear;
    logic [7:0] counter;


    property rst_zero;
        @(posedge clk) rst |=> (counter == 8'd0);
    endproperty
    a_rst_zero :
    assert property (rst_zero)
    else begin
        $display("[INTERFACE] rst = %d counter value error %d", rst, counter);
    end

endinterface

class transaction;
    bit            rst;
    rand bit       mode;
    randc bit       run_stop;
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

    static int hold_cnt = 0,hold_cnt_rs = 0;  // 남은 유지 클럭 수 (객체 간 공유)

    constraint mode_hold {(hold_cnt > 0) -> (mode == 1);}
    constraint run_stop_hold {(hold_cnt_rs > 0) -> (run_stop == 1);}

    function void post_randomize();  // randomize() 직후 자동 호출
        if (hold_cnt > 0) hold_cnt--;
        else if (mode) hold_cnt = 2;  // 이번 1 + 이후 2번 = 3클럭
        if (hold_cnt_rs > 0) hold_cnt_rs--;
        else if (run_stop) hold_cnt_rs = 2; 
    endfunction

    constraint clear_dist{
        clear dist{
             0:/9,
             1:/1
        };
    }



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
            assert (tr.randomize())
            else $display("[GEN] tr.randomized error !!!!");
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
    int
        clear_pass = 0,
        clear_fail = 0,
        mode0_pass = 0,
        mode0_fail = 0,
        mode1_pass = 0,
        mode1_fail = 0,
        stop_pass = 0,
        stop_fail = 0;
    task run();
        forever begin
            tr = new;
            mon2scb_mbox.get(tr);

            tr.debug_ptint("SCB");

            total_cnt++;
            if (!(tr.rst || tr.clear)) begin  // clear 아닐떄
                if (tr.run_stop) begin  //동작중
                    if (!tr.mode) begin  // ++ 덩작 
                        expected_count++;
                        if (expected_count === tr.counter) begin  //pass판단 
                            $display("%t : mode0 PASS", $time);
                            mode0_pass++;
                        end else begin
                            $display("%t : mode0 fail", $time);
                            mode0_fail++;
                        end

                    end else begin  //--동작
                        expected_count--;
                        if (expected_count === tr.counter) begin  //pass판단 
                            $display("%t : mode1 PASS", $time);
                            mode1_pass++;
                        end else begin
                            $display("%t : mode1 fail", $time);
                            mode1_fail++;
                        end
                    end
                end else begin  //동작 X
                    if (expected_count === tr.counter) begin  //pass판단 
                        $display("%t : stop PASS", $time);
                        stop_pass++;
                    end else begin
                        $display("%t : stop fail", $time);
                        stop_fail++;
                    end
                    expected_count = expected_count;
                end
            end else begin  // clear
                expected_count = 0;
                if (expected_count === tr.counter) begin  //pass판단 
                    $display("%t : clear PASS", $time);
                    clear_pass++;
                end else begin
                    $display("%t : clear fail", $time);
                    clear_fail++;
                end
            end
        end
    endtask

    task report();
        pass_cnt = mode0_pass + mode1_pass + clear_pass + stop_pass;
        fail_cnt = mode0_fail + mode1_fail + clear_fail + stop_fail;
        $display("***********************************");
        $display("***** counter 256 test progeam*****");
        $display("**       total test = %4d       **", total_cnt);
        $display("**   mode0    pass  test = %4d  **", mode0_pass);
        $display("**   mode0    fail  test = %4d  **", mode0_fail);
        $display("***********************************");
        $display("**   mode1    pass  test = %4d  **", mode1_pass);
        $display("**   mode1    fail  test = %4d  **", mode1_fail);
        $display("***********************************");
        $display("**   clear    pass  test = %4d  **", clear_pass);
        $display("**   clear    fail  test = %4d  **", clear_fail);
        $display("***********************************");
        $display("**   stop     pass  test = %4d  **", stop_pass);
        $display("**   stop     fail  test = %4d  **", stop_fail);
        $display("***********************************");
        $display("**   total    pass  test = %4d  **", pass_cnt);
        $display("**   total    fail  test = %4d  **", fail_cnt);
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
