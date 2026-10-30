module baud_tick_gen_dht11 #(
    parameter integer F_COUNT = 100
)(
    input clk,
    input rst,
    input enable,
    input clear,
    output reg b_tick
);

    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 0;
        end
        else if (clear) begin
            counter_reg <= 0;
            b_tick <= 0;
        end
        else if (enable) begin
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                b_tick <= 1;
            end
            else begin
                counter_reg <= counter_reg + 1'b1;
                b_tick <= 0;
            end
        end
        else begin
            counter_reg <= 0;
            b_tick <= 0;
        end
    end

endmodule