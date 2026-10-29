`timescale 1ns / 1ps
module ascii_decorder (
    input [7:0] rx_data,
    input rx_done,
    output fnd_data
);
    reg [4:0] fnd_data_reg;

    assign fnd_data = fnd_data_reg;

    always @(*) begin
        fnd_data_reg = 5'd0;
        if (rx_done) begin
            case (rx_data)
                8'h30:   fnd_data_reg = 5'd0;
                8'h31:   fnd_data_reg = 5'd1;
                8'h32:   fnd_data_reg = 5'd2;
                8'h33:   fnd_data_reg = 5'd3;
                8'h34:   fnd_data_reg = 5'd4;
                8'h35:   fnd_data_reg = 5'd5;
                8'h36:   fnd_data_reg = 5'd6;
                8'h37:   fnd_data_reg = 5'd7;
                8'h38:   fnd_data_reg = 5'd8;
                8'h39:   fnd_data_reg = 5'd9;  // 0~9
                8'h41:   fnd_data_reg = 5'd10;  // capital A~F
                8'h42:   fnd_data_reg = 5'd11;
                8'h43:   fnd_data_reg = 5'd12;
                8'h44:   fnd_data_reg = 5'd13;
                8'h45:   fnd_data_reg = 5'd14;
                8'h46:   fnd_data_reg = 5'd15;
                8'h61:   fnd_data_reg = 5'd16;  // lower a~f
                8'h62:   fnd_data_reg = 5'd17;
                8'h63:   fnd_data_reg = 5'd18;
                8'h64:   fnd_data_reg = 5'd19;
                8'h65:   fnd_data_reg = 5'd20;
                8'h66:   fnd_data_reg = 5'd21;
            endcase
        end
    end
endmodule
