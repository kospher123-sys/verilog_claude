`timescale 1ns / 1ps
module bram_ip (
    input            clk,
    input            we,
    input      [7:0] addr,
    input      [7:0] wdata,
    // output reg [7:0] rdata_sl,
    output [7:0] rdata
);

    reg [7:0] ram[0:255];  //주소 8비트 256개  + 데이터 8비트

    always @(posedge clk) begin
        if (we) begin
            ram[addr] <= wdata;
        end 
        else begin
            // rdata <= ram[addr];
        end
    end

    assign rdata = ram[addr];

endmodule
