`timescale 1ns / 1ps


module counter_10000 (
    input clk,
    input reset,
    input [2:0] sw,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    wire [13:0] w_counter;

    data_path U_DATA_PATH (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .counter(w_counter)
    );


    fnd_controller U_FND_CONT (
        .clk(clk),
        .reset(reset),
        .fnd_data(w_counter),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

endmodule

module data_path (
    input clk,
    input reset,
    input [2:0] sw,
    output [13:0] counter
);

    wire w_tick;

    tick_gen U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .o_tick(w_tick)
    );

    tick_counter U_TICK_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick),
        .sw(sw),
        .counter(counter)
    );

endmodule


module tick_counter (
    input clk,
    input reset,
    input i_tick,
    input [2:0] sw,
    output [13:0] counter
);

    reg [13:0] counter_reg;
    assign counter = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (sw[1] || reset) begin
            counter_reg <= 0;

        end else begin
                if ( i_tick && sw[0] ) begin // i_tick == 1 && sw[0] == 1
                if (sw[2] == 0) begin
                    if (counter_reg == 9999) begin
                        counter_reg <= 0;
                    end else begin
                        counter_reg <= counter_reg + 1;
                    end
                end else if (sw[2] == 1) begin
                    if (counter_reg == 0) begin
                        counter_reg <= 9999;
                    end else begin
                        counter_reg <= counter_reg - 1;
                    end
                end
            end
        end
    end

endmodule



module tick_gen (
    input  clk,
    input  reset,
    input [2:0] sw,
    output o_tick
);
    parameter F_COUNT = 10_000_000;
    reg tick_reg;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    assign o_tick = tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset || sw[1]) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;

        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (F_COUNT - 1)) begin
                tick_reg <= 1;
                counter_reg <= 0;
            end else begin
                tick_reg <= 0;

            end

        end
    end

endmodule
