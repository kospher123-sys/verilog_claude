`timescale 1ns / 1ps
module btn_debouce_block (
    input  clk,
    input  rst,
    
    input  btnR,
    input  btnL,
    input  btnU,
    input  btnD,

    output btnR_tick,
    output btnL_tick,
    output btnU_tick,
    output btnD_tick
);

    btn_debounce U_BD_R (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(btnR_tick)
    );

    btn_debounce U_BD_L (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnL),
        .o_btn(btnL_tick)
    );

    btn_debounce U_BD_U (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnU),
        .o_btn(btnU_tick)
    );

    btn_debounce U_BD_D (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnD),
        .o_btn(btnD_tick)
    );




endmodule


module btn_or_ascii (
    input clk,
    input rst,

    input btn_R,
    input btn_L,
    input btn_U,
    input btn_D,
    input sw_mode1,
    input sw_mode2,
    input sw_mode3,
    input sw_mode4,

    input ascii_R,
    input ascii_L,
    input ascii_U,
    input ascii_D,
    input ascii_mode1,
    input ascii_mode2,
    input ascii_mode3,
    input ascii_mode4,

    output reg btnR_tick,
    output reg btnL_tick,
    output reg btnU_tick,
    output reg btnD_tick,
    output mode1,
    output mode2,
    output mode3,
    output mode4
);

    wire [3:0] sw_input, ascii_input;
    reg [3:0]mode_reg, mode_next;


    assign sw_input = {sw_mode1, sw_mode2, sw_mode3, sw_mode4};
    assign ascii_input = {ascii_mode1, ascii_mode2, ascii_mode3, ascii_mode4};
    assign mode1 = mode_reg[3];
    assign mode2 = mode_reg[2];
    assign mode3 = mode_reg[1];
    assign mode4 = mode_reg[0];

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            mode_reg <= 0;
        end else begin
            mode_reg <= mode_next;
        end
    end

    always @(*) begin
        btnR_tick  = btn_R | ascii_R;
        btnL_tick  = btn_L | ascii_L;
        btnU_tick  = btn_U | ascii_U;
        btnD_tick  = btn_D | ascii_D;
        mode_next = mode_reg;
        if (sw_input != 0) begin
            case (sw_input)
                4'b1000: mode_next = 4'b1000;
                4'b0100: mode_next = 4'b0100;
                4'b0010: mode_next = 4'b0010;
                4'b0001: mode_next = 4'b0001;
            endcase
        end else begin
            if (ascii_input == 0) begin
                mode_next = 4'b0000;
            end
            case (ascii_input)
                4'b1000: mode_next = 4'b1000;
                4'b0100: mode_next = 4'b0100;
                4'b0010: mode_next = 4'b0010;
                4'b0001: mode_next = 4'b0001;
            endcase
        end
    end


endmodule
