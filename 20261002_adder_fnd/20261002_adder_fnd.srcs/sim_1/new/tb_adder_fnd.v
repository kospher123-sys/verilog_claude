`timescale 1ns / 1ps


module tb_adder_fnd ();

    reg [7:0] a, b;
    reg  [1:0] ds_sel;
    wire [7:0] fnd_font;
    wire [3:0] fnd_com;
    integer i, j, k;

    adder_fnd UDT(
        .a(a), .b(b), .ds_sel(ds_sel), .fnd_font(fnd_font), .fnd_com(fnd_com)
    );

    initial begin
        for (i = 0; i < 255; i = i + 1) begin
            for (j = 0; j < 255; j = j + 1) begin
                for (k = 0; k < 4; k = k + 1) begin
                    a = i;
                    b = j;
                    ds_sel = k;
                    #10;
                end
            end
        end
        $finish;
    end


endmodule
