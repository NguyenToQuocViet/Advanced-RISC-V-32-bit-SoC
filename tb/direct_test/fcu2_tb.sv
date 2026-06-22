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
// Module       : fcu2_tb
// Description  : Testbench scaffold for FCU2.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-19
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module fcu2_tb;
    import cpu_pkg::*;

    //system
    logic clk;
    logic rst_n;

    //i-cache response
    logic [DATA_WIDTH-1:0]  instr_i;
    logic                   cache_valid;
    logic                   cache_ready;

    //IF1/IF2 metadata
    logic                   if2_valid;

    //branch prediction
    logic                   pred_taken;
    logic [ADDR_WIDTH-1:0]  pred_target;

    //EX feedback
    logic                   ex_mispredict;

    //FCU1 control
    logic                   cache_advance;
    logic                   if2_redirect;
    logic [ADDR_WIDTH-1:0]  if2_redirect_pc;

    //hazard control
    logic                   stall;

    //IF2/ID pipeline
    logic [DATA_WIDTH-1:0]  instr_o;
    logic                   if2_id_pred_taken;
    logic [ADDR_WIDTH-1:0]  if2_id_pred_target;
    logic                   if2_id_flush;

    //DUT
    fcu2 dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .instr_i                (instr_i),
        .cache_valid            (cache_valid),
        .cache_ready            (cache_ready),
        .if2_valid              (if2_valid),
        .pred_taken             (pred_taken),
        .pred_target            (pred_target),
        .ex_mispredict          (ex_mispredict),
        .cache_advance          (cache_advance),
        .if2_redirect           (if2_redirect),
        .if2_redirect_pc        (if2_redirect_pc),
        .stall                  (stall),
        .instr_o                (instr_o),
        .if2_id_pred_taken      (if2_id_pred_taken),
        .if2_id_pred_target     (if2_id_pred_target),
        .if2_id_flush           (if2_id_flush)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    int pass_count;
    int fail_count;

    task automatic drive_idle;
        begin
            instr_i       = 32'h0000_0013; //NOP
            cache_valid   = 1'b0;
            cache_ready   = 1'b0;
            if2_valid     = 1'b0;
            pred_taken    = 1'b0;
            pred_target   = '0;
            ex_mispredict = 1'b0;
            stall         = 1'b0;
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

    task automatic expect_ctrl;
        input logic                  exp_cache_advance;
        input logic                  exp_if2_redirect;
        input logic [ADDR_WIDTH-1:0] exp_if2_redirect_pc;
        input logic                  exp_if2_id_flush;
        input string                 desc;
        begin
            if ((cache_advance    === exp_cache_advance) &&
                (if2_redirect     === exp_if2_redirect) &&
                (if2_redirect_pc  === exp_if2_redirect_pc) &&
                (if2_id_flush     === exp_if2_id_flush)) begin
                $display("PASS | %-45s adv=%0b redir=%0b redir_pc=%h flush=%0b",
                         desc, cache_advance, if2_redirect, if2_redirect_pc, if2_id_flush);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (cache_advance !== exp_cache_advance)
                    $display("       cache_advance : got=%0b exp=%0b", cache_advance, exp_cache_advance);
                if (if2_redirect !== exp_if2_redirect)
                    $display("       if2_redirect  : got=%0b exp=%0b", if2_redirect, exp_if2_redirect);
                if (if2_redirect_pc !== exp_if2_redirect_pc)
                    $display("       redirect_pc   : got=%h exp=%h", if2_redirect_pc, exp_if2_redirect_pc);
                if (if2_id_flush !== exp_if2_id_flush)
                    $display("       if2_id_flush  : got=%0b exp=%0b", if2_id_flush, exp_if2_id_flush);
                fail_count++;
            end
        end
    endtask

    task automatic expect_pipe;
        input logic [DATA_WIDTH-1:0] exp_instr;
        input logic                  exp_pred_taken;
        input logic [ADDR_WIDTH-1:0] exp_pred_target;
        input string                 desc;
        begin
            if ((instr_o             === exp_instr) &&
                (if2_id_pred_taken   === exp_pred_taken) &&
                (if2_id_pred_target  === exp_pred_target)) begin
                $display("PASS | %-45s instr=%h pred=%0b target=%h",
                         desc, instr_o, if2_id_pred_taken, if2_id_pred_target);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (instr_o !== exp_instr)
                    $display("       instr_o      : got=%h exp=%h", instr_o, exp_instr);
                if (if2_id_pred_taken !== exp_pred_taken)
                    $display("       pred_taken   : got=%0b exp=%0b", if2_id_pred_taken, exp_pred_taken);
                if (if2_id_pred_target !== exp_pred_target)
                    $display("       pred_target  : got=%h exp=%h", if2_id_pred_target, exp_pred_target);
                fail_count++;
            end
        end
    endtask
     
    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        reset_dut();

        //1. valid ready response, not taken
        instr_i       = 32'h0050_0093;

        cache_valid   = 1'b1;
        cache_ready   = 1'b1;
        if2_valid     = 1'b1;

        pred_taken    = 1'b0;
        pred_target   = 32'h0000_0040;

        ex_mispredict = 1'b0;
        stall         = 1'b0;

        step();

        expect_ctrl(
            1'b1,             //cache_advance
            1'b0,             //if2_redirect
            32'h0000_0040,    //if2_redirect_pc
            1'b0,             //if2_id_flush
            "valid ready not taken ctrl"
        );

        expect_pipe(
            32'h0050_0093,    //instr_o
            1'b0,             //if2_id_pred_taken
            32'h0000_0040,    //if2_id_pred_target
            "valid ready not taken pipe"
        );



        //2. valid ready response, taken redirect
        instr_i       = 32'h0000_0063;
        cache_valid   = 1'b1;
        cache_ready   = 1'b1;
        if2_valid     = 1'b1;
        pred_taken    = 1'b1;
        pred_target   = 32'h0000_0080;
        ex_mispredict = 1'b0;
        stall         = 1'b0;

        step();

        expect_ctrl(
            1'b1,
            1'b1,
            32'h0000_0080,
            1'b0,
            "valid ready taken ctrl"
        );

        expect_pipe(
            32'h0000_0063,
            1'b1,
            32'h0000_0080,
            "valid ready taken pipe"
        );

        //3. if2_valid=0 blocks redirect and flushes IF2/ID
        instr_i       = 32'h0010_0113;
        cache_valid   = 1'b1;
        cache_ready   = 1'b1;
        if2_valid     = 1'b0;
        pred_taken    = 1'b1;
        pred_target   = 32'h0000_00c0;
        ex_mispredict = 1'b0;
        stall         = 1'b0;

        step();

        expect_ctrl(
            1'b0,
            1'b0,
            32'h0000_00c0,
            1'b1,
            "invalid if2 slot ctrl"
        );

        expect_pipe(
            32'h0010_0113,
            1'b1,
            32'h0000_00c0,
            "invalid if2 slot pipe"
        );

        //4. cache_valid=0 blocks redirect and flushes IF2/ID
        instr_i       = 32'h0020_0193;
        cache_valid   = 1'b0;
        cache_ready   = 1'b0;
        if2_valid     = 1'b1;
        pred_taken    = 1'b1;
        pred_target   = 32'h0000_0100;
        ex_mispredict = 1'b0;
        stall         = 1'b0;

        step();

        expect_ctrl(
            1'b0,
            1'b0,
            32'h0000_0100,
            1'b1,
            "invalid cache response ctrl"
        );

        expect_pipe(
            32'h0020_0193,
            1'b1,
            32'h0000_0100,
            "invalid cache response pipe"
        );

        //5. stall blocks IF2 fire and redirect, cache_advance remains cache-side ready
        instr_i       = 32'h0030_0213;
        cache_valid   = 1'b1;
        cache_ready   = 1'b1;
        if2_valid     = 1'b1;
        pred_taken    = 1'b1;
        pred_target   = 32'h0000_0140;
        ex_mispredict = 1'b0;
        stall         = 1'b1;

        step();

        expect_ctrl(
            1'b1,
            1'b0,
            32'h0000_0140,
            1'b0,
            "stall blocks fire ctrl"
        );

        expect_pipe(
            32'h0030_0213,
            1'b1,
            32'h0000_0140,
            "stall blocks fire pipe"
        );

        //6. ex_mispredict overrides BTB redirect
        instr_i       = 32'h0040_0293;
        cache_valid   = 1'b1;
        cache_ready   = 1'b1;
        if2_valid     = 1'b1;
        pred_taken    = 1'b1;
        pred_target   = 32'h0000_0180;
        ex_mispredict = 1'b1;
        stall         = 1'b0;

        step();

        expect_ctrl(
            1'b1,
            1'b0,
            32'h0000_0180,
            1'b1,
            "ex mispredict priority ctrl"
        );

        expect_pipe(
            32'h0040_0293,
            1'b1,
            32'h0000_0180,
            "ex mispredict priority pipe"
        );

        //7. CWF response captures once, then duplicate is blocked
        ex_mispredict = 1'b0;
        instr_i       = 32'h0050_0313;
        cache_valid   = 1'b1;
        cache_ready   = 1'b0;
        if2_valid     = 1'b1;
        pred_taken    = 1'b0;
        pred_target   = 32'h0000_01c0;
        stall         = 1'b0;

        #1;

        expect_ctrl(
            1'b0,
            1'b0,
            32'h0000_01c0,
            1'b0,
            "cwf first fire ctrl"
        );

        expect_pipe(
            32'h0050_0313,
            1'b0,
            32'h0000_01c0,
            "cwf first fire pipe"
        );

        step();

        expect_ctrl(
            1'b0,
            1'b0,
            32'h0000_01c0,
            1'b1,
            "cwf duplicate blocked ctrl"
        );

        expect_pipe(
            32'h0050_0313,
            1'b0,
            32'h0000_01c0,
            "cwf duplicate blocked pipe"
        );

        //8. cache_ready clears CWF consumed state
        cache_ready = 1'b1;

        step();

        expect_ctrl(
            1'b1,
            1'b0,
            32'h0000_01c0,
            1'b0,
            "cache ready clears cwf ctrl"
        );

        expect_pipe(
            32'h0050_0313,
            1'b0,
            32'h0000_01c0,
            "cache ready clears cwf pipe"
        );

        //9. taken CWF must redirect once, then block duplicate redirect
        instr_i       = 32'h0060_0363;
        cache_valid   = 1'b1;
        cache_ready   = 1'b0;
        if2_valid     = 1'b1;
        pred_taken    = 1'b1;
        pred_target   = 32'h0000_0200;
        ex_mispredict = 1'b0;
        stall         = 1'b0;

        #1;

        expect_ctrl(
            1'b0,
            1'b1,
            32'h0000_0200,
            1'b0,
            "taken cwf first redirect ctrl"
        );

        expect_pipe(
            32'h0060_0363,
            1'b1,
            32'h0000_0200,
            "taken cwf first redirect pipe"
        );

        step();

        expect_ctrl(
            1'b0,
            1'b0,
            32'h0000_0200,
            1'b1,
            "taken cwf duplicate blocked ctrl"
        );

        expect_pipe(
            32'h0060_0363,
            1'b1,
            32'h0000_0200,
            "taken cwf duplicate blocked pipe"
        );

        cache_ready = 1'b1;

        step();

        expect_ctrl(
            1'b1,
            1'b1,
            32'h0000_0200,
            1'b0,
            "taken cwf ready clear ctrl"
        );

        expect_pipe(
            32'h0060_0363,
            1'b1,
            32'h0000_0200,
            "taken cwf ready clear pipe"
        );

        //10. interleaved stress: normal, stall, mispredict, CWF, recover
        instr_i       = 32'h0060_0393;
        cache_valid   = 1'b1;
        cache_ready   = 1'b1;
        if2_valid     = 1'b1;
        pred_taken    = 1'b0;
        pred_target   = 32'h0000_0200;
        ex_mispredict = 1'b0;
        stall         = 1'b0;

        step();
        expect_ctrl(1'b1, 1'b0, 32'h0000_0200, 1'b0, "stress normal ctrl");
        expect_pipe (32'h0060_0393, 1'b0, 32'h0000_0200, "stress normal pipe");

        instr_i     = 32'h0070_0413;
        pred_taken  = 1'b1;
        pred_target = 32'h0000_0240;
        stall       = 1'b1;

        step();
        expect_ctrl(1'b1, 1'b0, 32'h0000_0240, 1'b0, "stress stall ctrl");
        expect_pipe (32'h0070_0413, 1'b1, 32'h0000_0240, "stress stall pipe");

        stall         = 1'b0;
        ex_mispredict = 1'b1;
        pred_target   = 32'h0000_0280;

        step();
        expect_ctrl(1'b1, 1'b0, 32'h0000_0280, 1'b1, "stress ex priority ctrl");
        expect_pipe (32'h0070_0413, 1'b1, 32'h0000_0280, "stress ex priority pipe");

        ex_mispredict = 1'b0;
        instr_i       = 32'h0080_0493;
        cache_ready   = 1'b0;
        pred_taken    = 1'b0;
        pred_target   = 32'h0000_02c0;

        #1;
        expect_ctrl(1'b0, 1'b0, 32'h0000_02c0, 1'b0, "stress cwf first ctrl");
        expect_pipe (32'h0080_0493, 1'b0, 32'h0000_02c0, "stress cwf first pipe");

        step();
        expect_ctrl(1'b0, 1'b0, 32'h0000_02c0, 1'b1, "stress cwf duplicate ctrl");
        expect_pipe (32'h0080_0493, 1'b0, 32'h0000_02c0, "stress cwf duplicate pipe");

        cache_ready = 1'b1;
        pred_taken  = 1'b0;
        pred_target = 32'h0000_0300;

        step();
        expect_ctrl(1'b1, 1'b0, 32'h0000_0300, 1'b0, "stress recover ctrl");
        expect_pipe (32'h0080_0493, 1'b0, 32'h0000_0300, "stress recover pipe");

        $display("--------------------------------------------------");
        $display("FCU2_TB SCAFFOLD READY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------------");

        $finish;
    end
endmodule
