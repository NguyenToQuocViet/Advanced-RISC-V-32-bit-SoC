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
// Module       : cache_subsystem_7stg_tb
// Description  : Integration TB for cache_subsystem_7stg and AXI memory model.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-23
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module cache_subsystem_7stg_tb;
    import cache_pkg::*;
    import axi_pkg::*;

    //system
    logic clk;
    logic rst_n;

    //IF side
    logic [ADDR_WIDTH-1:0]  if_pc;
    logic                   if_req;
    logic [DATA_WIDTH-1:0]  if_instr;
    logic                   if_icache_ready;
    logic                   if_icache_valid;
    logic                   if_icache_consume;
    logic                   flush_refill;

    //MEM side
    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req;
    logic                   mem_we;
    logic [DATA_WIDTH-1:0]  mem_wdata;
    logic [STRB_WIDTH-1:0]  mem_wstrb;
    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic                   mem_dcache_ready;
    logic                   mem_dcache_valid;

    //fence
    logic                   fence;
    logic                   fence_done;

    //AXI4 master
    logic                   axi_arvalid;
    logic                   axi_arready;
    logic [ADDR_WIDTH-1:0]  axi_araddr;
    logic [7:0]             axi_arlen;
    logic [2:0]             axi_arsize;
    logic [1:0]             axi_arburst;
    logic                   axi_rvalid;
    logic                   axi_rready;
    logic [DATA_WIDTH-1:0]  axi_rdata;
    logic [1:0]             axi_rresp;
    logic                   axi_rlast;
    logic                   axi_awvalid;
    logic                   axi_awready;
    logic [ADDR_WIDTH-1:0]  axi_awaddr;
    logic [7:0]             axi_awlen;
    logic [2:0]             axi_awsize;
    logic [1:0]             axi_awburst;
    logic                   axi_wvalid;
    logic                   axi_wready;
    logic [DATA_WIDTH-1:0]  axi_wdata;
    logic [STRB_WIDTH-1:0]  axi_wstrb;
    logic                   axi_wlast;
    logic                   axi_bvalid;
    logic                   axi_bready;
    logic [1:0]             axi_bresp;

    cache_subsystem_7stg u_dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .if_pc              (if_pc),
        .if_req             (if_req),
        .if_instr           (if_instr),
        .if_icache_ready    (if_icache_ready),
        .if_icache_valid    (if_icache_valid),
        .if_icache_consume  (if_icache_consume),
        .flush_refill       (flush_refill),
        .mem_addr           (mem_addr),
        .mem_req            (mem_req),
        .mem_we             (mem_we),
        .mem_wdata          (mem_wdata),
        .mem_wstrb          (mem_wstrb),
        .mem_rdata          (mem_rdata),
        .mem_dcache_ready   (mem_dcache_ready),
        .mem_dcache_valid   (mem_dcache_valid),
        .fence              (fence),
        .fence_done         (fence_done),
        .m_axi_arvalid      (axi_arvalid),
        .m_axi_arready      (axi_arready),
        .m_axi_araddr       (axi_araddr),
        .m_axi_arlen        (axi_arlen),
        .m_axi_arsize       (axi_arsize),
        .m_axi_arburst      (axi_arburst),
        .m_axi_rvalid       (axi_rvalid),
        .m_axi_rready       (axi_rready),
        .m_axi_rdata        (axi_rdata),
        .m_axi_rresp        (axi_rresp),
        .m_axi_rlast        (axi_rlast),
        .m_axi_awvalid      (axi_awvalid),
        .m_axi_awready      (axi_awready),
        .m_axi_awaddr       (axi_awaddr),
        .m_axi_awlen        (axi_awlen),
        .m_axi_awsize       (axi_awsize),
        .m_axi_awburst      (axi_awburst),
        .m_axi_wvalid       (axi_wvalid),
        .m_axi_wready       (axi_wready),
        .m_axi_wdata        (axi_wdata),
        .m_axi_wstrb        (axi_wstrb),
        .m_axi_wlast        (axi_wlast),
        .m_axi_bvalid       (axi_bvalid),
        .m_axi_bready       (axi_bready),
        .m_axi_bresp        (axi_bresp)
    );

    axi_slave_model #(
        .MEM_SIZE       (65536),
        .READ_LATENCY   (3),
        .WRITE_LATENCY  (12),
        .VERBOSE        (1'b0)
    ) u_mem_model (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_arvalid  (axi_arvalid),
        .s_axi_araddr   (axi_araddr),
        .s_axi_arlen    (axi_arlen),
        .s_axi_arsize   (axi_arsize),
        .s_axi_arburst  (axi_arburst),
        .s_axi_arready  (axi_arready),
        .s_axi_rvalid   (axi_rvalid),
        .s_axi_rdata    (axi_rdata),
        .s_axi_rresp    (axi_rresp),
        .s_axi_rlast    (axi_rlast),
        .s_axi_rready   (axi_rready),
        .s_axi_awvalid  (axi_awvalid),
        .s_axi_awaddr   (axi_awaddr),
        .s_axi_awlen    (axi_awlen),
        .s_axi_awsize   (axi_awsize),
        .s_axi_awburst  (axi_awburst),
        .s_axi_awready  (axi_awready),
        .s_axi_wvalid   (axi_wvalid),
        .s_axi_wdata    (axi_wdata),
        .s_axi_wstrb    (axi_wstrb),
        .s_axi_wlast    (axi_wlast),
        .s_axi_wready   (axi_wready),
        .s_axi_bvalid   (axi_bvalid),
        .s_axi_bresp    (axi_bresp),
        .s_axi_bready   (axi_bready)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    localparam int MAX_WAIT = 160;

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
            if_pc        = '0;
            if_req       = 1'b0;
            if_icache_consume = 1'b0;
            flush_refill = 1'b0;
            mem_addr     = '0;
            mem_req      = 1'b0;
            mem_we       = 1'b0;
            mem_wdata    = '0;
            mem_wstrb    = '0;
            fence        = 1'b0;
        end
    endtask

    task automatic reset_dut;
        begin
            drive_idle();
            rst_n = 1'b0;
            repeat (4) step();
            rst_n = 1'b1;
            step();
        end
    endtask

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

    task automatic wait_if_ready;
        input string desc;
        int waited;
        begin
            waited = 0;
            while (!if_icache_ready && waited < MAX_WAIT) begin
                step();
                waited++;
            end

            if (if_icache_ready)
                pass_msg(desc);
            else
                fail_msg(desc);
        end
    endtask

    task automatic wait_mem_ready;
        input string desc;
        int waited;
        begin
            waited = 0;
            while (!mem_dcache_ready && waited < MAX_WAIT) begin
                step();
                waited++;
            end

            if (mem_dcache_ready)
                pass_msg(desc);
            else
                fail_msg(desc);
        end
    endtask

    task automatic i_read;
        input logic [ADDR_WIDTH-1:0] addr;
        input logic [DATA_WIDTH-1:0] expected;
        input string                 desc;
        int waited;
        bit seen;
        begin
            if_pc  = addr;
            if_req = 1'b1;
            step();
            if_req = 1'b0;

            waited = 0;
            seen   = 1'b0;
            while (!seen && waited < MAX_WAIT) begin
                if (if_icache_valid)
                    seen = 1'b1;
                else begin
                    step();
                    waited++;
                end
            end

            if (seen && (if_instr === expected)) begin
                $display("PASS | %-48s instr=%h", desc, if_instr);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (!seen)
                    $display("       if_icache_valid was not asserted");
                else
                    $display("       if_instr: got=%h exp=%h", if_instr, expected);
                fail_count++;
            end

            if_icache_consume = 1'b1;
            step();
            if_icache_consume = 1'b0;
            wait_if_ready({desc, " ready"});
        end
    endtask

    task automatic d_read;
        input logic [ADDR_WIDTH-1:0] addr;
        input logic [DATA_WIDTH-1:0] expected;
        input string                 desc;
        int waited;
        bit seen;
        begin
            mem_addr  = addr;
            mem_req   = 1'b1;
            mem_we    = 1'b0;
            mem_wdata = '0;
            mem_wstrb = '0;
            step();
            mem_req   = 1'b0;
            mem_we    = 1'b0;

            waited = 0;
            seen   = 1'b0;
            while (!seen && waited < MAX_WAIT) begin
                if (mem_dcache_valid)
                    seen = 1'b1;
                else begin
                    step();
                    waited++;
                end
            end

            if (seen && (mem_rdata === expected)) begin
                $display("PASS | %-48s rdata=%h", desc, mem_rdata);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (!seen)
                    $display("       mem_dcache_valid was not asserted");
                else
                    $display("       mem_rdata: got=%h exp=%h", mem_rdata, expected);
                fail_count++;
            end

            wait_mem_ready({desc, " ready"});
        end
    endtask

    task automatic d_write;
        input logic [ADDR_WIDTH-1:0] addr;
        input logic [DATA_WIDTH-1:0] data;
        input logic [STRB_WIDTH-1:0] strb;
        input string                 desc;
        int waited;
        bit seen;
        begin
            mem_addr  = addr;
            mem_req   = 1'b1;
            mem_we    = 1'b1;
            mem_wdata = data;
            mem_wstrb = strb;
            step();
            mem_req   = 1'b0;
            mem_we    = 1'b0;
            mem_wdata = '0;
            mem_wstrb = '0;

            waited = 0;
            seen   = 1'b0;
            while (!seen && waited < MAX_WAIT) begin
                if (mem_dcache_valid)
                    seen = 1'b1;
                else begin
                    step();
                    waited++;
                end
            end

            if (seen) begin
                $display("PASS | %-48s addr=%h data=%h strb=%04b", desc, addr, data, strb);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                $display("       mem_dcache_valid was not asserted");
                fail_count++;
            end

            wait_mem_ready({desc, " ready"});
        end
    endtask

    task automatic fence_wait;
        input string desc;
        int waited;
        begin
            fence  = 1'b1;
            waited = 0;

            while (!fence_done && waited < MAX_WAIT) begin
                step();
                waited++;
            end

            if (fence_done) begin
                $display("PASS | %-48s", desc);
                pass_count++;
            end else begin
                fail_msg(desc);
            end

            step();
            fence = 1'b0;
        end
    endtask

    task automatic simultaneous_i_d_miss;
        input logic [ADDR_WIDTH-1:0] i_addr;
        input logic [DATA_WIDTH-1:0] i_expected;
        input logic [ADDR_WIDTH-1:0] d_addr;
        input logic [DATA_WIDTH-1:0] d_expected;
        input string                 desc;
        int waited;
        int i_cycle;
        int d_cycle;
        bit i_seen;
        bit d_seen;
        begin
            if_pc      = i_addr;
            if_req     = 1'b1;
            mem_addr   = d_addr;
            mem_req    = 1'b1;
            mem_we     = 1'b0;
            mem_wdata  = '0;
            mem_wstrb  = '0;
            step();
            if_req     = 1'b0;
            mem_req    = 1'b0;

            waited  = 0;
            i_seen  = 1'b0;
            d_seen  = 1'b0;
            i_cycle = -1;
            d_cycle = -1;

            while ((waited < MAX_WAIT) && (!i_seen || !d_seen)) begin
                if (!d_seen && mem_dcache_valid) begin
                    d_seen  = 1'b1;
                    d_cycle = waited;
                    if (mem_rdata !== d_expected) begin
                        $display("FAIL | %s D response", desc);
                        $display("       mem_rdata: got=%h exp=%h", mem_rdata, d_expected);
                        fail_count++;
                    end
                end

                if (!i_seen && if_icache_valid) begin
                    i_seen  = 1'b1;
                    i_cycle = waited;
                    if (if_instr !== i_expected) begin
                        $display("FAIL | %s I response", desc);
                        $display("       if_instr: got=%h exp=%h", if_instr, i_expected);
                        fail_count++;
                    end
                end

                if (!i_seen || !d_seen) begin
                    step();
                    waited++;
                end
            end

            if (i_seen && d_seen && (d_cycle < i_cycle)) begin
                $display("PASS | %-48s d_cycle=%0d i_cycle=%0d", desc, d_cycle, i_cycle);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                $display("       i_seen=%0b d_seen=%0b i_cycle=%0d d_cycle=%0d",
                         i_seen, d_seen, i_cycle, d_cycle);
                fail_count++;
            end

            if_icache_consume = 1'b1;
            step();
            if_icache_consume = 1'b0;
            wait_if_ready({desc, " I ready"});
            wait_mem_ready({desc, " D ready"});
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        reset_dut();

        //preload backing memory
        u_mem_model.write_word(32'h0000_1000, 32'hDEAD_BEEF);
        u_mem_model.write_word(32'h0000_1004, 32'hCAFE_BABE);
        u_mem_model.write_word(32'h0000_1008, 32'h1234_5678);
        u_mem_model.write_word(32'h0000_100c, 32'h89AB_CDEF);

        u_mem_model.write_word(32'h0000_2000, 32'h1122_3344);
        u_mem_model.write_word(32'h0000_2004, 32'h5566_7788);
        u_mem_model.write_word(32'h0000_2008, 32'h99AA_BBCC);
        u_mem_model.write_word(32'h0000_200c, 32'hDDEE_FF00);

        u_mem_model.write_word(32'h0000_3000, 32'h0000_0000);
        u_mem_model.write_word(32'h0000_3004, 32'h0000_0000);
        u_mem_model.write_word(32'h0000_3010, 32'h1122_3344);

        u_mem_model.write_word(32'h0000_4000, 32'h0400_0013);
        u_mem_model.write_word(32'h0000_4004, 32'h0400_0093);
        u_mem_model.write_word(32'h0000_5000, 32'h5000_0000);
        u_mem_model.write_word(32'h0000_5004, 32'h5000_0004);

        //1. I-cache cold miss then same-line hit.
        i_read(32'h0000_1000, 32'hDEAD_BEEF, "T1 I-cache cold miss");
        i_read(32'h0000_1004, 32'hCAFE_BABE, "T2 I-cache same-line hit");

        //2. D-cache cold miss then same-line hit.
        d_read(32'h0000_2000, 32'h1122_3344, "T3 D-cache load miss");
        d_read(32'h0000_2004, 32'h5566_7788, "T4 D-cache same-line hit");

        //3. Store hit updates cache and drains through write buffer.
        d_write(32'h0000_2000, 32'h0000_0099, 4'b0001, "T5 D-cache store hit byte");
        d_read (32'h0000_2000, 32'h1122_3399, "T6 D-cache load after store hit");

        //4. Store miss pushes write buffer; immediate load should see forwarded data.
        d_write(32'h0000_3000, 32'hAABB_CCDD, 4'b1111, "T7 D-cache store miss");
        d_read (32'h0000_3000, 32'hAABB_CCDD, "T8 Store-to-load forwarding");

        //partial forwarding must survive write-buffer drain during refill
        d_write(32'h0000_3010, 32'h0000_AA00, 4'b0010, "T8a Partial store miss");
        d_read (32'h0000_3010, 32'h1122_AA44, "T8b Partial forward snapshot");

        //5. Fence drains write buffer to AXI memory.
        fence_wait("T9 Fence drains write buffer");
        if (u_mem_model.read_word(32'h0000_3000) === 32'hAABB_CCDD)
            pass_msg("T10 AXI backing memory updated");
        else begin
            $display("FAIL | T10 AXI backing memory updated");
            $display("       mem[3000]: got=%h exp=%h",
                     u_mem_model.read_word(32'h0000_3000), 32'hAABB_CCDD);
            fail_count++;
        end

        //6. Concurrent I/D read miss: arbiter gives D-cache priority.
        simultaneous_i_d_miss(32'h0000_4000, 32'h0400_0013,
                              32'h0000_5000, 32'h5000_0000,
                              "T11 I/D simultaneous miss priority");

        $display("--------------------------------------------");
        $display("CACHE_SUBSYSTEM_7STG_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------");

        if (fail_count == 0)
            $display("CACHE_SUBSYSTEM_7STG_TB PASS");
        else
            $display("CACHE_SUBSYSTEM_7STG_TB FAIL");

        $finish;
    end
endmodule
