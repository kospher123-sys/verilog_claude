`timescale 1ns / 1ps

module ascii_decorder (
    input clk,
    input rst,
    input enable,
    input [7:0] ascii,
    output reg pop,
    output reg run_stop,
    output reg clear,
    output reg mode,
    output reg status
);

    localparam IDLE = 3'b000, r = 3'b001, c = 3'b010, u = 3'b011, s = 3'b100;
    reg [2:0] c_state, n_state;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        n_state = IDLE;
        pop = 1'b0;
        run_stop <= 1'b0;
        clear <= 1'b0;
        mode <= 1'b0;
        status <= 1'b0;
        if (enable) begin
            pop = 1'b1;
            case (ascii)
                8'h52, 8'h72: n_state = r;
                8'h43, 8'h63: n_state = c;
                8'h55, 8'h75: n_state = u;
                8'h53, 8'h73: n_state = s;
            endcase
        end
        case (c_state)
            r: run_stop <= 1'b1;
            c: clear <= 1'b1;
            u: mode <= 1'b1;
            s: status <= 1'b1;
        endcase
    end

endmodule


//     (
//     input clk,
//     input rst,
//     input enable,
//     input [7:0] ascii,
//     output reg pop,
//     output reg [3:0] bin
// );
// reg [7:0] data_reg, data_next;


// always @(posedge clk, posedge rst) begin
//     if (rst) begin
//         data_reg <= 0;
//     end else begin
//         data_reg <= data_next;
//     end
// end

// always @(*) begin
//     data_next = data_reg;
//     pop = 1'b0;
//     if (enable) begin
//         data_next = ascii;
//         pop = 1'b1;
//     end 
//         case (data_reg)
//             8'h30: bin = 4'h0;
//             8'h31: bin = 4'h1;
//             8'h32: bin = 4'h2;
//             8'h33: bin = 4'h3;
//             8'h34: bin = 4'h4;
//             8'h35: bin = 4'h5;
//             8'h36: bin = 4'h6;
//             8'h37: bin = 4'h7;
//             8'h38: bin = 4'h8;
//             8'h39: bin = 4'h9;
//             8'h41, 8'h61: bin = 4'ha;  //A
//             8'h42, 8'h62: bin = 4'hb;  //B
//             8'h43, 8'h63: bin = 4'hc;  //C
//             8'h44, 8'h64: bin = 4'hd;  //D
//             8'h45, 8'h65: bin = 4'he;  //E
//             8'h46, 8'h66: bin = 4'hf;  //F       
//             default: bin = 4'h0;
//         endcase
// end
