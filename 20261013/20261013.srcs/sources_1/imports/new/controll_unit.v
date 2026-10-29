`timescale 1ns / 1ps

module controll_unit (
    input            clk,
    input            reset,
    input      [2:0] sw,
    output reg       run_stop,
    output reg       clear,
    output           mode
);

    parameter STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10, MODE = 2'b11;
    reg [1:0] c_state, n_state;

    assign mode = sw[2];

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
        end else begin
            c_state <= n_state;
        end

    end

    always @(*) begin
        n_state  = c_state;
        run_stop = 1'b0;
        clear    = 1'b0;
        case (c_state)
            STOP: begin  //moore output
                run_stop = 1'b0;
                clear = 1'b0;
                if (sw[0] == 1'b1) n_state = RUN;
                else if (sw[1] == 1'b1) n_state = CLEAR;
            end
            RUN: begin
                run_stop = 1'b1;
                if (sw[0] == 1'b0) n_state = STOP;

            end
            CLEAR: begin
                clear = 1'b1;
                if (sw[1] == 1'b0) n_state = STOP;
            end

        endcase
    end

endmodule
