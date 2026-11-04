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
        repeat (256) begin
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

    function new(mailbox#(transaction) gen2drv_mbox_a,
                 virtual adder_interface ADDER_IF_v_a);
        gen2drv_mbox = gen2drv_mbox_a;
        ADDER_IF_v   = ADDER_IF_v_a;
    endfunction

    task run();
        forever begin
            gen2drv_mbox.get(tr);  
            tr.debug_ptint("DRV");

            ADDER_IF_v.a = tr.a;
            ADDER_IF_v.b = tr.b;
            ADDER_IF_v.mode = tr.mode;
            #10;
        end
    endtask
endclass

class environment;
    generator gen;
    driver drv;
    mailbox #(transaction) gen2drv_mbox;

    function new(virtual adder_interface ADDER_IF_v);
        gen2drv_mbox = new;
        gen = new(gen2drv_mbox);
        drv = new(gen2drv_mbox, ADDER_IF_v);
    endfunction

    task run();
        forever begin
            gen.run();
            drv.run();
        end
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
        env.run();
        $stop;
    end


endmodule
