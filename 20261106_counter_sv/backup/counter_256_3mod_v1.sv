`timescale 1ns / 1ps


module counter_256 (
    input  logic       clk,
    input  logic       rst,
    input  logic       mode,    //sw
    input  logic       run_stop,    //sw
    input  logic       clear,   //sw
    output logic [7:0] counter
);

    always_ff @(posedge clk, posedge rst) begin
        if (rst || clear) begin
            counter <= 0;
        end else if (run_stop) begin
            if (!mode) begin
                counter <= counter + 1;
            end else begin
                counter <= counter - 1;
            end
        end else begin
            counter <= counter;
        end
    end



endmodule
