`timescale 1ns / 1ps


module counter_10000 (
    input clk,
    input reset,
    input [2:0] sw,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);

    wire [13:0] w_counter;
    wire w_run_stop, w_clear, w_node;
    wire btnL, btnR;
    

    btn_debounce U_BTNL_DEBOUNCOR(
    .clk(clk),
    .reset(reset),
    .i_btn(sw[2]),
    .o_btn()
    );

    controll_unit_btn U_CONTROL_UNIT (
        .clk(clk),
        .reset(reset),
        .btnR(),      //run
        .btnL(), 
        .sw(sw),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(w_mode)
    );

    data_path U_DATA_PATH (
        .clk(clk),
        .reset(reset),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(w_mode),
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
    input run_stop,
    input clear,
    input mode,
    output [13:0] counter
);

    wire w_tick;

    tick_gen U_TICK_GEN (
        .clk(clk),
        .reset(reset),
        .run_stop(run_stop),
        .clear(clear),
        .o_tick(w_tick)
    );

    tick_counter U_TICK_COUNTER (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick),
        .mode(mode),
        .clear(clear),
        .counter(counter)
    );

endmodule


module tick_counter (
    input clk,
    input reset,
    input i_tick,
    input clear,
    input mode,
    output [13:0] counter
);

    reg [13:0] counter_reg;
    assign counter = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (clear || reset) begin
            counter_reg <= 0;

        end else begin
            if (i_tick) begin  // i_tick == 1 && sw[0] == 1
                if (mode == 0) begin
                    if (counter_reg == 9999) begin
                        counter_reg <= 0;
                    end else begin
                        counter_reg <= counter_reg + 1;
                    end
                end else if (mode == 1) begin
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
    input  run_stop,
    input  clear,
    output o_tick
);
    parameter F_COUNT = 10_000_000;
    reg tick_reg;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    assign o_tick = tick_reg;

    always @(posedge clk, posedge reset) begin
        if (reset || clear) begin
            counter_reg <= 0;
            tick_reg <= 1'b0;

        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == (F_COUNT - 1)) begin
                    tick_reg <= 1;
                    counter_reg <= 0;
                end else begin
                    tick_reg <= 0;

                end
            end

        end
    end

endmodule
