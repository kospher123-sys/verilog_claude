`timescale 1ns / 1ps

module fifo #(
    parameter DEPTH = 4,
    A_BIT_WIDTH = $clog2(DEPTH),
    D_BIT_WIDTH = 8
) (
    input                     clk,
    input                     rst,
    input                     push,
    input                     pop,
    input  [D_BIT_WIDTH -1:0] push_data,
    output [D_BIT_WIDTH -1:0] pop_data,
    output                    full,
    output                    empty
);


    wire [A_BIT_WIDTH -1:0] w_wptr;
    wire [A_BIT_WIDTH -1:0] w_rptr;


    register_file #(
        .DEPTH(DEPTH),
        .D_BIT_WIDTH(D_BIT_WIDTH)
    ) U_REGISTER_FILE (
        .clk(clk),
        .we((~full & push)),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .wdata(push_data),
        .rdata(pop_data)
    );

    controll_unit #(
        .A_BIT_WIDTH(A_BIT_WIDTH)
    ) U_CONTROLL_UNIT (
        .clk  (clk),
        .rst  (rst),
        .push (push),
        .pop  (pop),
        .wptr (w_wptr),
        .rptr (w_rptr),
        .full (full),
        .empty(empty)
    );


endmodule

module register_file #(
    parameter DEPTH = 4,
    A_BIT_WIDTH = $clog2(DEPTH),
    D_BIT_WIDTH = 8
) (
    input                     clk,
    input                     we,
    input  [A_BIT_WIDTH -1:0] waddr,
    input  [A_BIT_WIDTH -1:0] raddr,
    input  [D_BIT_WIDTH -1:0] wdata,
    output [D_BIT_WIDTH -1:0] rdata
);

    reg [D_BIT_WIDTH-1:0] register_file[0:DEPTH-1];

    always @(posedge clk) begin
        if (we) register_file[waddr] <= wdata;
    end

    assign rdata = register_file[raddr];

endmodule

module controll_unit #(
    parameter A_BIT_WIDTH = 2
) (
    input                     clk,
    input                     rst,
    input                     push,
    input                     pop,
    output [A_BIT_WIDTH -1:0] wptr,
    output [A_BIT_WIDTH -1:0] rptr,
    output                    full,
    output                    empty
);

    reg [A_BIT_WIDTH -1 : 0] wptr_reg, wptr_next;
    reg [A_BIT_WIDTH -1 : 0] rptr_reg, rptr_next;
    reg full_reg, full_next;
    reg empty_reg, empty_next;

    assign wptr  = wptr_reg;
    assign rptr  = rptr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            wptr_reg  <= 0;
            rptr_reg  <= 0;
            full_reg  <= 0;
            empty_reg <= 1;

        end else begin
            wptr_reg  <= wptr_next;
            rptr_reg  <= rptr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end

    end

    always @(*) begin
        wptr_next  = wptr_reg;
        rptr_next  = rptr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            push, pop
        })  //상태가 push,pull의입력과 동일해서 가능한 문법
            // 2'b00: begin     //IDLE상태와 동일. 동작 X
            //     end
            2'b10: begin  //push only
                if (!full_reg) begin
                    empty_next = 1'b0;
                    wptr_next  = wptr_reg + 1;
                    if (wptr_next == rptr_reg) full_next = 1;
                end
            end
            2'b01: begin  //pop only
                if (!empty_reg) begin
                    full_next = 0;
                    rptr_next = rptr_reg + 1;
                    if (rptr_next == wptr_reg) empty_next = 1;
                end
            end
            2'b11: begin  //push only
                if (full_reg) begin
                    full_next = 0;
                    rptr_next = rptr_reg + 1;
                    if (rptr_next == wptr_reg) empty_next = 1;
                end else if (empty_reg) begin
                    empty_next = 1'b0;
                    wptr_next  = wptr_reg + 1;
                    if (wptr_next == rptr_reg) full_next = 1;
                end else begin
                    wptr_next = wptr_reg + 1;
                    rptr_next = rptr_reg + 1;
                end
            end

        endcase
    end

endmodule
