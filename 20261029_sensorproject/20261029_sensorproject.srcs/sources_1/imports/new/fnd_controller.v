`timescale 1ns / 1ps

module fnd_controller #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input        clk,
    input        rst,
    input        sw_dsiplay_mode,
    input  [7:0] msec,
    input  [7:0] sec,
    input  [7:0] min,
    input  [7:0] hour,
    input  [1:0] setting_state,
    input        setting,          // switch
    input  [3:0] mode,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);


    wire [2:0] w_ds_sel;
    wire w_clk_800hz;
    //msec,sec,min,hour
    wire [3:0] w_mux_out, w_msec_sec_mux_out, w_min_hour_mux_out;
    wire [3:0] w_msec_ds1, w_msec_ds10;
    wire [3:0] w_sec_ds1, w_sec_ds10;
    wire [3:0] w_min_ds1, w_min_ds10;
    wire [3:0] w_hour_ds1, w_hour_ds10;
    wire w_dot_onoff;

    wire [3:0] o_msec_ds1;
    wire [3:0] o_msec_ds10;
    wire [3:0] o_sec_ds1;
    wire [3:0] o_sec_ds10;
    wire [3:0] o_min_ds1;
    wire [3:0] o_min_ds10;
    wire [3:0] o_hour_ds1;
    wire [3:0] o_hour_ds10;
    wire w_half_sec;

    // fnd_controller 안 (sec, hour 쪽 splitter 대신)
    wire raw = (mode == 4'b0010) | (mode == 4'b0001);
    assign w_sec_ds1  = raw ? sec[3:0]  : sec % 10;
    assign w_sec_ds10 = raw ? sec[7:4]  : (sec / 10) % 10;
    assign w_hour_ds1  = raw ? hour[3:0]  : hour % 10;
    assign w_hour_ds10 = raw ? hour[7:4]  : (hour / 10) % 10;

    clk_div_800hz U_CLK_DIV_800HZ (
        .clk(clk),
        .reset(rst),
        .o_clk_800hz(w_clk_800hz)
    );

    counter_8 U_COUNTER_4 (
        .clk(w_clk_800hz),
        .reset(rst),
        .ds_sel(w_ds_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .ds_sel (w_ds_sel[1:0]),
        .fnd_com(fnd_com)
    );


    // msec ds
    digit_splitter_fnd U_MSEC_DIRIT_SPLITTER (
        .dsin(msec),
        .ds1 (w_msec_ds1),
        .ds10(w_msec_ds10)
    );

    // //sec ds
    // digit_splitter_fnd U_SEC_DIRIT_SPLITTER (
    //     .dsin(sec),
    //     .ds1 (w_sec_ds1),
    //     .ds10(w_sec_ds10)
    // );

    //min ds
    digit_splitter_fnd U_MIN_DIRIT_SPLITTER (
        .dsin(min),
        .ds1 (w_min_ds1),
        .ds10(w_min_ds10)
    );

    // //hour ds
    // digit_splitter_fnd U_HOUR_DIRIT_SPLITTER (
    //     .dsin(hour),
    //     .ds1 (w_hour_ds1),
    //     .ds10(w_hour_ds10)
    // );


    dot_comparator U_DOT_COMP (
        .msec     (msec),
        .dot_onoff(w_dot_onoff)
    );


    counter_halfsec U_COUNTER_HALFSEC (
        .clk(clk),
        .rst(rst),
        .half_sec(w_half_sec)
    );

    mux_4x4 U_MUX_4x4 (
        .sel(w_half_sec),
        .setting(setting),
        .setting_state(setting_state),
        .mode(mode),
        .in0(w_msec_ds1),
        .in1(w_msec_ds10),
        .in2(w_sec_ds1),
        .in3(w_sec_ds10),
        .in4(w_min_ds1),
        .in5(w_min_ds10),
        .in6(w_hour_ds1),
        .in7(w_hour_ds10),
        .out0(o_msec_ds1),
        .out1(o_msec_ds10),
        .out2(o_sec_ds1),
        .out3(o_sec_ds10),
        .out4(o_min_ds1),
        .out5(o_min_ds10),
        .out6(o_hour_ds1),
        .out7(o_hour_ds10)
    );

    mux_8x1 U_MSEC_SEC_MUX_8x1 (
        .sel(w_ds_sel),
        .in0(o_msec_ds1),
        .in1(o_msec_ds10),
        .in2(o_sec_ds1),
        .in3(o_sec_ds10),
        .in4(4'hf),
        .in5(4'hf),
        .in6({3'b111, w_dot_onoff}),
        .in7(4'hf),
        .mux_out(w_msec_sec_mux_out)
    );

    mux_8x1 U_MIN_HOUR_MUX_8x1 (
        .sel(w_ds_sel),
        .in0(o_min_ds1),
        .in1(o_min_ds10),
        .in2(o_hour_ds1),
        .in3(o_hour_ds10),
        .in4(4'hf),
        .in5(4'hf),
        .in6({3'b111, w_dot_onoff}),
        .in7(4'hf),
        .mux_out(w_min_hour_mux_out)
    );

    mux_2x1 U_MUX_DISPLAY_MODE (
        .sel(sw_dsiplay_mode),
        .in0(w_msec_sec_mux_out),
        .in1(w_min_hour_mux_out),
        .mux_out(w_mux_out)
    );


    BCD U_BCD (
        .bin(w_mux_out),
        .fnd_font(fnd_font)
    );


endmodule

// 100Mhz -> 3.33Hz
module counter_halfsec (
    input clk,
    input rst,
    output reg half_sec
);
    parameter F_COUNT = 30_000_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            half_sec <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            half_sec <= 1;
            if (counter_reg > (F_COUNT / 2) && counter_reg < F_COUNT) begin
                half_sec <= 0;
                if (counter_reg > F_COUNT) counter_reg <= 0;
            end
        end
    end

endmodule

module mux_4x4 (
    input            sel,
    input            setting,
    input      [1:0] setting_state,
    input      [3:0] in0,
    input      [3:0] in1,
    input      [3:0] in2,
    input      [3:0] in3,
    input      [3:0] in4,
    input      [3:0] in5,
    input      [3:0] in6,
    input      [3:0] in7,
    input      [3:0] mode,
    output reg [3:0] out0,
    output reg [3:0] out1,
    output reg [3:0] out2,
    output reg [3:0] out3,
    output reg [3:0] out4,
    output reg [3:0] out5,
    output reg [3:0] out6,
    output reg [3:0] out7
);
    parameter _1 = 2'b00, _10 = 2'b01, _100 = 2'b10, _1000 = 2'b11;

    always @(*) begin
        if (setting && mode == 4'b1000) begin
            case (setting_state)
                _1: begin
                    if (sel) begin
                        out0 = 4'hf;
                        out1 = 4'hf;
                        out2 = in2;
                        out3 = in3;
                        out4 = in4;
                        out5 = in5;
                        out6 = in6;
                        out7 = in7;
                    end else begin
                        out0 = in0;
                        out1 = in1;
                        out2 = in2;
                        out3 = in3;
                        out4 = in4;
                        out5 = in5;
                        out6 = in6;
                        out7 = in7;
                    end
                end
                _10: begin
                    if (sel) begin
                        out0 = in0;
                        out1 = in1;
                        out2 = 4'hf;
                        out3 = 4'hf;
                        out4 = in4;
                        out5 = in5;
                        out6 = in6;
                        out7 = in7;
                    end else begin
                        out0 = in0;
                        out1 = in1;
                        out2 = in2;
                        out3 = in3;
                        out4 = in4;
                        out5 = in5;
                        out6 = in6;
                        out7 = in7;
                    end
                end
                _100: begin
                    if (sel) begin
                        out0 = in0;
                        out1 = in1;
                        out2 = in2;
                        out3 = in3;
                        out4 = 4'hf;
                        out5 = 4'hf;
                        out6 = in6;
                        out7 = in7;
                    end else begin
                        out0 = in0;
                        out1 = in1;
                        out2 = in2;
                        out3 = in3;
                        out4 = in4;
                        out5 = in5;
                        out6 = in6;
                        out7 = in7;
                    end
                end
                _1000: begin
                    if (sel) begin
                        out0 = in0;
                        out1 = in1;
                        out2 = in2;
                        out3 = in3;
                        out4 = in4;
                        out5 = in5;
                        out6 = 4'hf;
                        out7 = 4'hf;
                    end else begin
                        out0 = in0;
                        out1 = in1;
                        out2 = in2;
                        out3 = in3;
                        out4 = in4;
                        out5 = in5;
                        out6 = in6;
                        out7 = in7;
                    end
                end
                default: begin
                    out0 = in0;
                    out1 = in1;
                    out2 = in2;
                    out3 = in3;
                    out4 = in4;
                    out5 = in5;
                    out6 = in6;
                    out7 = in7;
                end
            endcase
        end else begin
            out0 = in0;
            out1 = in1;
            out2 = in2;
            out3 = in3;
            out4 = in4;
            out5 = in5;
            out6 = in6;
            out7 = in7;
        end
    end

endmodule

module dot_comparator (
    input  [6:0] msec,
    output       dot_onoff
);

    assign dot_onoff = (msec >= 50) ? 1 : 0;


endmodule

module mux_2x1 (
    input        sel,
    input  [3:0] in0,
    input  [3:0] in1,
    output [3:0] mux_out
);
    assign mux_out = (sel) ? in1 : in0;
endmodule

module clk_div_800hz (
    input clk,
    input reset,
    output reg o_clk_800hz
);

    reg [15:0] counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 16'b0;
            o_clk_800hz <= 1'b0;

        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == (62_500 - 1)) begin
                counter_reg <= 16'b0;
                o_clk_800hz <= ~o_clk_800hz;
            end

        end
    end

endmodule


module counter_8 (
    input clk,
    input reset,
    output [2:0] ds_sel
);

    reg [2:0] counter_reg;

    assign ds_sel = counter_reg;

    always @(posedge clk, posedge reset) begin

        if (reset) begin
            //reset : 1'b01
            counter_reg <= 3'b00;
        end else begin
            //operation
            counter_reg <= counter_reg + 1;

        end
    end


endmodule

module decoder_2x4 (
    input [1:0] ds_sel,
    output reg [3:0] fnd_com
);

    always @(ds_sel) begin
        case (ds_sel)
            2'b00:   fnd_com = 4'b1110;
            2'b01:   fnd_com = 4'b1101;
            2'b10:   fnd_com = 4'b1011;
            2'b11:   fnd_com = 4'b0111;
            default: fnd_com = 4'b1111;
        endcase
    end

endmodule


module digit_splitter_fnd (
    input  [7:0] dsin,
    output [3:0] ds1,
    output [3:0] ds10
);

    assign ds1  = dsin % 10;
    assign ds10 = (dsin / 10) % 10;


endmodule



module mux_8x1 (
    input [2:0] sel,
    input [3:0] in0,
    input [3:0] in1,
    input [3:0] in2,
    input [3:0] in3,
    input [3:0] in4,
    input [3:0] in5,
    input [3:0] in6,
    input [3:0] in7,
    output reg [3:0] mux_out
);

    always @(*) begin  // * : all nput sesitivity list
        case (sel)
            3'b000:  mux_out = in0;
            3'b001:  mux_out = in1;
            3'b010:  mux_out = in2;
            3'b011:  mux_out = in3;
            3'b100:  mux_out = in4;
            3'b101:  mux_out = in5;
            3'b110:  mux_out = in6;
            3'b111:  mux_out = in7;
            default: mux_out = in0;
        endcase
    end

endmodule

module BCD (
    input [3:0] bin,
    output reg [7:0] fnd_font   // always 구문에 출력으로 사용할 수 있도록 reg타입으로 선언
);

    always @(bin) begin
        case (bin)
            4'b0000: fnd_font = 8'hc0;
            4'b0001: fnd_font = 8'hf9;
            4'b0010: fnd_font = 8'ha4;
            4'b0011: fnd_font = 8'hb0;
            4'b0100: fnd_font = 8'h99;
            4'b0101: fnd_font = 8'h92;
            4'b0110: fnd_font = 8'h82;
            4'b0111: fnd_font = 8'hf8;
            4'b1000: fnd_font = 8'h80;
            4'b1001: fnd_font = 8'h90;
            4'b1010: fnd_font = 8'h88;
            4'b1011: fnd_font = 8'h89;  //H
            4'b1100: fnd_font = 8'h87;  //t
            4'b1101: fnd_font = 8'ha1;  //d
            4'b1110: fnd_font = 8'h7f;  //e -> dot display
            4'b1111: fnd_font = 8'hff;  //f -> off display
            default: fnd_font = 8'hff;
        endcase
    end

endmodule
