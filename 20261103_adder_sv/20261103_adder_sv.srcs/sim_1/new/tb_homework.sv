`timescale 1ns / 1ps

module tb_homework ();

    task A_thread();
        repeat (5) $display("%t : A theread", $time);
    endtask

    task B_thread();
        forever begin
            $display("%t : B theread", $time);
            #5;
        end
    endtask

    task C_thread();
        forever begin
            $display("%t : C theread", $time);
            #10;
        end
    endtask


    initial begin
        #1 $display("%t : start fork-join_any", $time);

        fork
            #10 A_thread();
            fork
                #20 B_thread();
                #50 B_thread();
            join
            #30 C_thread();
        join_any

        #10 $display("%t : end fork-join_any", $time);
        disable fork;
        $stop;
    end
endmodule


