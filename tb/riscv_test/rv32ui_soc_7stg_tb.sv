// -----------------------------------------------------------------------------
// Copyright (c) 2026 NGUYEN TO QUOC VIET
// Ho Chi Minh City University of Technology (HCMUT-VNU)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit SoC
// Module       : rv32ui_soc_7stg_tb
// Description  : rv32ui regression for riscv_soc_7stg.
//                Core runs through I-Cache, D-Cache, bus arbiter, AXI memory.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-24
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module rv32ui_soc_7stg_tb;
    import cache_pkg::*;
    import axi_pkg::*;

    //parameters
    localparam TOHOST_ADDR = 32'h1000;
    localparam MAX_CYCLES  = 50_000;
    localparam MEM_BYTES   = 65536;

    //clock / reset
    logic clk;
    logic rst_n;
    initial clk = 1'b0;
    always #5 clk = ~clk;

    //fence
    logic fence;
    logic fence_done;

    //AXI4 wires
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

    //DUT
    riscv_soc_7stg dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .fence          (fence),
        .fence_done     (fence_done),
        .m_axi_arvalid  (axi_arvalid),
        .m_axi_arready  (axi_arready),
        .m_axi_araddr   (axi_araddr),
        .m_axi_arlen    (axi_arlen),
        .m_axi_arsize   (axi_arsize),
        .m_axi_arburst  (axi_arburst),
        .m_axi_rvalid   (axi_rvalid),
        .m_axi_rready   (axi_rready),
        .m_axi_rdata    (axi_rdata),
        .m_axi_rresp    (axi_rresp),
        .m_axi_rlast    (axi_rlast),
        .m_axi_awvalid  (axi_awvalid),
        .m_axi_awready  (axi_awready),
        .m_axi_awaddr   (axi_awaddr),
        .m_axi_awlen    (axi_awlen),
        .m_axi_awsize   (axi_awsize),
        .m_axi_awburst  (axi_awburst),
        .m_axi_wvalid   (axi_wvalid),
        .m_axi_wready   (axi_wready),
        .m_axi_wdata    (axi_wdata),
        .m_axi_wstrb    (axi_wstrb),
        .m_axi_wlast    (axi_wlast),
        .m_axi_bvalid   (axi_bvalid),
        .m_axi_bready   (axi_bready),
        .m_axi_bresp    (axi_bresp)
    );

    //AXI memory model
    axi_slave_model #(
        .MEM_SIZE       (MEM_BYTES),
        .READ_LATENCY   (2),
        .WRITE_LATENCY  (2),
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

    //memory utilities
    task automatic clear_memory;
        for (int i = 0; i < MEM_BYTES; i++)
            u_mem_model.mem[i] = 8'h00;
    endtask

    task automatic preload_from_file(input string filepath);
        clear_memory();
        u_mem_model.preload_from_file(filepath);
    endtask

    task automatic write_word(input logic [ADDR_WIDTH-1:0] addr,
                              input logic [DATA_WIDTH-1:0] data);
        u_mem_model.write_word(addr, data);
    endtask

    function automatic logic [DATA_WIDTH-1:0] read_word(
        input logic [ADDR_WIDTH-1:0] addr);
        return u_mem_model.read_word(addr);
    endfunction

    //test runner
    int pass_count;
    int fail_count;
    int timeout_count;
    int cycle_cnt;

    task automatic do_reset;
        begin
            fence = 1'b0;
            rst_n = 1'b0;
            repeat (6) @(posedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic run_one_test;
        input string mem_path;
        input string test_name;
        output int   result;

        logic [31:0] tohost_val;
        int          failed_vec;
        begin
            preload_from_file(mem_path);
            write_word(TOHOST_ADDR, 32'h0);
            do_reset();

            tohost_val = 32'h0;
            for (cycle_cnt = 0; cycle_cnt < MAX_CYCLES; cycle_cnt++) begin
                @(posedge clk);
                tohost_val = read_word(TOHOST_ADDR);
                if (tohost_val != 32'h0)
                    break;
            end

            if (cycle_cnt == MAX_CYCLES) begin
                $display("TIMEOUT | %-30s  (> %0d cycles)", test_name, MAX_CYCLES);
                timeout_count++;
                result = -1;
            end else if (tohost_val == 32'h1) begin
                $display("PASS    | %-30s  (%0d cycles)", test_name, cycle_cnt);
                pass_count++;
                result = 1;
            end else begin
                failed_vec = int'(tohost_val >> 1);
                $display("FAIL    | %-30s  FAIL at test vector #%0d  (tohost=0x%h, %0d cycles)",
                         test_name, failed_vec, tohost_val, cycle_cnt);
                fail_count++;
                result = 0;
            end
        end
    endtask

    localparam string MEM_BASE = "tb/riscv_test/build/";
    int dummy;

    initial begin
        pass_count    = 0;
        fail_count    = 0;
        timeout_count = 0;
        rst_n         = 1'b1;
        fence         = 1'b0;

        clear_memory();

        $display("============================================================");
        $display("  rv32ui_soc_7stg_tb -- CORE + CACHE + AXI");
        $display("  MAX_CYCLES/test: %0d  |  MEM_BYTES: %0d", MAX_CYCLES, MEM_BYTES);
        $display("============================================================");

        run_one_test({MEM_BASE, "rv32ui-p-simple.mem"},  "rv32ui-p-simple",  dummy);
        run_one_test({MEM_BASE, "rv32ui-p-add.mem"},     "rv32ui-p-add",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-addi.mem"},    "rv32ui-p-addi",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-and.mem"},     "rv32ui-p-and",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-andi.mem"},    "rv32ui-p-andi",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-auipc.mem"},   "rv32ui-p-auipc",   dummy);
        run_one_test({MEM_BASE, "rv32ui-p-beq.mem"},     "rv32ui-p-beq",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bge.mem"},     "rv32ui-p-bge",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bgeu.mem"},    "rv32ui-p-bgeu",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-blt.mem"},     "rv32ui-p-blt",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bltu.mem"},    "rv32ui-p-bltu",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-bne.mem"},     "rv32ui-p-bne",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-jal.mem"},     "rv32ui-p-jal",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-jalr.mem"},    "rv32ui-p-jalr",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lb.mem"},      "rv32ui-p-lb",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lbu.mem"},     "rv32ui-p-lbu",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lh.mem"},      "rv32ui-p-lh",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lhu.mem"},     "rv32ui-p-lhu",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lw.mem"},      "rv32ui-p-lw",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-lui.mem"},     "rv32ui-p-lui",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-or.mem"},      "rv32ui-p-or",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-ori.mem"},     "rv32ui-p-ori",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sb.mem"},      "rv32ui-p-sb",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sh.mem"},      "rv32ui-p-sh",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sw.mem"},      "rv32ui-p-sw",      dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sll.mem"},     "rv32ui-p-sll",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-slli.mem"},    "rv32ui-p-slli",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-slt.mem"},     "rv32ui-p-slt",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-slti.mem"},    "rv32ui-p-slti",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sltiu.mem"},   "rv32ui-p-sltiu",   dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sltu.mem"},    "rv32ui-p-sltu",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sra.mem"},     "rv32ui-p-sra",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-srai.mem"},    "rv32ui-p-srai",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-srl.mem"},     "rv32ui-p-srl",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-srli.mem"},    "rv32ui-p-srli",    dummy);
        run_one_test({MEM_BASE, "rv32ui-p-sub.mem"},     "rv32ui-p-sub",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-xor.mem"},     "rv32ui-p-xor",     dummy);
        run_one_test({MEM_BASE, "rv32ui-p-xori.mem"},    "rv32ui-p-xori",    dummy);

        $display("============================================================");
        $display("  SOC-7STG SUMMARY: %0d PASS | %0d FAIL | %0d TIMEOUT  (total: %0d)",
                 pass_count, fail_count, timeout_count,
                 pass_count + fail_count + timeout_count);
        if (fail_count == 0 && timeout_count == 0)
            $display("  >> ALL TESTS PASSED -- 7-STAGE SOC CLEAN <<");
        else
            $display("  >> 7-STAGE SOC STILL HAS BUGS -- debug core/cache/AXI boundary <<");
        $display("============================================================");

        $finish;
    end
endmodule
