// -----------------------------------------------------------------------------
// Copyright (c) 2026 NGUYEN TO QUOC VIET
// Ho Chi Minh City University of Technology (HCMUT-VNU)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit SoC
// Module       : rv32ui_core_7stg_tb
// Description  : CORE-ONLY rv32ui test for riscv_core_7stg.
//                Bypasses cache_subsystem but preserves 1-cycle IF/MEM timing.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-24
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module rv32ui_core_7stg_tb;
    import cpu_pkg::*;

    //parameters
    localparam TOHOST_ADDR = 32'h1000;
    localparam MAX_CYCLES  = 8_000;
    localparam MEM_BYTES   = 65536;

    //clock / reset
    logic clk, rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    //core I/O
    logic                   if_req;
    logic [ADDR_WIDTH-1:0]  if_pc;
    logic [DATA_WIDTH-1:0]  if_instr;
    logic                   if_icache_ready, if_icache_valid;
    logic                   if_icache_consume;

    logic [ADDR_WIDTH-1:0]  mem_addr;
    logic                   mem_req, mem_we;
    logic [DATA_WIDTH-1:0]  mem_wdata;
    logic [3:0]             mem_wstrb;
    logic [DATA_WIDTH-1:0]  mem_rdata;
    logic                   mem_dcache_ready, mem_dcache_valid;
    logic                   flush_refill_o;

    //backing store
    logic [7:0] mem [0:MEM_BYTES-1];

    //IF response model: request N, instruction valid N+1
    logic                   if_req_q;
    logic [ADDR_WIDTH-1:0]  if_pc_q;
    logic [ADDR_WIDTH-1:0]  if_idx_q;

    assign if_idx_q = if_pc_q & 32'h0000_FFFF;
    assign if_icache_ready = 1'b1;
    assign if_icache_valid = if_req_q;
    assign if_instr        = if_req_q ? {mem[if_idx_q+3], mem[if_idx_q+2],
                                         mem[if_idx_q+1], mem[if_idx_q+0]} : NOP_INSTR;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_req_q <= 1'b0;
            if_pc_q  <= '0;
        end else begin
            if_req_q <= if_req;
            if_pc_q  <= if_pc;
        end
    end

    //D response model: request N, response valid N+1
    logic                   mem_req_q;
    logic                   mem_we_q;
    logic [ADDR_WIDTH-1:0]  mem_addr_q;
    logic [DATA_WIDTH-1:0]  mem_wdata_q;
    logic [3:0]             mem_wstrb_q;
    logic [ADDR_WIDTH-1:0]  mem_idx_q;

    assign mem_idx_q          = mem_addr_q & 32'h0000_FFFC;
    assign mem_dcache_ready   = 1'b1;
    assign mem_dcache_valid   = mem_req_q;
    assign mem_rdata          = mem_req_q ? {mem[mem_idx_q+3], mem[mem_idx_q+2],
                                             mem[mem_idx_q+1], mem[mem_idx_q+0]} : '0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_req_q   <= 1'b0;
            mem_we_q    <= 1'b0;
            mem_addr_q  <= '0;
            mem_wdata_q <= '0;
            mem_wstrb_q <= '0;
        end else begin
            mem_req_q   <= mem_req;
            mem_we_q    <= mem_we;
            mem_addr_q  <= mem_addr;
            mem_wdata_q <= mem_wdata;
            mem_wstrb_q <= mem_wstrb;
        end
    end

    //sync write applies when D-cache response accepts store
    always_ff @(posedge clk) begin
        if (mem_req_q && mem_we_q) begin
            if (mem_wstrb_q[0]) mem[mem_idx_q+0] <= mem_wdata_q[ 7: 0];
            if (mem_wstrb_q[1]) mem[mem_idx_q+1] <= mem_wdata_q[15: 8];
            if (mem_wstrb_q[2]) mem[mem_idx_q+2] <= mem_wdata_q[23:16];
            if (mem_wstrb_q[3]) mem[mem_idx_q+3] <= mem_wdata_q[31:24];
        end
    end

    //DUT
    riscv_core_7stg dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .if_req           (if_req),
        .if_pc            (if_pc),
        .if_instr         (if_instr),
        .if_icache_ready  (if_icache_ready),
        .if_icache_valid  (if_icache_valid),
        .if_icache_consume(if_icache_consume),
        .mem_addr         (mem_addr),
        .mem_req          (mem_req),
        .mem_we           (mem_we),
        .mem_wdata        (mem_wdata),
        .mem_wstrb        (mem_wstrb),
        .mem_rdata        (mem_rdata),
        .mem_dcache_ready (mem_dcache_ready),
        .mem_dcache_valid (mem_dcache_valid),
        .flush_refill_o   (flush_refill_o)
    );

    //memory utilities
    task automatic preload_from_file(input string filepath);
        for (int i = 0; i < MEM_BYTES; i++) mem[i] = 8'h00;
        $readmemh(filepath, mem);
    endtask

    task automatic write_word(input logic [ADDR_WIDTH-1:0] addr,
                              input logic [DATA_WIDTH-1:0] data);
        mem[addr+0] = data[ 7: 0];
        mem[addr+1] = data[15: 8];
        mem[addr+2] = data[23:16];
        mem[addr+3] = data[31:24];
    endtask

    function automatic logic [DATA_WIDTH-1:0] read_word(
        input logic [ADDR_WIDTH-1:0] addr);
        return {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]};
    endfunction

    //test runner
    int pass_count;
    int fail_count;
    int timeout_count;
    int cycle_cnt;

    task do_reset();
        rst_n = 1'b0;
        repeat(4) @(posedge clk);
        rst_n = 1'b1;
    endtask

    task automatic run_one_test;
        input string mem_path;
        input string test_name;
        output int   result;

        logic [31:0] tohost_val;
        int          failed_vec;
        begin
            write_word(TOHOST_ADDR, 32'h0);
            preload_from_file(mem_path);
            do_reset();

            tohost_val = 32'h0;
            for (cycle_cnt = 0; cycle_cnt < MAX_CYCLES; cycle_cnt++) begin
                @(posedge clk);
                tohost_val = read_word(TOHOST_ADDR);
                if (tohost_val != 32'h0) break;
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

        for (int i = 0; i < MEM_BYTES; i++) mem[i] = 8'h00;

        $display("============================================================");
        $display("  rv32ui_core_7stg_tb -- CORE-ONLY, 1-cycle IF/MEM timing");
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
        $display("  CORE-7STG SUMMARY: %0d PASS | %0d FAIL | %0d TIMEOUT  (total: %0d)",
                 pass_count, fail_count, timeout_count,
                 pass_count + fail_count + timeout_count);
        if (fail_count == 0 && timeout_count == 0)
            $display("  >> ALL TESTS PASSED -- 7-STAGE CORE-ONLY CLEAN <<");
        else
            $display("  >> 7-STAGE CORE STILL HAS BUGS -- debug core before SoC <<");
        $display("============================================================");

        $finish;
    end
endmodule
