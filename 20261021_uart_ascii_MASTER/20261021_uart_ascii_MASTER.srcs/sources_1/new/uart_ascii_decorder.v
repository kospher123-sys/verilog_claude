`timescale 1ns / 1ps


module uart_ascii_decorder (
    input clk,
    input rst,
    input rx,
    output tx,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);


    wire w_rx_done;
    wire [7:0] w_rx_data;
    wire [3:0] w_bin;

    uart U_UART (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .rx_done(w_rx_done),
        .rx_data(w_rx_data)
    );

    ascii_decorder U_ASCII_DECORDER (
        .clk(clk),
        .rst(rst),
        .enable(w_rx_done),
        .ascii(w_rx_data),
        .bin(w_bin)
    );

    fnd_controller U_FND_CONTROLLER (
        .clk(clk),
        .reset(rst),
        .fnd_data(w_bin),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

endmodule


module ascii_decorder (
    input clk,
    input rst,
    input enable,
    input [7:0] ascii,
    output reg [3:0] bin
);

    reg [7:0] data_reg, data_next;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            data_reg <= 0;
        end else begin
            data_reg <= data_next;
        end
    end

    always @(*) begin
        data_next = data_reg;
        if (enable) begin
            data_next = ascii;
        end 
            case (data_reg)
                8'h30: bin = 4'h0;
                8'h31: bin = 4'h1;
                8'h32: bin = 4'h2;
                8'h33: bin = 4'h3;
                8'h34: bin = 4'h4;
                8'h35: bin = 4'h5;
                8'h36: bin = 4'h6;
                8'h37: bin = 4'h7;
                8'h38: bin = 4'h8;
                8'h39: bin = 4'h9;
                8'h41, 8'h61: bin = 4'ha;  //A
                8'h42, 8'h62: bin = 4'hb;  //B
                8'h43, 8'h63: bin = 4'hc;  //C
                8'h44, 8'h64: bin = 4'hd;  //D
                8'h45, 8'h65: bin = 4'he;  //E
                8'h46, 8'h66: bin = 4'hf;  //F       
                default: bin = 4'h0;
            endcase
    end

endmodule
