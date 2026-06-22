// -----------------------------------------------------------------------------
// Copyright (c) 2026 NGUYEN TO QUOC VIET
// Ho Chi Minh City University of Technology (HCMUT-VNU)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit Processor
// Module       : dbp_7stg_tb
// Description  : Directed testbench for 7-stage DBP timing and predictor state.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-22
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module dbp_7stg_tb;
    import cpu_pkg::*;

    //system
    logic clk;
    logic rst_n;

    //IF1 query
    logic [ADDR_WIDTH-1:0] if1_pc;
    logic                  if1_valid;
    logic                  stall;
    logic                  flush;

    //IF2 prediction
    logic                  pred_taken;
    logic [ADDR_WIDTH-1:0] pred_target;

    //EX update
    logic                  ex_update_en;
    logic [ADDR_WIDTH-1:0] ex_pc;
    logic                  ex_actual_taken;
    logic [ADDR_WIDTH-1:0] ex_actual_target;

    dbp_7stg dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .if1_pc           (if1_pc),
        .if1_valid        (if1_valid),
        .stall            (stall),
        .flush            (flush),
        .pred_taken       (pred_taken),
        .pred_target      (pred_target),
        .ex_update_en     (ex_update_en),
        .ex_pc            (ex_pc),
        .ex_actual_taken  (ex_actual_taken),
        .ex_actual_target (ex_actual_target)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    localparam logic [ADDR_WIDTH-1:0] PC_A  = 32'h0000_0100;
    localparam logic [ADDR_WIDTH-1:0] PC_B  = 32'h0000_0200;
    localparam logic [ADDR_WIDTH-1:0] PC_C  = 32'h0001_0100;
    localparam logic [ADDR_WIDTH-1:0] TGT_A = 32'h0000_0300;
    localparam logic [ADDR_WIDTH-1:0] TGT_B = 32'h0000_0400;

    int pass_count;
    int fail_count;

    task automatic drive_idle;
        begin
            if1_pc           = '0;
            if1_valid        = 1'b0;
            stall            = 1'b0;
            flush            = 1'b0;
            ex_update_en     = 1'b0;
            ex_pc            = '0;
            ex_actual_taken  = 1'b0;
            ex_actual_target = '0;
        end
    endtask

    task automatic reset_dut;
        begin
            drive_idle();
            rst_n = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            rst_n = 1'b1;
        end
    endtask

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic do_update;
        input logic [ADDR_WIDTH-1:0] t_ex_pc;
        input logic                  t_taken;
        input logic [ADDR_WIDTH-1:0] t_target;
        begin
            @(negedge clk);
            ex_update_en     = 1'b1;
            ex_pc            = t_ex_pc;
            ex_actual_taken  = t_taken;
            ex_actual_target = t_target;
            @(posedge clk);
            #1;
            ex_update_en     = 1'b0;
            ex_actual_taken  = 1'b0;
            ex_actual_target = '0;
        end
    endtask

    task automatic launch_query;
        input logic [ADDR_WIDTH-1:0] t_if1_pc;
        input string                 desc;
        begin
            if1_pc    = t_if1_pc;
            if1_valid = 1'b1;
            stall     = 1'b0;
            flush     = 1'b0;
            step();
            if1_valid = 1'b0;
            $display("INFO | %-45s launched pc=%h", desc, t_if1_pc);
        end
    endtask

    task automatic expect_pred;
        input logic                  exp_taken;
        input logic [ADDR_WIDTH-1:0] exp_target;
        input string                 desc;
        begin
            if ((pred_taken === exp_taken) && (pred_target === exp_target)) begin
                $display("PASS | %-45s pred=%0b target=%h", desc, pred_taken, pred_target);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (pred_taken !== exp_taken)
                    $display("       pred_taken : got=%0b exp=%0b", pred_taken, exp_taken);
                if (pred_target !== exp_target)
                    $display("       pred_target: got=%h exp=%h", pred_target, exp_target);
                fail_count++;
            end
        end
    endtask

    task automatic check_query;
        input logic [ADDR_WIDTH-1:0] t_if1_pc;
        input logic                  exp_taken;
        input logic [ADDR_WIDTH-1:0] exp_target;
        input string                 desc;
        begin
            launch_query(t_if1_pc, desc);
            expect_pred(exp_taken, exp_target, desc);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        reset_dut();

        //1. cold miss: no BTB entry
        check_query(PC_A, 1'b0, '0, "cold miss PC_A");
        check_query(PC_B, 1'b0, '0, "cold miss PC_B");

        //2. BHT train up: BTB written on taken, threshold at WEAKLY_T
        do_update(PC_A, 1'b1, TGT_A);
        check_query(PC_A, 1'b0, TGT_A, "PC_A after 1 taken");

        do_update(PC_A, 1'b1, TGT_A);
        check_query(PC_A, 1'b1, TGT_A, "PC_A after 2 taken");

        do_update(PC_A, 1'b1, TGT_A);
        check_query(PC_A, 1'b1, TGT_A, "PC_A after 3 taken");

        do_update(PC_A, 1'b1, TGT_A);
        check_query(PC_A, 1'b1, TGT_A, "PC_A saturates taken");

        //3. BHT train down: BTB target remains, taken drops below threshold
        do_update(PC_A, 1'b0, TGT_A);
        check_query(PC_A, 1'b1, TGT_A, "PC_A after 1 not-taken");

        do_update(PC_A, 1'b0, TGT_A);
        check_query(PC_A, 1'b0, TGT_A, "PC_A after 2 not-taken");

        do_update(PC_A, 1'b0, TGT_A);
        check_query(PC_A, 1'b0, TGT_A, "PC_A after 3 not-taken");

        do_update(PC_A, 1'b0, TGT_A);
        check_query(PC_A, 1'b0, TGT_A, "PC_A saturates not-taken");

        //4. BTB write-on-taken only
        do_update(PC_B, 1'b1, TGT_B);
        check_query(PC_B, 1'b0, TGT_B, "PC_B after 1 taken");

        do_update(PC_B, 1'b1, TGT_B);
        check_query(PC_B, 1'b1, TGT_B, "PC_B after 2 taken");

        do_update(PC_B, 1'b0, 32'hDEAD_BEEF);
        check_query(PC_B, 1'b0, TGT_B, "PC_B not-taken keeps BTB target");

        //5. tag mismatch at same index
        do_update(PC_A, 1'b1, TGT_A);
        do_update(PC_A, 1'b1, TGT_A);
        check_query(PC_A, 1'b1, TGT_A, "PC_A trained for tag check");
        check_query(PC_C, 1'b0, '0, "PC_C same index tag miss");

        //6. update_en=0 does not change predictor state
        @(negedge clk);
        ex_update_en     = 1'b0;
        ex_pc            = PC_A;
        ex_actual_taken  = 1'b0;
        ex_actual_target = 32'hDEAD_BEEF;
        @(posedge clk);
        #1;
        check_query(PC_A, 1'b1, TGT_A, "update_en zero no change");

        //7. stall holds IF2 prediction metadata
        check_query(PC_A, 1'b1, TGT_A, "stall baseline PC_A");

        if1_pc    = PC_B;
        if1_valid = 1'b1;
        stall     = 1'b1;
        flush     = 1'b0;
        step();
        expect_pred(1'b1, TGT_A, "stall holds previous prediction");

        stall     = 1'b0;
        if1_valid = 1'b0;

        //8. flush kills pending IF1 query metadata
        if1_pc    = PC_A;
        if1_valid = 1'b1;
        flush     = 1'b1;
        step();
        flush     = 1'b0;
        if1_valid = 1'b0;
        expect_pred(1'b0, '0, "flush kills prediction response");

        $display("--------------------------------------------------");
        $display("DBP_7STG_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------------");

        if (fail_count == 0)
            $display("DBP_7STG_TB PASS");
        else
            $display("DBP_7STG_TB FAIL");

        $finish;
    end
endmodule
