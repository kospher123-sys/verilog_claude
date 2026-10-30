
`timescale 1ns / 1ps

module ascii_sender (
    input clk,
    rst,
    input run_stop,
    clear,
    mode,
    status,
    input mode_sel_valid,
    input [2:0] mode_sel,
    input [2:0] sw_mode,
    input [31:0] status_data,
    input periodic_status,
    input full,
    output reg push,
    output reg [7:0] push_data,
    output wire ready
);

    localparam IDLE = 2'd0, CONVERT = 2'd1, SEND = 2'd2;

    reg [1:0] state;
    reg [2:0] saved_mode;
    reg [31:0] saved_data;
    reg is_echo;
    reg [7:0] echo_char;
    reg [5:0] idx;

    reg [8:0] binary_shift;
    reg [11:0] bcd_work, bcd0, bcd1;
    reg [3:0] bit_count;
    reg [1:0] part;

    // Watch / Stopwatch Decimal Data
    reg [7:0] bcd_hour;
    reg [7:0] bcd_min;
    reg [7:0] bcd_sec;
    reg [7:0] bcd_cs;

    assign ready = (state == IDLE);

    // Skip leading zero digits, but preserve the last digit
    wire skip_digit =
        (saved_mode == 3'd2 &&
           ((idx == 6'd11 && bcd0[11:8] == 0) ||
            (idx == 6'd12 && bcd0[11:8] == 0 &&
             bcd0[7:4] == 0))) ||
        (saved_mode == 3'd3 &&
           ((idx == 6'd9 && bcd0[11:8] == 0) ||
            (idx == 6'd10 && bcd0[11:8] == 0 &&
             bcd0[7:4] == 0) ||
            (idx == 6'd28 && bcd1[11:8] == 0) ||
            (idx == 6'd29 && bcd1[11:8] == 0 &&
             bcd1[7:4] == 0)));

    // Double Dabble: Add-3
    function [11:0] add3;
        input [11:0] x;
        reg [11:0] y;
        begin
            y = x;

            if (y[3:0] >= 5) y[3:0] = y[3:0] + 4'd3;

            if (y[7:4] >= 5) y[7:4] = y[7:4] + 4'd3;

            if (y[11:8] >= 5) y[11:8] = y[11:8] + 4'd3;

            add3 = y;
        end
    endfunction

    wire [11:0] adjusted = add3(bcd_work);
    wire [11:0] shifted_bcd = {adjusted[10:0], binary_shift[8]};

    // FSM Sequential Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            saved_mode   <= 0;
            saved_data   <= 0;
            is_echo      <= 0;
            echo_char    <= 0;
            idx          <= 0;
            binary_shift <= 0;
            bcd_work     <= 0;
            bcd0         <= 0;
            bcd1         <= 0;
            bit_count    <= 0;
            part         <= 0;
            bcd_hour     <= 8'd0;
            bcd_min      <= 8'd0;
            bcd_sec      <= 8'd0;
            bcd_cs       <= 8'd0;
        end else begin
            case (state)

                IDLE: begin
                    idx <= 0;

                    if (run_stop || clear || mode || mode_sel_valid) begin

                        is_echo <= 1;

                        if (run_stop) echo_char <= "r";
                        else if (clear) echo_char <= "c";
                        else if (mode) echo_char <= "u";
                        else echo_char <= 8'h31 + {5'b0, mode_sel};

                        state <= SEND;

                    end else if (status || periodic_status) begin
                        is_echo    <= 0;
                        saved_mode <= sw_mode;
                        saved_data <= status_data;

                        bit_count  <= 0;
                        part       <= 0;
                        bcd_work   <= 0;

                        case (sw_mode)

                            // Stopwatch / Watch
                            3'd0, 3'd1: begin
                                binary_shift <= {4'b0000, status_data[23:19]};
                                state <= CONVERT;
                            end

                            // HC-SR04
                            3'd2: begin
                                binary_shift <= status_data[8:0];
                                state <= CONVERT;
                            end

                            // DHT11
                            3'd3: begin
                                binary_shift <= {1'b0, status_data[31:24]};
                                state <= CONVERT;
                            end

                            default: begin
                                state <= SEND;
                            end

                        endcase
                    end
                end

                CONVERT: begin

                    bcd_work <= shifted_bcd;

                    binary_shift <= {binary_shift[7:0], 1'b0};

                    if (bit_count == 4'd8) begin

                        bit_count <= 0;
                        bcd_work  <= 0;

                        // Stopwatch / Watch
                        if (saved_mode == 3'd0 || saved_mode == 3'd1) begin

                            case (part)

                                2'd0: begin
                                    bcd_hour <= shifted_bcd[7:0];
                                    binary_shift <= {3'b000, saved_data[18:13]};
                                    part <= 2'd1;
                                end

                                2'd1: begin
                                    bcd_min <= shifted_bcd[7:0];
                                    binary_shift <= {3'b000, saved_data[12:7]};
                                    part <= 2'd2;
                                end

                                2'd2: begin
                                    bcd_sec <= shifted_bcd[7:0];
                                    binary_shift <= {2'b00, saved_data[6:0]};
                                    part <= 2'd3;
                                end

                                2'd3: begin
                                    bcd_cs <= shifted_bcd[7:0];
                                    state  <= SEND;
                                end

                            endcase

                        end  // HC-SR04 / DHT11
                        else begin

                            if (part == 2'd0) bcd0 <= shifted_bcd;
                            else bcd1 <= shifted_bcd;

                            if (saved_mode == 3'd3 && part == 2'd0) begin

                                part <= 2'd1;
                                binary_shift <= {1'b0, saved_data[15:8]};

                            end else begin
                                state <= SEND;
                            end

                        end

                    end else begin
                        bit_count <= bit_count + 1'b1;
                    end

                end

                SEND: begin
                    if (!is_echo && skip_digit) begin
                        idx <= idx + 1'b1;

                    end else if (!full) begin
                        if ((is_echo && idx == 6'd2) ||
            (!is_echo && saved_mode < 2 && idx == 6'd14) ||
            (!is_echo && saved_mode == 2 && idx == 6'd17) ||
            (!is_echo && saved_mode == 3 && idx == 6'd33) ||
            (!is_echo && saved_mode > 3 && idx == 6'd11)) begin

                            state <= IDLE;
                        end else begin
                            idx <= idx + 1'b1;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    // ASCII Character Generation
    reg [3:0] hex_digit;

    always @(*) begin
        push = 1'b0;
        push_data = 8'h00;
        hex_digit = 0;

        if (state == SEND && !full && (is_echo || !skip_digit)) begin

            push = 1'b1;

            if (is_echo) begin
                case (idx)
                    6'd0: push_data = echo_char;
                    6'd1: push_data = 8'h0D;  // CR
                    6'd2: push_data = 8'h0A;  // LF
                    default: push_data = 8'h00;
                endcase

            end else begin
                case (saved_mode)

                    // Stopwatch / Watch: HH:MM:SS.CC
                    3'd0, 3'd1: begin
                        case (idx)

                            0: push_data = 8'h30 + {5'b0, saved_mode};
                            1: push_data = ":";

                            // Hour
                            2: push_data = 8'h30 + bcd_hour[7:4];
                            3: push_data = 8'h30 + bcd_hour[3:0];

                            4: push_data = ":";

                            // Minute
                            5: push_data = 8'h30 + bcd_min[7:4];
                            6: push_data = 8'h30 + bcd_min[3:0];

                            7: push_data = ":";

                            // Second
                            8: push_data = 8'h30 + bcd_sec[7:4];
                            9: push_data = 8'h30 + bcd_sec[3:0];

                            10: push_data = ".";

                            // Centisecond
                            11: push_data = 8'h30 + bcd_cs[7:4];
                            12: push_data = 8'h30 + bcd_cs[3:0];

                            13: push_data = 8'h0D;
                            14: push_data = 8'h0A;

                            default: push_data = 8'h00;

                        endcase
                    end

                    // HC-SR04: distance : xxcm
                    3'd2: begin
                        case (idx)
                            0:  push_data = "d";
                            1:  push_data = "i";
                            2:  push_data = "s";
                            3:  push_data = "t";
                            4:  push_data = "a";
                            5:  push_data = "n";
                            6:  push_data = "c";
                            7:  push_data = "e";
                            8:  push_data = " ";
                            9:  push_data = ":";
                            10: push_data = " ";
                            11: push_data = 8'h30 + bcd0[11:8];
                            12: push_data = 8'h30 + bcd0[7:4];
                            13: push_data = 8'h30 + bcd0[3:0];
                            14: push_data = "c";
                            15: push_data = "m";
                            16: push_data = 8'h0D;
                            17: push_data = 8'h0A;
                        endcase
                    end

                    // DHT11: humidity and temperature
                    3'd3: begin
                        case (idx)
                            0:  push_data = "h";
                            1:  push_data = "u";
                            2:  push_data = "m";
                            3:  push_data = "i";
                            4:  push_data = "d";
                            5:  push_data = "i";
                            6:  push_data = "t";
                            7:  push_data = "y";
                            8:  push_data = ":";
                            9:  push_data = 8'h30 + bcd0[11:8];
                            10: push_data = 8'h30 + bcd0[7:4];
                            11: push_data = 8'h30 + bcd0[3:0];
                            12: push_data = "%";
                            13: push_data = 8'h0D;
                            14: push_data = 8'h0A;

                            15: push_data = "t";
                            16: push_data = "e";
                            17: push_data = "m";
                            18: push_data = "p";
                            19: push_data = "e";
                            20: push_data = "r";
                            21: push_data = "a";
                            22: push_data = "t";
                            23: push_data = "u";
                            24: push_data = "r";
                            25: push_data = "e";
                            26: push_data = ":";
                            27: push_data = " ";
                            28: push_data = 8'h30 + bcd1[11:8];
                            29: push_data = 8'h30 + bcd1[7:4];
                            30: push_data = 8'h30 + bcd1[3:0];
                            31: push_data = "C";
                            32: push_data = 8'h0D;
                            33: push_data = 8'h0A;
                        endcase
                    end

                    default: begin
                        case (idx)
                            0: push_data = "?";
                            1: push_data = ":";
                            10: push_data = 8'h0D;
                            11: push_data = 8'h0A;
                            default: push_data = "0";
                        endcase
                    end

                endcase
            end
        end
    end

endmodule
