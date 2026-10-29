`timescale 1ns / 1ps

module tb_ram ();

    reg        clk;
    reg        we;
    reg  [7:0] addr;
    reg  [7:0] wdata;
    wire [7:0] rdata_sl;
    wire [7:0] rdata;

    bram_ip DUT (
        .clk(clk),
        .we(we),
        .addr(addr),
        .wdata(wdata),
        // .rdata_sl(rdata_sl),
        .rdata(rdata)
    );

    always #5 clk = ~clk;


    initial begin
        clk   = 0;
        we    = 0;
        addr  = 0;
        wdata = 0;

        @(negedge clk);
        we    = 1;
        addr  = 10;
        wdata = 8'h0a;
        @(negedge clk);
        addr  = 11;
        wdata = 8'h0b;
        @(negedge clk);
        addr  = 31;
        wdata = 8'h0c;
        @(negedge clk);
        addr  = 32;
        wdata = 8'h0d;

        @(negedge clk);
        we   = 0;
        @(negedge clk);
        addr = 10;
        @(negedge clk);
        addr = 11;
        @(negedge clk);
        addr = 31;
        @(negedge clk);
        addr = 32;
        @(negedge clk);

        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        $stop;

    end

    // initial begin
    //     clk   = 0;
    //     we    = 0;
    //     addr  = 0;
    //     wdata = 0;

    //     @(posedge clk);
    //     we    = 1;
    //     addr  = 10;
    //     wdata = 8'h0a;
    //     @(posedge clk);
    //     addr  = 11;
    //     wdata = 8'h0b;
    //     @(posedge clk);
    //     addr  = 31;
    //     wdata = 8'h0c;
    //     @(posedge clk);
    //     addr  = 32;
    //     wdata = 8'h0d;

    //     @(posedge clk);
    //     we   = 0;
    //     @(posedge clk);
    //     addr = 10;
    //     @(posedge clk);
    //     addr = 11;
    //     @(posedge clk);
    //     addr = 31;
    //     @(posedge clk);
    //     addr = 32;

    //     #100;
    //     $stop;

    // end


endmodule
