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
// Module       : dcache_7stg_tb
// Description  : Directed tests for 7-stage D-Cache standalone behavior.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-23
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module dcache_7stg_tb;
    import cache_pkg::*;

    //system
    logic clk;
    logic rst_n;

    //LSU interface
    logic [ADDR_WIDTH-1:0]    addr;
    logic                     mem_req;
    logic                     mem_we;
    logic [DATA_WIDTH-1:0]    wdata;
    logic [STRB_WIDTH-1:0]    wstrb;
    logic [DATA_WIDTH-1:0]    rdata;
    logic                     dcache_ready;
    logic                     dcache_valid;

    //write-buffer push
    logic                     wb_push;
    logic [ADDR_WIDTH-1:0]    wb_addr;
    logic [DATA_WIDTH-1:0]    wb_data;
    logic [STRB_WIDTH-1:0]    wb_strb;
    logic                     wb_full;

    //write-buffer forwarding
    logic [ADDR_WIDTH-1:0]    fwd_addr;
    logic                     fwd_hit;
    logic [DATA_WIDTH-1:0]    fwd_data;
    logic [STRB_WIDTH-1:0]    fwd_strb;

    //arbiter interface
    logic [DATA_WIDTH-1:0]    arb_rdata;
    logic                     arb_valid;
    logic                     arb_last;
    logic                     arb_grant;
    logic                     dcache_req;
    logic [ADDR_WIDTH-1:0]    dcache_addr;

    //DUT
    dcache_7stg dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .addr          (addr),
        .mem_req       (mem_req),
        .mem_we        (mem_we),
        .wdata         (wdata),
        .wstrb         (wstrb),
        .rdata         (rdata),
        .dcache_ready  (dcache_ready),
        .dcache_valid  (dcache_valid),
        .wb_push       (wb_push),
        .wb_addr       (wb_addr),
        .wb_data       (wb_data),
        .wb_strb       (wb_strb),
        .wb_full       (wb_full),
        .fwd_addr      (fwd_addr),
        .fwd_hit       (fwd_hit),
        .fwd_data      (fwd_data),
        .fwd_strb      (fwd_strb),
        .arb_rdata     (arb_rdata),
        .arb_valid     (arb_valid),
        .arb_last      (arb_last),
        .arb_grant     (arb_grant),
        .dcache_req    (dcache_req),
        .dcache_addr   (dcache_addr)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    localparam int MAX_WAIT = 40;

    localparam logic [ADDR_WIDTH-1:0] ADDR_A0 = 32'h0000_1000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A1 = 32'h0000_1004;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A2 = 32'h0000_1008;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A3 = 32'h0000_100c;
    localparam logic [ADDR_WIDTH-1:0] ADDR_B0 = 32'h0000_2000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_C0 = 32'h0000_3000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_D0 = 32'h0000_4000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_U0 = 32'h1000_0000;

    int pass_count;
    int fail_count;

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic drive_idle;
        begin
            addr      = '0;
            mem_req   = 1'b0;
            mem_we    = 1'b0;
            wdata     = '0;
            wstrb     = '0;
            wb_full   = 1'b0;
            fwd_hit   = 1'b0;
            fwd_data  = '0;
            fwd_strb  = '0;
            arb_rdata = '0;
            arb_valid = 1'b0;
            arb_last  = 1'b0;
            arb_grant = 1'b0;
        end
    endtask

    task automatic reset_dut;
        begin
            drive_idle();
            rst_n = 1'b0;
            repeat (3) step();
            rst_n = 1'b1;
            step();
        end
    endtask

    function automatic logic [ADDR_WIDTH-1:0] word_base(input logic [ADDR_WIDTH-1:0] a);
        begin
            word_base = a & {{(ADDR_WIDTH-WORD_OFF_BITS){1'b1}}, {WORD_OFF_BITS{1'b0}}};
        end
    endfunction

    function automatic logic [DATA_WIDTH-1:0] select_line_word;
        input logic [1:0] sel;
        input logic [DATA_WIDTH-1:0] w0;
        input logic [DATA_WIDTH-1:0] w1;
        input logic [DATA_WIDTH-1:0] w2;
        input logic [DATA_WIDTH-1:0] w3;
        begin
            case (sel)
                2'd0: select_line_word = w0;
                2'd1: select_line_word = w1;
                2'd2: select_line_word = w2;
                2'd3: select_line_word = w3;
            endcase
        end
    endfunction

    task automatic pass_msg;
        input string desc;
        begin
            $display("PASS | %s", desc);
            pass_count++;
        end
    endtask

    task automatic fail_msg;
        input string desc;
        begin
            $display("FAIL | %s", desc);
            fail_count++;
        end
    endtask

    task automatic expect_ctrl;
        input logic  exp_valid;
        input logic  exp_ready;
        input string desc;
        begin
            if ((dcache_valid === exp_valid) &&
                (dcache_ready === exp_ready)) begin
                $display("PASS | %-46s valid=%0b ready=%0b", desc, dcache_valid, dcache_ready);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (dcache_valid !== exp_valid)
                    $display("       dcache_valid: got=%0b exp=%0b", dcache_valid, exp_valid);
                if (dcache_ready !== exp_ready)
                    $display("       dcache_ready: got=%0b exp=%0b", dcache_ready, exp_ready);
                fail_count++;
            end
        end
    endtask

    task automatic expect_data;
        input logic [DATA_WIDTH-1:0] exp_rdata;
        input string                 desc;
        begin
            if (rdata === exp_rdata) begin
                $display("PASS | %-46s rdata=%h", desc, rdata);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                $display("       rdata: got=%h exp=%h", rdata, exp_rdata);
                fail_count++;
            end
        end
    endtask

    task automatic expect_wb;
        input logic                  exp_push;
        input logic [ADDR_WIDTH-1:0] exp_addr;
        input logic [DATA_WIDTH-1:0] exp_data;
        input logic [STRB_WIDTH-1:0] exp_strb;
        input string                 desc;
        begin
            if ((wb_push === exp_push) &&
                (!exp_push ||
                 ((wb_addr === exp_addr) &&
                  (wb_data === exp_data) &&
                  (wb_strb === exp_strb)))) begin
                $display("PASS | %-46s push=%0b addr=%h data=%h strb=%04b",
                         desc, wb_push, wb_addr, wb_data, wb_strb);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (wb_push !== exp_push) $display("       wb_push: got=%0b exp=%0b", wb_push, exp_push);
                if (exp_push && (wb_addr !== exp_addr)) $display("       wb_addr: got=%h exp=%h", wb_addr, exp_addr);
                if (exp_push && (wb_data !== exp_data)) $display("       wb_data: got=%h exp=%h", wb_data, exp_data);
                if (exp_push && (wb_strb !== exp_strb)) $display("       wb_strb: got=%04b exp=%04b", wb_strb, exp_strb);
                fail_count++;
            end
        end
    endtask

    task automatic expect_bus_req;
        input logic [ADDR_WIDTH-1:0] exp_addr;
        input string                 desc;
        begin
            if ((dcache_req === 1'b1) &&
                (dcache_addr === exp_addr)) begin
                $display("PASS | %-46s req=1 addr=%h", desc, dcache_addr);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (dcache_req !== 1'b1)       $display("       dcache_req : got=%0b exp=1", dcache_req);
                if (dcache_addr !== exp_addr)  $display("       dcache_addr: got=%h exp=%h", dcache_addr, exp_addr);
                fail_count++;
            end
        end
    endtask

    task automatic wait_bus_req;
        input logic [ADDR_WIDTH-1:0] exp_addr;
        input string                 desc;
        int waited;
        bit seen;
        begin
            waited = 0;
            seen   = 1'b0;
            while ((waited < MAX_WAIT) && !seen) begin
                if (dcache_req)
                    seen = 1'b1;
                else begin
                    step();
                    waited++;
                end
            end

            if (seen)
                expect_bus_req(exp_addr, desc);
            else
                fail_msg(desc);
        end
    endtask

    task automatic launch_load;
        input logic [ADDR_WIDTH-1:0] t_addr;
        input string                 desc;
        begin
            addr    = t_addr;
            mem_req = 1'b1;
            mem_we  = 1'b0;
            wdata   = '0;
            wstrb   = '0;
            step();
            mem_req = 1'b0;
            mem_we  = 1'b0;
            $display("INFO | %-46s addr=%h", desc, t_addr);
        end
    endtask

    task automatic launch_store;
        input logic [ADDR_WIDTH-1:0] t_addr;
        input logic [DATA_WIDTH-1:0] t_wdata;
        input logic [STRB_WIDTH-1:0] t_wstrb;
        input string                 desc;
        begin
            addr    = t_addr;
            mem_req = 1'b1;
            mem_we  = 1'b1;
            wdata   = t_wdata;
            wstrb   = t_wstrb;
            step();
            mem_req = 1'b0;
            mem_we  = 1'b0;
            $display("INFO | %-46s addr=%h data=%h strb=%04b", desc, t_addr, t_wdata, t_wstrb);
        end
    endtask

    task automatic accept_refill;
        begin
            arb_grant = 1'b1;
            step();
            arb_grant = 1'b0;
        end
    endtask

    task automatic send_refill_line;
        input logic [ADDR_WIDTH-1:0] t_req_addr;
        input logic [DATA_WIDTH-1:0] w0;
        input logic [DATA_WIDTH-1:0] w1;
        input logic [DATA_WIDTH-1:0] w2;
        input logic [DATA_WIDTH-1:0] w3;
        input logic                  exp_cwf;
        input logic [DATA_WIDTH-1:0] exp_cwf_data;
        input string                 desc;
        logic [1:0] start_sel;
        logic [1:0] beat_sel;
        begin
            start_sel = t_req_addr[WORD_OFF_BITS +: WORD_SEL_BITS];

            wait_bus_req(word_base(t_req_addr), {desc, " bus request"});
            accept_refill();

            for (int beat = 0; beat < WORDS_PER_LINE; beat++) begin
                beat_sel  = start_sel + beat[1:0];
                arb_valid = 1'b1;
                arb_last  = (beat == WORDS_PER_LINE-1);
                arb_rdata = select_line_word(beat_sel, w0, w1, w2, w3);
                step();

                if (beat == 0) begin
                    if (exp_cwf) begin
                        expect_ctrl(1'b1, 1'b0, {desc, " first beat CWF ctrl"});
                        expect_data(exp_cwf_data, {desc, " first beat CWF data"});
                    end else begin
                        expect_ctrl(1'b0, 1'b0, {desc, " first beat no CWF"});
                    end
                end
            end

            arb_valid = 1'b0;
            arb_last  = 1'b0;
            arb_rdata = '0;

            //wait for both 64-bit commit writes
            do begin
                step();
            end while (!dcache_ready);
            expect_ctrl(1'b0, 1'b1, {desc, " refill committed"});
        end
    endtask

    task automatic expect_no_bus_req_next_cycle;
        input string desc;
        begin
            step();
            if (dcache_req === 1'b0)
                pass_msg(desc);
            else begin
                $display("FAIL | %s", desc);
                $display("       dcache_req=%0b dcache_addr=%h", dcache_req, dcache_addr);
                fail_count++;
            end
        end
    endtask

    task automatic run_uncacheable_load;
        input logic [ADDR_WIDTH-1:0] t_addr;
        input logic [DATA_WIDTH-1:0] exp_data;
        bit saw_valid;
        begin
            saw_valid = 1'b0;

            launch_load(t_addr, "T8 uncacheable load miss");
            expect_ctrl(1'b0, 1'b0, "T8 uncacheable miss stalls");

            wait_bus_req(word_base(t_addr), "T8 uncacheable bus request");
            accept_refill();

            for (int beat = 0; beat < WORDS_PER_LINE; beat++) begin
                arb_valid = 1'b1;
                arb_last  = (beat == WORDS_PER_LINE-1);
                arb_rdata = (beat == 0) ? exp_data : (32'h1BAD_0000 + beat[31:0]);
                step();

                if (dcache_valid && (rdata === exp_data))
                    saw_valid = 1'b1;
            end

            arb_valid = 1'b0;
            arb_last  = 1'b0;
            arb_rdata = '0;

            step();
            if (dcache_valid && (rdata === exp_data))
                saw_valid = 1'b1;

            if (saw_valid)
                pass_msg("T8 uncacheable load returns refill data");
            else
                fail_msg("T8 uncacheable load returns refill data");

            expect_ctrl(1'b0, 1'b1, "T8 uncacheable returns idle");
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        reset_dut();
        expect_ctrl(1'b0, 1'b1, "reset idle ready");

        //1. load miss, refill, critical-word-first response
        launch_load(ADDR_A0, "T1 load miss A0");
        expect_ctrl(1'b0, 1'b0, "T1 miss enters refill path");
        send_refill_line(ADDR_A0,
                         32'hAAA0_0000,
                         32'hAAA0_0001,
                         32'hAAA0_0002,
                         32'hAAA0_0003,
                         1'b1,
                         32'hAAA0_0000,
                         "T1 refill line A");

        //2. load hit after refill
        launch_load(ADDR_A3, "T2 load hit A3");
        expect_ctrl(1'b1, 1'b1, "T2 hit ctrl");
        expect_data(32'hAAA0_0003, "T2 hit data word3");
        step();

        //verify all word positions across both 64-bit pairs
        launch_load(ADDR_A0, "T2b load hit A0");
        expect_data(32'hAAA0_0000, "T2b hit data word0");
        step();
        launch_load(ADDR_A1, "T2c load hit A1");
        expect_data(32'hAAA0_0001, "T2c hit data word1");
        step();
        launch_load(ADDR_A2, "T2d load hit A2");
        expect_data(32'hAAA0_0002, "T2d hit data word2");
        step();

        //3. store miss: push write buffer, do not allocate cache line
        launch_store(ADDR_B0, 32'hBEEF_1234, 4'b1111, "T3 store miss B0");
        expect_ctrl(1'b1, 1'b1, "T3 store miss accepted");
        expect_wb(1'b1, word_base(ADDR_B0), 32'hBEEF_1234, 4'b1111, "T3 store miss wb push");
        step();

        launch_load(ADDR_B0, "T3b load after store miss no fwd");
        expect_ctrl(1'b0, 1'b0, "T3b proves store miss did not allocate");
        send_refill_line(ADDR_B0,
                         32'hBBB0_0000,
                         32'hBBB0_0001,
                         32'hBBB0_0002,
                         32'hBBB0_0003,
                         1'b1,
                         32'hBBB0_0000,
                         "T3b refill line B");

        //same set, second way, both word pairs
        launch_load(ADDR_B0, "T3c load way1 pair0");
        expect_data(32'hBBB0_0000, "T3c way1 word0");
        step();
        launch_load(ADDR_B0 + 8, "T3d load way1 pair1");
        expect_data(32'hBBB0_0002, "T3d way1 word2");
        step();

        //4. store hit: update cache SRAM, then push write buffer in STORE_DONE
        launch_store(ADDR_A1, 32'h1234_5678, 4'b0011, "T4 store hit A1");
        expect_ctrl(1'b0, 1'b0, "T4 store hit update cycle");
        expect_wb(1'b0, '0, '0, '0, "T4 no wb push during update");
        step();
        expect_ctrl(1'b1, 1'b1, "T4 store hit done ctrl");
        expect_wb(1'b1, word_base(ADDR_A1), 32'h1234_5678, 4'b0011, "T4 store hit wb push");
        step();

        launch_load(ADDR_A1, "T4b load updated A1");
        expect_ctrl(1'b1, 1'b1, "T4b updated hit ctrl");
        expect_data(32'hAAA0_5678, "T4b updated hit data");
        step();

        launch_load(ADDR_A0, "T4c pair neighbor preserved");
        expect_data(32'hAAA0_0000, "T4c A0 unchanged after A1 SH");
        step();

        //upper pair byte store and neighbor preservation
        launch_store(ADDR_A2, 32'h12AB_5678, 4'b0100, "T4d store hit A2 byte");
        expect_ctrl(1'b0, 1'b0, "T4d store hit update cycle");
        step();
        expect_wb(1'b1, word_base(ADDR_A2), 32'h12AB_5678, 4'b0100, "T4d store hit wb push");
        step();
        launch_load(ADDR_A2, "T4e load byte-updated A2");
        expect_data(32'hAAAB_0002, "T4e A2 byte update");
        step();
        launch_load(ADDR_A3, "T4f upper pair neighbor preserved");
        expect_data(32'hAAA0_0003, "T4f A3 unchanged after A2 SB");
        step();

        //full-word store on second way
        launch_store(ADDR_B0, 32'hDEAD_BEEF, 4'b1111, "T4g store hit B0 word");
        expect_ctrl(1'b0, 1'b0, "T4g store hit update cycle");
        step();
        expect_wb(1'b1, word_base(ADDR_B0), 32'hDEAD_BEEF, 4'b1111, "T4g store hit wb push");
        step();
        launch_load(ADDR_B0, "T4h load word-updated B0");
        expect_data(32'hDEAD_BEEF, "T4h B0 word update");
        step();
        launch_load(ADDR_B0 + 4, "T4i lower pair neighbor preserved");
        expect_data(32'hBBB0_0001, "T4i B1 unchanged after B0 SW");
        step();

        //5. partial write-buffer forwarding merges with cache-hit word
        fwd_hit  = 1'b1;
        fwd_data = 32'h1122_3344;
        fwd_strb = 4'b0101;
        launch_load(ADDR_A2, "T5 partial forwarding on hit");
        expect_ctrl(1'b1, 1'b1, "T5 partial fwd hit ctrl");
        expect_data(32'hAA22_0044, "T5 partial fwd merged data");
        step();
        fwd_hit  = 1'b0;
        fwd_data = '0;
        fwd_strb = '0;

        //6. full write-buffer forwarding can satisfy cache miss without refill
        fwd_hit  = 1'b1;
        fwd_data = 32'hFEED_C0DE;
        fwd_strb = 4'b1111;
        launch_load(ADDR_C0, "T6 full forwarding on miss");
        expect_ctrl(1'b1, 1'b1, "T6 full fwd miss ctrl");
        expect_data(32'hFEED_C0DE, "T6 full fwd miss data");
        expect_no_bus_req_next_cycle("T6 full fwd miss no refill request");
        fwd_hit  = 1'b0;
        fwd_data = '0;
        fwd_strb = '0;

        //7. wb_full stalls store until buffer can accept push
        wb_full = 1'b1;
        launch_store(ADDR_D0, 32'hDADA_0001, 4'b1111, "T7 store waits on wb_full");
        expect_ctrl(1'b0, 1'b0, "T7 store stalled by wb_full");
        expect_wb(1'b0, '0, '0, '0, "T7 no push while wb_full");
        wb_full = 1'b0;
        #1;
        expect_ctrl(1'b1, 1'b1, "T7 store resumes after wb_full clears");
        expect_wb(1'b1, word_base(ADDR_D0), 32'hDADA_0001, 4'b1111, "T7 resumed wb push");
        step();

        //8. uncacheable load should return data but not allocate
        run_uncacheable_load(ADDR_U0, 32'h1BAD_C0DE);

        $display("--------------------------------------------");
        $display("DCACHE_7STG_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------");

        if (fail_count == 0)
            $display("DCACHE_7STG_TB PASS");
        else
            $display("DCACHE_7STG_TB FAIL");

        $finish;
    end
endmodule
