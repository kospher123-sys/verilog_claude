`timescale 1ns / 1ps


module ram_ip_sv #(
    parameter BIT_WIDTH = 8,
    WIDTH = 64
) (
    input  logic       clk,
    input  logic [5:0] addr,
    input  logic [7:0] wdata,
    input  logic       we,
    output logic [7:0] rdata
);

    logic [BIT_WIDTH -1:0] ram[0:WIDTH-1];

    always_ff @(posedge clk) begin
        if (we) begin
            ram[addr] <= wdata;
        end
    end

    assign rdata = ram[addr];


endmodule
