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
// Module       : fcu1_tb
// Description  : Testbench scaffold for FCU1.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-19
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module fcu1_tb;
    import cpu_pkg::*;

    //system
    logic clk;
    logic rst_n;

    //i-cache request
    logic                    if_req;
    logic [ADDR_WIDTH-1:0]   if_pc;

    //EX feedback
    logic                    ex_mispredict;
    logic [ADDR_WIDTH-1:0]   ex_correct_pc;

    //hazard control
    logic                    stall;


    //IF1/IF2 pipeline
    logic [ADDR_WIDTH-1:0]   if1_if2_pc;
    logic                    if1_if2_flush;

    //IF2 redirect
    logic                    if2_redirect;
    logic [ADDR_WIDTH-1:0]   if2_redirect_pc;
    logic                    cache_advance;

    //DUT
    fcu1 dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .if_req             (if_req),
        .if_pc              (if_pc),
        .ex_mispredict      (ex_mispredict),
        .ex_correct_pc      (ex_correct_pc),
        .stall              (stall),
        .if1_if2_pc         (if1_if2_pc),
        .if1_if2_flush      (if1_if2_flush),
        .if2_redirect       (if2_redirect),
        .if2_redirect_pc    (if2_redirect_pc),
        .cache_advance      (cache_advance)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    int pass_count;
    int fail_count;

    task automatic drive_idle;
        begin
            ex_mispredict  = 1'b0;
            ex_correct_pc  = '0;
            stall          = 1'b0;
            if2_redirect   = 1'b0;
            if2_redirect_pc = '0;
            cache_advance  = 1'b1;
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

    task automatic expect_fetch;
        input logic [ADDR_WIDTH-1:0] exp_if_pc;
        input logic                  exp_if_req;
        input string                 desc;
        begin
            if ((if_pc === exp_if_pc) && (if_req === exp_if_req)) begin
                $display("PASS | %-45s if_pc=%h if_req=%0b", desc, if_pc, if_req);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (if_pc !== exp_if_pc)
                    $display("       if_pc : got=%h exp=%h", if_pc, exp_if_pc);
                if (if_req !== exp_if_req)
                    $display("       if_req: got=%0b exp=%0b", if_req, exp_if_req);
                fail_count++;
            end
        end
    endtask

    task automatic expect_pipe;
        input logic [ADDR_WIDTH-1:0] exp_pc;
        input logic                  exp_flush;
        input string                 desc;
        begin
            if ((if1_if2_pc === exp_pc) &&
                (if1_if2_flush === exp_flush)) begin
                $display("PASS | %-45s pipe_pc=%h flush=%0b",
                         desc, if1_if2_pc, if1_if2_flush);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (if1_if2_pc !== exp_pc)
                    $display("       pipe_pc: got=%h exp=%h", if1_if2_pc, exp_pc);
                if (if1_if2_flush !== exp_flush)
                    $display("       flush  : got=%0b exp=%0b", if1_if2_flush, exp_flush);
                fail_count++;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        //1. normal advance
        reset_dut();
        expect_fetch(PC_RESET_VEC + 4, 1'b1, "reset release launch pc");
        expect_pipe (PC_RESET_VEC + 4, 1'b0, "reset release pipe output");

        step();
        expect_fetch(PC_RESET_VEC + 8, 1, "normal advance cycle 1 fetch");
        expect_pipe (PC_RESET_VEC + 8, 0, "normal advance cycle 1 pipe");

        step();
        expect_fetch(PC_RESET_VEC + 12, 1, "normal advance cycle 2 fetch");
        expect_pipe (PC_RESET_VEC + 12, 0, "normal advance cycle 2 pipe");

        //2. cache_advance=0 hold
        cache_advance = 0;
        step();
        expect_fetch(PC_RESET_VEC + 8, 1, "!cache_advance cycle 3 fetch");
        expect_pipe (PC_RESET_VEC + 8, 0, "!cache_advance cycle 3 pipe");
 
        step();
        expect_fetch(PC_RESET_VEC + 8, 1, "!cache_advance cycle 4 fetch");
        expect_pipe (PC_RESET_VEC + 8, 0, "!cache_advance cycle 4 pipe");
        
        //3. stall hold and if_req=0

            //normal advance
        cache_advance   = 1;

        step();
        expect_fetch(PC_RESET_VEC + 16, 1, "normal advance cycle 5 fetch");
        expect_pipe (PC_RESET_VEC + 16, 0, "normal advance cycle 5 pipe");
            
            //stall
        stall           = 1;
        
        step();
        expect_fetch(PC_RESET_VEC + 12, 0, "stall cycle 6 fetch");
        expect_pipe (PC_RESET_VEC + 12, 0, "stall cycle 6 pipe");

        step();

        expect_fetch(PC_RESET_VEC + 12, 0, "stall cycle 7 fetch");
        expect_pipe (PC_RESET_VEC + 12, 0, "stall cycle 7 pipe");

        //4. if2_redirect priority

            //normal advance
        stall           = 0;

        step();
        expect_fetch(PC_RESET_VEC + 20, 1, "stall cycle 8 fetch");
        expect_pipe (PC_RESET_VEC + 20, 0, "stall cycle 8 pipe");

            //redirect
        if2_redirect    = 1;
        if2_redirect_pc = PC_RESET_VEC + 40;

        step();
        expect_fetch(PC_RESET_VEC + 44, 1, "redirect cycle 9 fetch");
        expect_pipe (PC_RESET_VEC + 44, 1, "redirect cycle 9 pipe");

        if2_redirect    = 1;
        if2_redirect_pc = PC_RESET_VEC + 120;

        step();
        expect_fetch(PC_RESET_VEC + 124, 1, "redirect cycle 10 fetch");
        expect_pipe (PC_RESET_VEC + 124, 1, "redirect cycle 10 pipe");

        if2_redirect    = 0;
                
            //normal advance
        step();
        expect_fetch(PC_RESET_VEC + 128, 1, "normal advance cycle 11 fetch");
        expect_pipe (PC_RESET_VEC + 128, 0, "normal advance cycle 11 pipe");

        //5. ex_mispredict priority over if2_redirect
            //normal mispredict
        ex_mispredict       = 1;
        ex_correct_pc       = PC_RESET_VEC + 28;

        step();
        expect_fetch(PC_RESET_VEC + 32, 0, "mispredict cycle 12 fetch");
        expect_pipe (PC_RESET_VEC + 32, 1, "mispredict cycle 12 pipe");

            //mispredict over redirect
        ex_mispredict       = 1;
        ex_correct_pc       = PC_RESET_VEC + 64;

        if2_redirect        = 1;
        if2_redirect_pc     = PC_RESET_VEC + 200;

        step();
        expect_fetch(PC_RESET_VEC + 68, 0, "mispredict cycle 13 fetch");
        expect_pipe (PC_RESET_VEC + 68, 1, "mispredict cycle 13 pipe");


        //6. interleaved stress: normal, stall, redirect, mispredict
        ex_mispredict   = 0;
        ex_correct_pc   = '0;
        if2_redirect    = 0;
        if2_redirect_pc = '0;
        stall           = 0;
        cache_advance   = 1;

        step();
        expect_fetch(PC_RESET_VEC + 72, 1, "stress cycle 14 normal fetch");
        expect_pipe (PC_RESET_VEC + 72, 0, "stress cycle 14 normal pipe");

        stall = 1;
        step();
        expect_fetch(PC_RESET_VEC + 68, 0, "stress cycle 15 stall fetch");
        expect_pipe (PC_RESET_VEC + 68, 0, "stress cycle 15 stall pipe");

        stall           = 0;
        if2_redirect    = 1;
        if2_redirect_pc = PC_RESET_VEC + 300;
        step();
        expect_fetch(PC_RESET_VEC + 304, 1, "stress cycle 16 redirect fetch");
        expect_pipe (PC_RESET_VEC + 304, 1, "stress cycle 16 redirect pipe");

        ex_mispredict   = 1;
        ex_correct_pc   = PC_RESET_VEC + 400;
        if2_redirect    = 1;
        if2_redirect_pc = PC_RESET_VEC + 500;
        step();
        expect_fetch(PC_RESET_VEC + 404, 0, "stress cycle 17 ex priority fetch");
        expect_pipe (PC_RESET_VEC + 404, 1, "stress cycle 17 ex priority pipe");

        ex_mispredict   = 0;
        if2_redirect    = 0;
        step();
        expect_fetch(PC_RESET_VEC + 408, 1, "stress cycle 18 recover fetch");
        expect_pipe (PC_RESET_VEC + 408, 0, "stress cycle 18 recover pipe");

        $display("--------------------------------------------------");
        $display("FCU1_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------------");

        if (fail_count == 0)
            $display("FCU1_TB PASS");
        else
            $display("FCU1_TB FAIL");

        $finish;
    end
endmodule
