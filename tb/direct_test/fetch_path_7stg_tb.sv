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
// Module       : fetch_path_7stg_tb
// Description  : Integration TB for FCU1, IF1/IF2, I-Cache, DBP, and FCU2.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-22
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module fetch_path_7stg_tb;
    import cpu_pkg::*;

    //system
    logic clk;
    logic rst_n;

    //FCU1 -> I-cache / IF1
    logic                    if_req;
    logic [ADDR_WIDTH-1:0]   if_pc;
    logic [ADDR_WIDTH-1:0]   if1_if2_pc;
    logic                    if1_if2_flush;

    //IF1/IF2 -> IF2
    logic [ADDR_WIDTH-1:0]   if2_pc;
    logic                    if2_valid;

    //I-cache -> FCU2
    logic [DATA_WIDTH-1:0]   icache_instr;
    logic                    icache_ready;
    logic                    icache_valid;

    //I-cache arbiter stub
    logic [DATA_WIDTH-1:0]   arb_rdata;
    logic                    arb_valid;
    logic                    arb_last;
    logic                    arb_grant;
    logic                    icache_req;
    logic [ADDR_WIDTH-1:0]   icache_addr;

    //DBP -> FCU2
    logic                    pred_taken;
    logic [ADDR_WIDTH-1:0]   pred_target;

    //EX/HDU stubs
    logic                    ex_mispredict;
    logic [ADDR_WIDTH-1:0]   ex_correct_pc;
    logic                    stall;
    logic                    ex_update_en;
    logic [ADDR_WIDTH-1:0]   ex_pc;
    logic                    ex_actual_taken;
    logic [ADDR_WIDTH-1:0]   ex_actual_target;

    //FCU2 -> FCU1 / observe
    logic                    cache_advance;
    logic                    if2_redirect;
    logic [ADDR_WIDTH-1:0]   if2_redirect_pc;
    logic [DATA_WIDTH-1:0]   instr_o;
    logic                    if2_id_pred_taken;
    logic [ADDR_WIDTH-1:0]   if2_id_pred_target;
    logic                    if2_id_flush;

    logic accept_instr;
    assign accept_instr = if2_valid && icache_valid && !if2_id_flush && !stall;

    fcu1 u_fcu1 (
        .clk             (clk),
        .rst_n           (rst_n),
        .if_req          (if_req),
        .if_pc           (if_pc),
        .ex_mispredict   (ex_mispredict),
        .ex_correct_pc   (ex_correct_pc),
        .stall           (stall),
        .if1_if2_pc      (if1_if2_pc),
        .if1_if2_flush   (if1_if2_flush),
        .if2_redirect    (if2_redirect),
        .if2_redirect_pc (if2_redirect_pc),
        .cache_advance   (cache_advance)
    );

    if1_if2_pipeline u_if1_if2 (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall       (stall),
        .flush       (if1_if2_flush),
        .if1_pc_i    (if1_if2_pc),
        .if1_valid_i (if_req),
        .if2_pc_o    (if2_pc),
        .if2_valid_o (if2_valid)
    );

    icache_7stg u_icache (
        .clk          (clk),
        .rst_n        (rst_n),
        .pc           (if_pc),
        .if_req       (if_req),
        .instr        (icache_instr),
        .icache_ready (icache_ready),
        .icache_valid (icache_valid),
        .flush_refill (if1_if2_flush),
        .arb_rdata    (arb_rdata),
        .arb_valid    (arb_valid),
        .arb_last     (arb_last),
        .arb_grant    (arb_grant),
        .icache_req   (icache_req),
        .icache_addr  (icache_addr)
    );

    dbp_7stg u_dbp (
        .clk              (clk),
        .rst_n            (rst_n),
        .if1_pc           (if_pc),
        .if1_valid        (if_req),
        .stall            (stall),
        .flush            (if1_if2_flush),
        .pred_taken       (pred_taken),
        .pred_target      (pred_target),
        .ex_update_en     (ex_update_en),
        .ex_pc            (ex_pc),
        .ex_actual_taken  (ex_actual_taken),
        .ex_actual_target (ex_actual_target)
    );

    fcu2 u_fcu2 (
        .clk                 (clk),
        .rst_n               (rst_n),
        .instr_i             (icache_instr),
        .cache_valid         (icache_valid),
        .cache_ready         (icache_ready),
        .if2_valid           (if2_valid),
        .pred_taken          (pred_taken),
        .pred_target         (pred_target),
        .ex_mispredict       (ex_mispredict),
        .cache_advance       (cache_advance),
        .if2_redirect        (if2_redirect),
        .if2_redirect_pc     (if2_redirect_pc),
        .stall               (stall),
        .instr_o             (instr_o),
        .if2_id_pred_taken   (if2_id_pred_taken),
        .if2_id_pred_target  (if2_id_pred_target),
        .if2_id_flush        (if2_id_flush)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    localparam int MAX_WAIT = 80;

    localparam logic [ADDR_WIDTH-1:0] PC_0   = 32'h0000_0000;
    localparam logic [ADDR_WIDTH-1:0] PC_4   = 32'h0000_0004;
    localparam logic [ADDR_WIDTH-1:0] PC_8   = 32'h0000_0008;
    localparam logic [ADDR_WIDTH-1:0] PC_C   = 32'h0000_000c;
    localparam logic [ADDR_WIDTH-1:0] PC_40  = 32'h0000_0040;
    localparam logic [ADDR_WIDTH-1:0] PC_80  = 32'h0000_0080;
    localparam logic [ADDR_WIDTH-1:0] PC_84  = 32'h0000_0084;
    localparam logic [ADDR_WIDTH-1:0] PC_88  = 32'h0000_0088;

    int pass_count;
    int fail_count;

    function automatic logic [DATA_WIDTH-1:0] rom_word(input logic [ADDR_WIDTH-1:0] addr);
        begin
            case (addr)
                32'h0000_0000: rom_word = 32'h0000_0013;
                32'h0000_0004: rom_word = 32'h0010_0093;
                32'h0000_0008: rom_word = 32'h0020_0113;
                32'h0000_000c: rom_word = 32'h0030_0193;
                32'h0000_0040: rom_word = 32'h0400_0063;
                32'h0000_0044: rom_word = 32'h0040_0213;
                32'h0000_0048: rom_word = 32'h0050_0293;
                32'h0000_004c: rom_word = 32'h0060_0313;
                32'h0000_0080: rom_word = 32'h0800_0063;
                32'h0000_0084: rom_word = 32'h0070_0393;
                32'h0000_0088: rom_word = 32'h0080_0413;
                32'h0000_008c: rom_word = 32'h0090_0493;
                default:       rom_word = 32'h0000_0013;
            endcase
        end
    endfunction

    //simple refill responder
    typedef enum logic [1:0] {
        ARB_IDLE,
        ARB_DATA
    } arb_state_t;

    arb_state_t              arb_state;
    logic [1:0]              beat_count;
    logic [ADDR_WIDTH-1:0]   refill_base;
    logic [ADDR_WIDTH-1:0]   beat_addr;

    assign beat_addr = {refill_base[ADDR_WIDTH-1:4], beat_count, 2'b00};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arb_state   <= ARB_IDLE;
            arb_grant   <= 1'b0;
            arb_valid   <= 1'b0;
            arb_last    <= 1'b0;
            arb_rdata   <= '0;
            beat_count  <= '0;
            refill_base <= '0;
        end else begin
            arb_grant <= 1'b0;
            arb_valid <= 1'b0;
            arb_last  <= 1'b0;

            case (arb_state)
                ARB_IDLE: begin
                    if (icache_req) begin
                        arb_grant   <= 1'b1;
                        refill_base <= {icache_addr[ADDR_WIDTH-1:4], 4'b0000};
                        beat_count  <= 2'd0;
                        arb_state   <= ARB_DATA;
                    end
                end

                ARB_DATA: begin
                    arb_valid <= 1'b1;
                    arb_rdata <= rom_word(beat_addr);
                    arb_last  <= (beat_count == 2'd3);

                    if (beat_count == 2'd3)
                        arb_state <= ARB_IDLE;
                    else
                        beat_count <= beat_count + 2'd1;
                end
            endcase
        end
    end

    task automatic drive_idle;
        begin
            ex_mispredict    = 1'b0;
            ex_correct_pc    = '0;
            stall            = 1'b0;
            ex_update_en     = 1'b0;
            ex_pc            = '0;
            ex_actual_taken  = 1'b0;
            ex_actual_target = '0;
        end
    endtask

    task automatic reset_dut;
        begin
            drive_idle();
            stall = 1'b1;
            rst_n = 1'b0;
            repeat (3) @(posedge clk);
            #1;
            rst_n = 1'b1;
            repeat (2) @(posedge clk);
            #1;
            stall = 1'b0;
        end
    endtask

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic mark_pass(input string desc);
        begin
            $display("PASS | %s", desc);
            pass_count++;
        end
    endtask

    task automatic mark_fail(input string desc);
        begin
            $display("FAIL | %s", desc);
            fail_count++;
        end
    endtask

    task automatic expect_fetch_req;
        input logic  exp_req;
        input string desc;
        begin
            #1;
            if (if_req === exp_req)
                mark_pass(desc);
            else begin
                $display("FAIL | %s", desc);
                $display("       if_req: got=%0b exp=%0b", if_req, exp_req);
                fail_count++;
            end
        end
    endtask

    task automatic expect_fire;
        input logic [ADDR_WIDTH-1:0] exp_pc;
        input logic [DATA_WIDTH-1:0] exp_instr;
        input string                 desc;
        int                          i;
        begin
            for (i = 0; i < MAX_WAIT; i++) begin
                #1;
                if (accept_instr) begin
                    if ((if2_pc === exp_pc) && (instr_o === exp_instr)) begin
                        $display("PASS | %-45s pc=%h instr=%h redir=%0b target=%h",
                                 desc, if2_pc, instr_o, if2_redirect, if2_redirect_pc);
                        pass_count++;
                    end else begin
                        $display("FAIL | %s", desc);
                        if (if2_pc !== exp_pc)
                            $display("       pc    : got=%h exp=%h", if2_pc, exp_pc);
                        if (instr_o !== exp_instr)
                            $display("       instr : got=%h exp=%h", instr_o, exp_instr);
                        $display("       redir : got=%0b target=%h", if2_redirect, if2_redirect_pc);
                        fail_count++;
                    end
                    step();
                    return;
                end
                step();
            end

            $display("FAIL | %s", desc);
            $display("       timeout waiting for accepted instr pc=%h", exp_pc);
            fail_count++;
        end
    endtask

    task automatic expect_fire_redirect;
        input logic [ADDR_WIDTH-1:0] exp_pc;
        input logic [DATA_WIDTH-1:0] exp_instr;
        input logic                  exp_redirect;
        input logic [ADDR_WIDTH-1:0] exp_redirect_pc;
        input string                 desc;
        int                          i;
        begin
            for (i = 0; i < MAX_WAIT; i++) begin
                #1;
                if (accept_instr) begin
                    if ((if2_pc === exp_pc) &&
                        (instr_o === exp_instr) &&
                        (if2_redirect === exp_redirect) &&
                        (if2_redirect_pc === exp_redirect_pc)) begin
                        $display("PASS | %-45s pc=%h instr=%h redir=%0b target=%h",
                                 desc, if2_pc, instr_o, if2_redirect, if2_redirect_pc);
                        pass_count++;
                    end else begin
                        $display("FAIL | %s", desc);
                        if (if2_pc !== exp_pc)
                            $display("       pc        : got=%h exp=%h", if2_pc, exp_pc);
                        if (instr_o !== exp_instr)
                            $display("       instr     : got=%h exp=%h", instr_o, exp_instr);
                        if (if2_redirect !== exp_redirect)
                            $display("       redirect  : got=%0b exp=%0b", if2_redirect, exp_redirect);
                        if (if2_redirect_pc !== exp_redirect_pc)
                            $display("       redir_pc  : got=%h exp=%h", if2_redirect_pc, exp_redirect_pc);
                        fail_count++;
                    end
                    step();
                    return;
                end
                step();
            end

            $display("FAIL | %s", desc);
            $display("       timeout waiting for accepted instr pc=%h", exp_pc);
            fail_count++;
        end
    endtask

    task automatic train_dbp_taken;
        input logic [ADDR_WIDTH-1:0] train_pc;
        input logic [ADDR_WIDTH-1:0] train_target;
        begin
            repeat (2) begin
                @(negedge clk);
                ex_update_en     = 1'b1;
                ex_pc            = train_pc;
                ex_actual_taken  = 1'b1;
                ex_actual_target = train_target;
                @(posedge clk);
                #1;
                ex_update_en     = 1'b0;
                ex_actual_taken  = 1'b0;
                ex_actual_target = '0;
            end
        end
    endtask

    task automatic pulse_ex_redirect;
        input logic [ADDR_WIDTH-1:0] target_pc;
        begin
            @(negedge clk);
            ex_mispredict = 1'b1;
            ex_correct_pc = target_pc;
            @(posedge clk);
            #1;
            ex_mispredict = 1'b0;
            ex_correct_pc = '0;
        end
    endtask

    task automatic expect_ex_override_on_pc;
        input logic [ADDR_WIDTH-1:0] observe_pc;
        input logic [ADDR_WIDTH-1:0] correct_pc;
        input string                 desc;
        int                          i;
        begin
            for (i = 0; i < MAX_WAIT; i++) begin
                #1;
                if (if2_valid && icache_valid && (if2_pc == observe_pc)) begin
                    ex_mispredict = 1'b1;
                    ex_correct_pc = correct_pc;
                    #1;

                    if ((if2_redirect === 1'b0) && (if2_id_flush === 1'b1)) begin
                        $display("PASS | %-45s pc=%h correct_pc=%h", desc, if2_pc, correct_pc);
                        pass_count++;
                    end else begin
                        $display("FAIL | %s", desc);
                        $display("       if2_redirect: got=%0b exp=0", if2_redirect);
                        $display("       if2_id_flush: got=%0b exp=1", if2_id_flush);
                        fail_count++;
                    end

                    step();
                    ex_mispredict = 1'b0;
                    ex_correct_pc = '0;
                    return;
                end
                step();
            end

            $display("FAIL | %s", desc);
            $display("       timeout waiting for IF2 pc=%h", observe_pc);
            fail_count++;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        //Test 1: cold fetch refills line 0 and should retire PC0 once, then PC4/PC8/PC12.
        reset_dut();
        expect_fire(PC_0, rom_word(PC_0), "T1 refill/CWF accepts PC0");
        expect_fire(PC_4, rom_word(PC_4), "T1 next accepted PC is PC4");
        expect_fire(PC_8, rom_word(PC_8), "T1 next accepted PC is PC8");
        expect_fire(PC_C, rom_word(PC_C), "T1 next accepted PC is PC12");

        //Test 2: stall blocks new fetch request.
        stall = 1'b1;
        expect_fetch_req(1'b0, "T2 stall blocks if_req");
        step();
        expect_fetch_req(1'b0, "T2 stall keeps if_req blocked");
        stall = 1'b0;
        step();

        //Test 3: DBP trained taken branch redirects from IF2 to target.
        stall = 1'b1;
        train_dbp_taken(PC_0, PC_40);
        stall = 1'b0;
        pulse_ex_redirect(PC_0);
        expect_fire_redirect(PC_0, rom_word(PC_0), 1'b1, PC_40, "T3 DBP taken redirects PC0");
        expect_fire(PC_40, rom_word(PC_40), "T3 target PC40 fetched");

        //Test 4: EX mispredict overrides IF2 redirect.
        stall = 1'b1;
        train_dbp_taken(PC_4, PC_40);
        stall = 1'b0;
        pulse_ex_redirect(PC_4);
        expect_ex_override_on_pc(PC_4, PC_80, "T4 EX override blocks IF2 redirect");
        expect_fire(PC_80, rom_word(PC_80), "T4 EX correct PC80 fetched");

        //Test 5: redirected target line continues sequentially after refill.
        expect_fire(PC_84, rom_word(PC_84), "T5 target line PC84 fetched");
        expect_fire(PC_88, rom_word(PC_88), "T5 target line PC88 fetched");

        $display("--------------------------------------------------");
        $display("FETCH_PATH_7STG_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------------");

        if (fail_count == 0)
            $display("FETCH_PATH_7STG_TB PASS");
        else
            $display("FETCH_PATH_7STG_TB FAIL");

        $finish;
    end
endmodule
