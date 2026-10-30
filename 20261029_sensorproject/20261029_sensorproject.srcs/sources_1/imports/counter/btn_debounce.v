`timescale 1ns / 1ps


module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);

    reg [7:0] q_reg;
    wire debounce;  //debounced signal
    reg edge_reg;

    // 100Mhz -> 10khz clk divider
    parameter F_COUNT = 10_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg clk_1mhz;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            clk_1mhz  <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            
            if (counter_reg == (F_COUNT - 1)) begin
                counter_reg <= 0;
                clk_1mhz <= 1;
            end else clk_1mhz <= 0;
        end
    end


    // 8bit shift register : SIOP
    always @(posedge clk_1mhz, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h00;
        end else begin
            q_reg <= {i_btn, q_reg[7:1]};  //right shift, msb = in, lsb = [7:1]
        end
    end

    //8input AND gate
    assign debounce = &q_reg;

    // edge detection - 디바운스신호와 그신호의 f/f 츨력을 반전한값을 and
    always @(posedge clk, posedge reset) begin
        if (reset) edge_reg <= 0;
        else begin
            edge_reg <= debounce;
        end
    end

    // rising edge , tick gen
    assign o_btn = ~edge_reg & debounce;


endmodule
