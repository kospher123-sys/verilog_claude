`timescale 1ns / 1ps


module controll_unit_btn (
    input      clk,
    input      reset,
    input      btnR,      //run
    input      btnL,      //clear
    input      btnU,      //mode
    output reg run_stop,
    output reg clear,
    output  mode
);

    parameter STOP = 2'b00, RUN = 2'b01, CLEAR = 2'b10, MODE = 2'b11;
    reg [1:0] c_state, n_state;
    reg mode_reg, mode_next; // mode_reg_current mode , mode_next

    assign mode = mode_reg;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= STOP;
            mode_reg <= 1'b0;
        end else begin
            c_state <= n_state;
            mode_reg <= mode_next;
        end

    end
    

    always @(*) begin
        n_state  = c_state;
        run_stop = 1'b0;  //mode 값은 이전 상태를 기억하고 있어야해서 순차 회로에서는 다룰 수 없음
        clear    = 1'b0;
        mode_next = mode_reg;
        case (c_state)
            STOP: begin  //moore output
                run_stop = 1'b0;
                clear = 1'b0;
                if (btnR == 1'b1) n_state = RUN;
                else if (btnL == 1'b1) n_state = CLEAR;
                
            end
            RUN: begin
                run_stop = 1'b1;
                if (btnR == 1'b1) n_state = STOP;
                else if (btnU == 1'b1) n_state = MODE;

            end
            CLEAR: begin
                clear   = 1'b1;
                n_state = STOP;
            end
            MODE: begin
                mode_next = ~mode_reg;
                n_state = RUN;
            end
        endcase
    end
endmodule


