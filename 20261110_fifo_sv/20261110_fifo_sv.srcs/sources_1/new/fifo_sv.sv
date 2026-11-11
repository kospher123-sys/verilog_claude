`timescale 1ns / 1ps


module fifo_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic       push,
    input  logic       pop,
    input  logic [7:0] push_data,
    output logic [7:0] pop_data,
    output logic       full,
    output logic       empty
);

    logic [1:0] w_wptr, w_rptr;

    register U_REGISTER (
        .*,
        .enable(push & (~full)),
        .waddr(w_wptr),
        .raddr(w_rptr)
    );

    controll U_CONTROLL (
        .*,
        .wptr (w_wptr),
        .rptr (w_rptr)
    );
endmodule


module register #(
    parameter DEPTH = 4,
    DEPTH_BIT = $clog2(DEPTH)
) (
    input  logic                    clk,
    input  logic [DEPTH_BIT -1 : 0] waddr,
    input  logic [DEPTH_BIT -1 : 0] raddr,
    input  logic                    enable,
    input  logic [             7:0] push_data,
    output logic [             7:0] pop_data
);

    logic [7:0] ram[0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (enable) begin
            ram[waddr] <= push_data;
        end
    end

    assign pop_data = ram[raddr];

endmodule

module controll #(
    parameter DEPTH = 4,
    DEPTH_BIT = $clog2(DEPTH)
) (
    input  logic                    clk,
    input  logic                    rst,
    input  logic                    push,
    input  logic                    pop,
    output logic [DEPTH_BIT -1 : 0] wptr,
    output logic [DEPTH_BIT -1 : 0] rptr,
    output logic                    full,
    output logic                    empty
);
    logic [DEPTH_BIT -1 : 0] wptr_next; //logic이라 굳이 reg는 필요없음
    logic [DEPTH_BIT -1 : 0] rptr_next;
    logic full_next;
    logic empty_next;



    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            wptr  <= 0;
            rptr  <= 0;
            full  <= 0;
            empty <= 1;
        end else begin
            wptr  <= wptr_next;
            rptr  <= rptr_next;
            full  <= full_next;
            empty <= empty_next;
        end
    end

    always_comb begin
        wptr_next  = wptr;
        rptr_next  = rptr;
        full_next  = full;
        empty_next = empty;
        case ({
            push, pop
        })
            2'b10: begin
                if (!full) begin
                    empty_next = 0;
                    wptr_next  = wptr + 1;
                    if (wptr_next == rptr) begin
                        full_next = 1;
                    end
                end
            end
            2'b01: begin
                if (!empty) begin
                    full_next = 0;
                    rptr_next = rptr + 1;
                    if (rptr_next == wptr) begin
                        empty_next = 1;
                    end
                end
            end
            2'b11: begin
                if (empty) begin
                    empty_next = 0;
                    wptr_next  = wptr + 1;
                end else if (full) begin
                    full_next = 0;
                    rptr_next = rptr + 1;
                end else begin
                    wptr_next = wptr + 1;
                    rptr_next = rptr + 1;
                end
            end
        endcase
    end

endmodule
