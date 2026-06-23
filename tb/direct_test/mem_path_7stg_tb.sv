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
// Module       : mem_path_7stg_tb
// Description  : Integration TB for LSU1, MEM1/MEM2, D-Cache, WB forward, LSU2.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-23
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module mem_path_7stg_tb;
    import cpu_pkg::*;
    import cache_pkg::STRB_WIDTH;
    import cache_pkg::WORD_OFF_BITS;
    import cache_pkg::WORD_SEL_BITS;
    import cache_pkg::WORDS_PER_LINE;

    //system
    logic clk;
    logic rst_n;

    //MEM1 stimulus
    logic [ADDR_WIDTH-1:0]    mem1_addr;
    logic                     mem1_req;
    logic                     mem1_we;
    logic [2:0]               mem1_size;
    logic [DATA_WIDTH-1:0]    mem1_wdata;

    //LSU1 -> D-Cache
    logic [ADDR_WIDTH-1:0]    dc_addr;
    logic                     dc_req;
    logic                     dc_we;
    logic [DATA_WIDTH-1:0]    dc_wdata;
    logic [STRB_WIDTH-1:0]    dc_wstrb;
    logic [1:0]               lsu1_addr_lsb;
    logic [2:0]               lsu1_mem_size;

    //MEM1/MEM2 metadata
    logic                     mem_pipe_stall;
    logic [DATA_WIDTH-1:0]    mem2_alu_result;
    logic [DATA_WIDTH-1:0]    mem2_rdata2;
    logic [ADDR_WIDTH-1:0]    mem2_pc;
    logic                     mem2_req;
    logic                     mem2_we;
    logic [2:0]               mem2_size;
    logic [1:0]               mem2_addr_lsb;
    logic                     mem2_reg_we;
    logic [1:0]               mem2_wb_sel;
    logic [4:0]               mem2_rd;

    //D-Cache -> LSU2
    logic [DATA_WIDTH-1:0]    dc_rdata;
    logic                     dc_valid;
    logic                     dc_ready;
    logic [DATA_WIDTH-1:0]    load_data;
    logic                     load_valid;
    logic                     load_ready;

    //D-Cache <-> write buffer
    logic                     wb_push;
    logic [ADDR_WIDTH-1:0]    wb_push_addr;
    logic [DATA_WIDTH-1:0]    wb_push_data;
    logic [STRB_WIDTH-1:0]    wb_push_strb;
    logic                     wb_full;
    logic [ADDR_WIDTH-1:0]    fwd_addr;
    logic                     fwd_hit;
    logic [DATA_WIDTH-1:0]    fwd_data;
    logic [STRB_WIDTH-1:0]    fwd_strb;
    logic                     wb_req;
    logic [ADDR_WIDTH-1:0]    wb_addr;
    logic [DATA_WIDTH-1:0]    wb_data;
    logic [STRB_WIDTH-1:0]    wb_strb;

    //refill stub
    logic [DATA_WIDTH-1:0]    arb_rdata;
    logic                     arb_valid;
    logic                     arb_last;
    logic                     arb_grant;
    logic                     dcache_req;
    logic [ADDR_WIDTH-1:0]    dcache_addr;

    //Stall after metadata reaches MEM2 and response is not ready yet.
    assign mem_pipe_stall = mem2_req && !load_valid;

    lsu1 u_lsu1 (
        .mem_req      (mem1_req),
        .mem_we       (mem1_we),
        .mem_size     (mem1_size),
        .addr         (mem1_addr),
        .wdata        (mem1_wdata),
        .dc_addr      (dc_addr),
        .dc_req       (dc_req),
        .dc_we        (dc_we),
        .dc_wdata     (dc_wdata),
        .dc_wstrb     (dc_wstrb),
        .addr_lsb     (lsu1_addr_lsb),
        .mem_size_o   (lsu1_mem_size)
    );

    mem1_mem2_pipeline u_mem1_mem2 (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (mem_pipe_stall),
        .flush        (1'b0),
        .alu_result_i (mem1_addr),
        .rdata2_i     (mem1_wdata),
        .pc_i         ('0),
        .mem_req_i    (mem1_req),
        .mem_we_i     (mem1_we),
        .mem_size_i   (lsu1_mem_size),
        .addr_lsb_i   (lsu1_addr_lsb),
        .reg_we_i     (1'b0),
        .wb_sel_i     ('0),
        .rd_i         ('0),
        .alu_result_o (mem2_alu_result),
        .rdata2_o     (mem2_rdata2),
        .pc_o         (mem2_pc),
        .mem_req_o    (mem2_req),
        .mem_we_o     (mem2_we),
        .mem_size_o   (mem2_size),
        .addr_lsb_o   (mem2_addr_lsb),
        .reg_we_o     (mem2_reg_we),
        .wb_sel_o     (mem2_wb_sel),
        .rd_o         (mem2_rd)
    );

    dcache_7stg u_dcache (
        .clk           (clk),
        .rst_n         (rst_n),
        .addr          (dc_addr),
        .mem_req       (dc_req),
        .mem_we        (dc_we),
        .wdata         (dc_wdata),
        .wstrb         (dc_wstrb),
        .rdata         (dc_rdata),
        .dcache_ready  (dc_ready),
        .dcache_valid  (dc_valid),
        .wb_push       (wb_push),
        .wb_addr       (wb_push_addr),
        .wb_data       (wb_push_data),
        .wb_strb       (wb_push_strb),
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

    write_buffer u_write_buffer (
        .clk          (clk),
        .rst_n        (rst_n),
        .push         (wb_push),
        .push_addr    (wb_push_addr),
        .push_data    (wb_push_data),
        .push_strb    (wb_push_strb),
        .wb_full      (wb_full),
        .fwd_addr     (fwd_addr),
        .fwd_hit      (fwd_hit),
        .fwd_data     (fwd_data),
        .fwd_strb     (fwd_strb),
        .fence        (1'b0),
        .fence_done   (),
        .wb_req       (wb_req),
        .wb_addr      (wb_addr),
        .wb_data      (wb_data),
        .wb_strb      (wb_strb),
        .arb_wr_done  (1'b0)
    );

    lsu2 u_lsu2 (
        .dc_rdata   (dc_rdata),
        .dc_valid   (dc_valid),
        .dc_ready   (dc_ready),
        .addr_lsb   (mem2_addr_lsb),
        .mem_size   (mem2_size),
        .mem_rdata  (load_data),
        .mem_valid  (load_valid),
        .mem_ready  (load_ready)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    localparam int MAX_WAIT = 80;

    localparam logic [ADDR_WIDTH-1:0] ADDR_A0 = 32'h0000_1000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A1 = 32'h0000_1001;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A2 = 32'h0000_1002;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A4 = 32'h0000_1004;
    localparam logic [ADDR_WIDTH-1:0] ADDR_B0 = 32'h0000_2000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_C0 = 32'h0000_3000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_C1 = 32'h0000_3001;

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
            mem1_addr  = '0;
            mem1_req   = 1'b0;
            mem1_we    = 1'b0;
            mem1_size  = '0;
            mem1_wdata = '0;
            arb_rdata  = '0;
            arb_valid  = 1'b0;
            arb_last   = 1'b0;
            arb_grant  = 1'b0;
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

    task automatic expect_load;
        input logic [DATA_WIDTH-1:0] exp_data;
        input string                 desc;
        begin
            if ((load_valid === 1'b1) && (load_data === exp_data)) begin
                $display("PASS | %-48s data=%h", desc, load_data);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (load_valid !== 1'b1)
                    $display("       load_valid: got=%0b exp=1", load_valid);
                if (load_data !== exp_data)
                    $display("       load_data : got=%h exp=%h", load_data, exp_data);
                fail_count++;
            end
        end
    endtask

    task automatic expect_bus_req;
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

            if (seen && (dcache_addr === exp_addr)) begin
                $display("PASS | %-48s addr=%h", desc, dcache_addr);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (!seen)
                    $display("       dcache_req was not asserted");
                else
                    $display("       dcache_addr: got=%h exp=%h", dcache_addr, exp_addr);
                fail_count++;
            end
        end
    endtask

    task automatic launch_mem;
        input logic [ADDR_WIDTH-1:0] t_addr;
        input logic                  t_we;
        input logic [2:0]            t_size;
        input logic [DATA_WIDTH-1:0] t_wdata;
        input string                 desc;
        begin
            mem1_addr  = t_addr;
            mem1_req   = 1'b1;
            mem1_we    = t_we;
            mem1_size  = t_size;
            mem1_wdata = t_wdata;
            step();
            mem1_req   = 1'b0;
            mem1_we    = 1'b0;
            mem1_size  = '0;
            mem1_wdata = '0;
            $display("INFO | %-48s addr=%h we=%0b size=%03b", desc, t_addr, t_we, t_size);
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
        input logic [DATA_WIDTH-1:0] exp_first_data;
        input string                 desc;
        logic [1:0] start_sel;
        logic [1:0] beat_sel;
        begin
            start_sel = t_req_addr[WORD_OFF_BITS +: WORD_SEL_BITS];

            expect_bus_req(word_base(t_req_addr), {desc, " bus request"});
            accept_refill();

            for (int beat = 0; beat < WORDS_PER_LINE; beat++) begin
                beat_sel  = start_sel + beat[1:0];
                arb_valid = 1'b1;
                arb_last  = (beat == WORDS_PER_LINE-1);
                arb_rdata = select_line_word(beat_sel, w0, w1, w2, w3);
                step();

                if (beat == 0)
                    expect_load(exp_first_data, {desc, " CWF response"});
            end

            arb_valid = 1'b0;
            arb_last  = 1'b0;
            arb_rdata = '0;
            step();
        end
    endtask

    task automatic wait_load_response;
        input logic [DATA_WIDTH-1:0] exp_data;
        input string                 desc;
        int waited;
        bit seen;
        begin
            waited = 0;
            seen   = 1'b0;

            while ((waited < MAX_WAIT) && !seen) begin
                if (load_valid)
                    seen = 1'b1;
                else begin
                    step();
                    waited++;
                end
            end

            if (seen)
                expect_load(exp_data, desc);
            else
                fail_msg(desc);

            step();
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        reset_dut();

        //1. LW miss: LSU1 launch, D-Cache refill, LSU2 word pass-through.
        launch_mem(ADDR_A0, 1'b0, 3'b010, '0, "T1 LW miss A0");
        send_refill_line(ADDR_A0,
                         32'hAABB_CCDD,
                         32'h1122_3380,
                         32'h5566_AA88,
                         32'h99AA_BBCC,
                         32'hAABB_CCDD,
                         "T1 refill A");

        //2. Subword load hits: metadata must match D-Cache response in MEM2.
        launch_mem(ADDR_A1, 1'b0, 3'b000, '0, "T2 LB hit A1");
        wait_load_response(32'hFFFF_FFCC, "T2 LB sign extend byte1");

        launch_mem(ADDR_A2, 1'b0, 3'b100, '0, "T3 LBU hit A2");
        wait_load_response(32'h0000_00BB, "T3 LBU zero extend byte2");

        launch_mem(ADDR_A2, 1'b0, 3'b001, '0, "T4 LH hit A2");
        wait_load_response(32'hFFFF_AABB, "T4 LH sign extend upper half");

        launch_mem(ADDR_A0, 1'b0, 3'b101, '0, "T5 LHU hit A0");
        wait_load_response(32'h0000_CCDD, "T5 LHU zero extend lower half");

        //3. Store hit through LSU1 byte/half formatting, then load word through LSU2.
        launch_mem(ADDR_A1, 1'b1, 3'b000, 32'h0000_0044, "T6 SB hit A1");
        wait_load_response(32'h0000_0000, "T6 SB accepted");

        launch_mem(ADDR_A0, 1'b0, 3'b010, '0, "T6b LW after SB");
        wait_load_response(32'hAABB_44DD, "T6b SB merged into cached word");

        launch_mem(ADDR_A2, 1'b1, 3'b001, 32'h0000_1234, "T7 SH hit A2");
        wait_load_response(32'h0000_0000, "T7 SH accepted");

        launch_mem(ADDR_A0, 1'b0, 3'b010, '0, "T7b LW after SH");
        wait_load_response(32'h1234_44DD, "T7b SH merged into cached word");

        //4. Store miss enters write buffer; load miss is fully satisfied by forwarding.
        launch_mem(ADDR_B0, 1'b1, 3'b010, 32'hDEAD_BEEF, "T8 SW miss B0");
        wait_load_response(32'h0000_0000, "T8 SW miss accepted");

        launch_mem(ADDR_B0, 1'b0, 3'b010, '0, "T8b LW forwarded B0");
        wait_load_response(32'hDEAD_BEEF, "T8b full WB forwarding to LSU2");

        //5. Partial store miss + refill merge: WB byte overrides refill byte.
        launch_mem(ADDR_C1, 1'b1, 3'b000, 32'h0000_0077, "T9 SB miss C1");
        wait_load_response(32'h0000_0000, "T9 SB miss accepted");

        launch_mem(ADDR_C0, 1'b0, 3'b010, '0, "T9b LW miss C0 partial fwd");
        send_refill_line(ADDR_C0,
                         32'h5566_AA88,
                         32'h0123_4567,
                         32'h89AB_CDEF,
                         32'h0BAD_F00D,
                         32'h5566_7788,
                         "T9b refill C with partial WB merge");

        //6. Hit another word from the same refill to prove line allocation.
        launch_mem(ADDR_A4, 1'b0, 3'b010, '0, "T10 LW hit A4");
        wait_load_response(32'h1122_3380, "T10 hit word1 after earlier refill");

        $display("--------------------------------------------");
        $display("MEM_PATH_7STG_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------");

        if (fail_count == 0)
            $display("MEM_PATH_7STG_TB PASS");
        else
            $display("MEM_PATH_7STG_TB FAIL");

        $finish;
    end
endmodule
