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
    logic                  if2_consume;

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
        .if2_consume      (if2_consume),
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
    localparam logic [ADDR_WIDTH-1:0] PC_Q  = 32'h0000_0f00;
    localparam logic [ADDR_WIDTH-1:0] PC_D  = 32'h0000_0400;
    localparam logic [ADDR_WIDTH-1:0] PC_ALIAS_OLD = 32'h0000_0600;
    localparam logic [ADDR_WIDTH-1:0] PC_ALIAS_NEW = 32'h0001_0600;
    localparam logic [ADDR_WIDTH-1:0] PC_COALESCE  = 32'h0000_0700;
    localparam logic [ADDR_WIDTH-1:0] TGT_D = 32'h0000_1400;
    localparam logic [ADDR_WIDTH-1:0] PC_OV0 = 32'h0000_0800;
    localparam logic [ADDR_WIDTH-1:0] PC_OV1 = 32'h0000_0804;
    localparam logic [ADDR_WIDTH-1:0] PC_OV2 = 32'h0000_0808;
    localparam logic [ADDR_WIDTH-1:0] PC_OV3 = 32'h0000_080c;
    localparam logic [ADDR_WIDTH-1:0] PC_OV4 = 32'h0000_0810;
    localparam logic [ADDR_WIDTH-1:0] PC_DRAIN_A = 32'h0000_0900;
    localparam logic [ADDR_WIDTH-1:0] PC_DRAIN_B = 32'h0000_0904;

    int pass_count;
    int fail_count;

    task automatic drive_idle;
        begin
            if1_pc           = '0;
            if1_valid        = 1'b0;
            stall            = 1'b0;
            flush            = 1'b0;
            if2_consume      = 1'b0;
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

    task automatic queue_update_while_read;
        input logic [ADDR_WIDTH-1:0] query_pc;
        input logic [ADDR_WIDTH-1:0] update_pc;
        input logic [ADDR_WIDTH-1:0] update_target;
        begin
            @(negedge clk);
            if1_pc           = query_pc;
            if1_valid        = 1'b1;
            stall            = 1'b0;
            flush            = 1'b0;
            ex_update_en     = 1'b1;
            ex_pc            = update_pc;
            ex_actual_taken  = 1'b1;
            ex_actual_target = update_target;
            @(posedge clk);
            #1;
            if1_valid        = 1'b0;
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
            if2_consume = 1'b1;
            step();
            if2_consume = 1'b0;
        end
    endtask

    task automatic expect_queue_mask;
        input logic [3:0] exp_mask;
        input string      desc;
        begin
            if (dut.update_valid_q === exp_mask) begin
                $display("PASS | %-45s queue=%b", desc, dut.update_valid_q);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                $display("       queue: got=%b exp=%b", dut.update_valid_q, exp_mask);
                fail_count++;
            end
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
        launch_query(PC_A, "stall baseline PC_A");
        expect_pred(1'b1, TGT_A, "stall baseline PC_A");

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

        //9. same-cycle read/update forwards and remains stable while draining
        queue_update_while_read(PC_D, PC_D, TGT_D);
        expect_pred(1'b0, TGT_D, "same-cycle EX update forwards to IF2");
        expect_queue_mask(4'b0001, "read collision enqueues update");

        step();
        expect_pred(1'b0, TGT_D, "drain keeps held IF2 response stable");
        expect_queue_mask(4'b0000, "idle cycle drains queued update");

        if2_consume = 1'b1;
        step();
        if2_consume = 1'b0;
        check_query(PC_D, 1'b0, TGT_D, "drained update commits to SRAM");

        //10. repeated index coalesces to the newest target
        queue_update_while_read(PC_Q, PC_COALESCE, 32'h0000_1700);
        queue_update_while_read(PC_Q, PC_COALESCE, 32'h0000_1710);
        expect_queue_mask(4'b0001, "same-index updates coalesce");
        launch_query(PC_COALESCE, "coalesced pending target");
        expect_pred(1'b1, 32'h0000_1710, "coalesced pending target");

        if2_consume = 1'b1;
        step();
        if2_consume = 1'b0;

        //11. pending index shadows an older SRAM tag
        do_update(PC_ALIAS_OLD, 1'b1, 32'h0000_1600);
        queue_update_while_read(PC_Q, PC_ALIAS_NEW, 32'h0000_1610);
        launch_query(PC_ALIAS_OLD, "pending alias shadows old SRAM entry");
        expect_pred(1'b0, '0, "pending alias forces old-tag miss");
        launch_query(PC_ALIAS_NEW, "pending alias new tag");
        expect_pred(1'b1, 32'h0000_1610, "pending alias forwards new target");

        if2_consume = 1'b1;
        step();
        if2_consume = 1'b0;
        check_query(PC_ALIAS_OLD, 1'b0, '0, "committed alias replaces old tag");

        //12. fifth distinct update drops oldest without stalling reads
        queue_update_while_read(PC_Q, PC_OV0, 32'h0000_1800);
        queue_update_while_read(PC_Q, PC_OV1, 32'h0000_1804);
        queue_update_while_read(PC_Q, PC_OV2, 32'h0000_1808);
        queue_update_while_read(PC_Q, PC_OV3, 32'h0000_180c);
        queue_update_while_read(PC_Q, PC_OV4, 32'h0000_1810);
        expect_queue_mask(4'b1111, "overflow keeps four newest updates");
        launch_query(PC_OV0, "overflow-dropped oldest update");
        expect_pred(1'b0, '0, "overflow drops oldest update");
        launch_query(PC_OV4, "overflow-kept newest update");
        expect_pred(1'b0, 32'h0000_1810, "overflow keeps newest update");

        if2_consume = 1'b1;
        repeat (4) step();
        if2_consume = 1'b0;
        expect_queue_mask(4'b0000, "four idle cycles drain full queue");
        check_query(PC_OV1, 1'b0, 32'h0000_1804, "drain commits oldest retained update");

        //13. drain and new EX update share one cycle
        queue_update_while_read(PC_Q, PC_DRAIN_A, 32'h0000_1900);
        do_update(PC_DRAIN_B, 1'b1, 32'h0000_1904);
        expect_queue_mask(4'b0001, "drain captures simultaneous new update");
        launch_query(PC_DRAIN_A, "drain committed old queue head");
        expect_pred(1'b0, 32'h0000_1900, "drain committed old queue head");
        launch_query(PC_DRAIN_B, "simultaneous update remains pending");
        expect_pred(1'b0, 32'h0000_1904, "simultaneous update remains pending");

        if2_consume = 1'b1;
        step();
        if2_consume = 1'b0;

        //14. flush kills query metadata but preserves queued update
        queue_update_while_read(PC_Q, 32'h0000_0a00, 32'h0000_1a00);
        flush = 1'b1;
        step();
        flush = 1'b0;
        expect_pred(1'b0, '0, "flush kills IF2 response during drain");
        expect_queue_mask(4'b0000, "flush cycle commits queued update");
        check_query(32'h0000_0a00, 1'b0, 32'h0000_1a00,
                    "flush does not discard BTB update");

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
