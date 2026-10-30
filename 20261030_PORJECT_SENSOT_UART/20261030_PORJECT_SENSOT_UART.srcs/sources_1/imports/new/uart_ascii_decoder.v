`timescale 1ns / 1ps


// module uart_ascii_decoder (
//     input clk,
//     input rst,
//     input rx,
//     output tx,
//     //fnd
//     output [3:0] fnd_com,
//     output [7:0] fnd_font
// );

//     wire w_rx_done;
//     wire [7:0] w_rx_data;
//     wire [3:0] w_bin;

//     uart_fifo_loopback UART_FIFO_LOOPBACK (
//         .clk(clk),
//         .rst(rst),
//         // .rx_done(w_rx_done),
//         // .rx_data(w_rx_data),
//         .rx(rx),  // from PC
//         .tx(tx)  //to pc
//     );

//     ascii_decoder U_ASCII_DECODER (
//         .clk(clk),
//         .rst(rst),
//         .enable(w_rx_done),
//         .ascii(w_rx_data),
//         .bin(w_bin)

//     );
//     fnd_controller FND_CNT (
//         .clk(clk),
//         .rst(rst),
//         .fnd_data(w_bin),
//         .fnd_com(fnd_com),
//         .fnd_font(fnd_font)
//     );





// endmodule

module ascii_decoder (
    input            clk,
    input            rst,
    input            enable,
    input      [7:0] ascii,
    output           run_stop,
    output           clear,
    output           mode,
    output           status,
    output reg [3:0] bin,
    output reg       pop,
    output reg       mode_sel_valid,
    output reg [2:0] mode_sel


);



    reg [7:0] data_reg, data_next;
    reg edge_run_stop_reg, edge_clear_reg, edge_mode_reg, edge_status_reg;

    assign run_stop = edge_run_stop_reg;
    assign clear = edge_clear_reg;
    assign mode = edge_mode_reg;
    assign status = edge_status_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            data_reg <= 0;
        end else begin
            data_reg <= data_next;
        end
    end

    always @(*) begin
        bin = 4'h0;
        pop = 1'b0;
        data_next = data_reg;
        if (enable) begin
            data_next = ascii;
            pop = 1'b1;
        end else begin
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
                8'h41, 8'h61: bin = 4'ha;
                8'h42, 8'h62: bin = 4'hb;
                8'h43, 8'h63: bin = 4'hc;
                8'h44, 8'h64: bin = 4'hd;
                8'h45, 8'h65: bin = 4'he;
                8'h46, 8'h66: bin = 4'hf;

            endcase
        end
    end

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            edge_run_stop_reg <= 1'b0;
            edge_clear_reg    <= 1'b0;
            edge_mode_reg     <= 1'b0;
            edge_status_reg   <= 1'b0;
            mode_sel_valid    <= 1'b0;
            mode_sel          <= 3'b000;
        end else begin
            edge_run_stop_reg <= 1'b0;
            edge_clear_reg <= 1'b0;
            edge_mode_reg <= 1'b0;
            edge_status_reg <= 1'b0;
            mode_sel_valid <= 1'b0;
            if (enable) begin
                case (ascii)
                    8'h52, 8'h72: edge_run_stop_reg <= 1'b1;
                    8'h43, 8'h63: edge_clear_reg <= 1'b1;
                    8'h55, 8'h75: edge_mode_reg <= 1'b1;
                    8'h53, 8'h73: edge_status_reg <= 1'b1;

                    // UART Remote Mode Selection
                    8'h31: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b000;
                    end
                    8'h32: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b001;
                    end
                    8'h33: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b010;
                    end
                    8'h34: begin
                        mode_sel_valid <= 1'b1;
                        mode_sel       <= 3'b011;
                    end
                endcase
            end
        end
    end



endmodule
