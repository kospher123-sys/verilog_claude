
`timescale 1ns / 1ps

module sensor_fnd_controller (
    input clk,
    input rst,

    input [2:0] sw_mode,
    input sw_display_mode,

    input [8:0] distance,
    input [15:0] humidity,
    input [15:0] temperature,
    input dht_valid,
    input dht_error,

    output reg [3:0] fnd_com,
    output reg [7:0] fnd_font
);

    // ========================================
    // 1. Sensor Data MUX
    // ========================================

    reg [8:0] display_value;
    reg [7:0] prefix_font;
    reg show_wait;
    reg show_error;

    always @(*) begin
        display_value = 9'd0;
        prefix_font   = 8'hFF;
        show_wait     = 1'b0;
        show_error    = 1'b0;

        case (sw_mode)
            3'b010: begin
                // HC-SR04: d + 3-digit distance
                display_value = distance;
                prefix_font = 8'hA1;  // d
            end

            3'b011: begin
                // DHT11
                if (dht_error) begin
                    show_error = 1'b1;
                end
                else if (!dht_valid) begin
                    show_wait = 1'b1;
                end
                else if (sw_display_mode == 1'b0) begin
                    // Humidity integer part
                    display_value = {1'b0, humidity[15:8]};
                    prefix_font = 8'h89;  // H
                end
                else begin
                    // Temperature integer part
                    display_value = {1'b0, temperature[15:8]};
                    prefix_font = 8'h87;  // t
                end
            end

            default: begin
                // No sensor display
            end
        endcase
    end


    // ========================================
    // 2. Decimal Digit Splitter
    // ========================================

    wire [3:0] digit_100;
    wire [3:0] digit_10;
    wire [3:0] digit_1;

    assign digit_100 = display_value / 9'd100;
    assign digit_10  = (display_value % 9'd100) / 9'd10;
    assign digit_1   = display_value % 9'd10;


    // ========================================
    // 3. BCD to 7-Segment
    // ========================================

    wire [7:0] font_100;
    wire [7:0] font_10;
    wire [7:0] font_1;

    bcd U_BCD_100 (
        .bin(digit_100),
        .fnd_font(font_100)
    );

    bcd U_BCD_10 (
        .bin(digit_10),
        .fnd_font(font_10)
    );

    bcd U_BCD_1 (
        .bin(digit_1),
        .fnd_font(font_1)
    );


    // ========================================
    // 4. FND Scan Counter
    // ========================================

    // 100MHz Clock
    // 25,000 cycles / digit = 250us
    // 4 digits = 1ms (1kHz refresh)

    reg [14:0] scan_cnt_reg;
    reg [1:0] digit_sel_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_cnt_reg <= 0;
            digit_sel_reg <= 0;
        end
        else begin
            if (scan_cnt_reg == 15'd24999) begin
                scan_cnt_reg <= 0;
                digit_sel_reg <= digit_sel_reg + 1'b1;
            end
            else begin
                scan_cnt_reg <= scan_cnt_reg + 1'b1;
            end
        end
    end


    // ========================================
    // 5. FND Digit MUX
    // ========================================

    always @(*) begin
        fnd_com  = 4'b1111;
        fnd_font = 8'hFF;

        if ((sw_mode == 3'b010) ||
            (sw_mode == 3'b011)) begin

            case (digit_sel_reg)
                2'b00: begin
                    fnd_com  = 4'b1110;
                    fnd_font = font_1;
                end

                2'b01: begin
                    fnd_com  = 4'b1101;
                    fnd_font = font_10;
                end

                2'b10: begin
                    fnd_com  = 4'b1011;
                    fnd_font = font_100;
                end

                2'b11: begin
                    fnd_com  = 4'b0111;
                    fnd_font = prefix_font;
                end

                default: begin
                    fnd_com  = 4'b1111;
                    fnd_font = 8'hFF;
                end
            endcase

            // DHT11: waiting / measuring
            if (show_wait) begin
                fnd_font = 8'hBF;  // '-'
            end

            // DHT11: communication error
            else if (show_error) begin
                case (digit_sel_reg)
                    2'b00: fnd_font = 8'hFF; // blank
                    2'b01: fnd_font = 8'hAF; // r
                    2'b10: fnd_font = 8'hAF; // r
                    2'b11: fnd_font = 8'h86; // E
                    default: fnd_font = 8'hFF;
                endcase
            end
        end
    end

endmodule
