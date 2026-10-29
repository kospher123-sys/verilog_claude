`timescale 1ns / 1ps


module tb_fifo ();
    parameter DEPTH = 4, A_BIT_WIDTH = $clog2(DEPTH), D_BIT_WIDTH = 8;

    reg                        clk;
    reg                        rst;
    reg                        push;
    reg                        pop;
    reg     [D_BIT_WIDTH -1:0] push_data;
    wire    [D_BIT_WIDTH -1:0] pop_data;
    wire                       full;
    wire                       empty;
    integer                    i;

    reg     [             7:0] compare_buffer[0:DEPTH-1];
    reg [1:0] push_cnt, pop_cnt;
    integer pass_cnt, fail_cnt;


    fifo #(
        .DEPTH      (DEPTH),
        .D_BIT_WIDTH(D_BIT_WIDTH)
    ) DUT (
        .clk      (clk),
        .rst      (rst),
        .push     (push),
        .pop      (pop),
        .push_data(push_data),
        .pop_data (pop_data),
        .full     (full),
        .empty    (empty)
    );


    always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;
        push = 0;
        pop = 0;
        push_data = 0;
        i = 0;
        push_cnt = 0;
        pop_cnt = 0;
        pass_cnt =0;
        fail_cnt =0;

        @(negedge clk);
        @(negedge clk);

        rst = 0;
        @(negedge clk);
        if (full == 0) begin
            $display("%t : pass full reset signal", $stime);
        end else begin
            $display("%t : fail full reset signal", $stime);
        end

        if (empty == 1) begin
            $display("%t : pass empty reset signal", $stime);
        end else begin
            $display("%t : fail empty reset signal", $stime);
        end

        //PUSH OMLY
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge clk);
            push_data = 8'h0a + i;
            push = 1'b1;
            if (!full) begin
                compare_buffer[push_cnt] = push_data;
                push_cnt = push_cnt + 1;
            end
        end

        @(negedge clk);
        push = 1'b0;

        //POP ONLY
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge clk);
            pop = 1'b1;
            if (!empty) begin
                if (pop_data == compare_buffer[pop_cnt]) begin
                    $display("%t : pass pop data = %h", $stime, pop_data);
                end else begin
                    $display("%t : fail pop data = %h, compare_data = %h",
                             $stime, pop_data, compare_buffer[pop_cnt]);
                end
                pop_cnt = pop_cnt + 1;
            end
        end

        if (empty) begin
            $display("%t : pass empty signal", $stime);
        end else $display("%t : pass empty signal", $stime);

        @(negedge clk);
        pop = 1'b0;

        //PUSH & POP
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge clk);
            push_data = 8'ha0 + i;
            push = 1'b1;
            if (!full) begin
                compare_buffer[push_cnt] = push_data;
                push_cnt = push_cnt + 1;
            end
            ;
            pop = 1'b1;
            if (!empty) begin
                if (pop_data == compare_buffer[pop_cnt]) begin
                    $display("%t : pass pop data = %h", $stime, pop_data);
                end else begin
                    $display("%t : fail pop data = %h, compare_data = %h",
                             $stime, pop_data, compare_buffer[pop_cnt]);
                end
                pop_cnt = pop_cnt + 1;
            end
        end

        @(negedge clk);
        push = 0;
        pop  = 1;
        pop_cnt = pop_cnt +1;
        @(negedge clk);

        $display ("start random test");
        //random
        repeat (256) begin
            @(negedge clk);
            push = $random % 2;
            pop = $random % 2;
            push_data = $random % 256;
            if (!full && push ==1) begin
                compare_buffer[push_cnt] = push_data;
                push_cnt = push_cnt + 1;
            end
            if (!empty && pop ==1) begin
                if (pop_data == compare_buffer[pop_cnt]) begin
                    $display("%t : pass pop data = %h", $stime, pop_data);
                    pass_cnt = pass_cnt +1;
                end else begin
                    $display("%t : fail pop data = %h, compare_data = %h",
                             $stime, pop_data, compare_buffer[pop_cnt]);
                             fail_cnt = fail_cnt +1;
                end
                pop_cnt = pop_cnt + 1;
            end
        end

        //report
        $display("***random test result***");
        $display("* total random test =  256");
        $display("* pass count        = %4d", pass_cnt);
        $display("* fail count        = %4d", fail_cnt);

        #10;
        $finish;



    end


endmodule
