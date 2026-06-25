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
// Module       : riscv_core_7stg
// Description  : 7-stage core integration wrapper.
//                Pipeline: IF1 | IF2 | ID | EX | MEM1 | MEM2 | WB.
//                Keeps the same cache-facing contract as riscv_core.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-24
// Version      : 1.0
// -----------------------------------------------------------------------------

module riscv_core_7stg
    import cpu_pkg::*;
(
    //system
    input  logic                    clk,
    input  logic                    rst_n,

    //if interface
    output logic                    if_req,
    output logic [ADDR_WIDTH-1:0]   if_pc,
    input  logic [DATA_WIDTH-1:0]   if_instr,
    input  logic                    if_icache_ready,
    input  logic                    if_icache_valid,

    //mem interface
    output logic [ADDR_WIDTH-1:0]   mem_addr,
    output logic                    mem_req,
    output logic                    mem_we,
    output logic [DATA_WIDTH-1:0]   mem_wdata,
    output logic [3:0]              mem_wstrb,
    input  logic [DATA_WIDTH-1:0]   mem_rdata,
    input  logic                    mem_dcache_ready,
    input  logic                    mem_dcache_valid,

    //refill abandon - registered mispredict to icache
    output logic                    flush_refill_o
);

    //hazard / control
    logic                   load_use_stall;
    logic                   dcache_mem1_stall, dcache_mem2_stall, dcache_resp_flush;
    logic                   fcu1_stall, if1_if2_stall, if2_id_stall;
    logic                   id_ex_stall, ex_mem1_stall, mem1_mem2_stall, mem2_wb_stall;
    logic                   id_ex_flush, ex_mem1_flush, mem1_mem2_flush, mem2_wb_flush;
    logic                   mispredict_r;
    logic [ADDR_WIDTH-1:0]  correct_pc_r;

    //if1 / if2 stage
    logic [ADDR_WIDTH-1:0]  if1_if2_pc;
    logic                   if1_if2_flush;
    logic [ADDR_WIDTH-1:0]  if2_pc;
    logic                   if2_valid;
    logic                   cache_advance;
    logic                   if2_redirect;
    logic [ADDR_WIDTH-1:0]  if2_redirect_pc;
    logic                   if2_pred_taken;
    logic [ADDR_WIDTH-1:0]  if2_pred_target;
    logic [DATA_WIDTH-1:0]  if2_instr;
    logic                   if2_id_pred_taken;
    logic [ADDR_WIDTH-1:0]  if2_id_pred_target;
    logic                   if2_id_flush;

    //id stage
    logic [ADDR_WIDTH-1:0]  id_pc;
    logic [DATA_WIDTH-1:0]  id_instr;
    logic                   id_pred_taken;
    logic [ADDR_WIDTH-1:0]  id_pred_target;
    logic [4:0]             id_rs1, id_rs2, id_rd;
    logic [3:0]             id_alu_op;
    logic                   id_alu_src, id_alu_src_a;
    logic                   id_mem_req, id_mem_we;
    logic [2:0]             id_mem_size;
    logic                   id_reg_we;
    logic [1:0]             id_wb_sel;
    logic                   id_jump, id_branch;
    logic [DATA_WIDTH-1:0]  id_rdata1, id_rdata2, id_imm;

    //ex stage
    logic [ADDR_WIDTH-1:0]  ex_pc;
    logic [3:0]             ex_alu_op;
    logic                   ex_alu_src, ex_alu_src_a;
    logic                   ex_mem_req, ex_mem_we;
    logic [2:0]             ex_mem_size;
    logic                   ex_reg_we;
    logic [1:0]             ex_wb_sel;
    logic                   ex_jump, ex_branch;
    logic [DATA_WIDTH-1:0]  ex_rdata1, ex_rdata2, ex_imm;
    logic [4:0]             ex_rs1, ex_rs2, ex_rd;
    logic                   ex_pred_taken;
    logic [ADDR_WIDTH-1:0]  ex_pred_target;

    logic [DATA_WIDTH-1:0]  fw_src_a, fw_src_b;
    logic [DATA_WIDTH-1:0]  alu_src_a_val, alu_src_b_val;
    logic [DATA_WIDTH-1:0]  ex_alu_result;

    logic                   bru_update_en, bru_actual_taken, bru_mispredict;
    logic [ADDR_WIDTH-1:0]  bru_actual_target, bru_correct_pc;
    logic [1:0]             forward_a, forward_b;

    //mem1 stage
    logic [ADDR_WIDTH-1:0]  mem1_pc;
    logic [DATA_WIDTH-1:0]  mem1_alu_result, mem1_rdata2;
    logic                   mem1_mem_req, mem1_mem_we, mem1_reg_we;
    logic [2:0]             mem1_mem_size;
    logic [1:0]             mem1_wb_sel;
    logic [4:0]             mem1_rd;
    logic [1:0]             mem1_addr_lsb;
    logic [2:0]             mem1_lsu_mem_size;

    //mem2 stage
    logic [ADDR_WIDTH-1:0]  mem2_pc;
    logic [DATA_WIDTH-1:0]  mem2_alu_result, mem2_rdata2;
    logic                   mem2_mem_req, mem2_mem_we, mem2_reg_we;
    logic [2:0]             mem2_mem_size;
    logic [1:0]             mem2_addr_lsb;
    logic [1:0]             mem2_wb_sel;
    logic [4:0]             mem2_rd;
    logic [DATA_WIDTH-1:0]  mem2_rdata_ext;
    logic                   mem_valid_out, mem_ready_out;
    logic                   mem2_resp_fire;

    //wb stage
    logic [ADDR_WIDTH-1:0]  wb_pc;
    logic [DATA_WIDTH-1:0]  wb_mem_rdata, wb_alu_result;
    logic                   mwb_reg_we;
    logic [1:0]             wb_wb_sel;
    logic [4:0]             mwb_rd;
    logic                   wb_reg_we;
    logic [4:0]             wb_rd;
    logic [DATA_WIDTH-1:0]  wb_wdata;

    //D-cache response overlap cleanup
    assign mem2_resp_fire    = mem2_mem_req && mem_valid_out;
    assign dcache_resp_flush = mem2_resp_fire && dcache_mem1_stall;

    //hazard control distribution
    hazard_ctrl_7stg u_hazard_ctrl (
        .load_use_stall    (load_use_stall),
        .dcache_mem1_stall (dcache_mem1_stall),
        .dcache_mem2_stall (dcache_mem2_stall),
        .dcache_resp_flush (dcache_resp_flush),
        .mispredict_r      (mispredict_r),
        .fcu1_stall        (fcu1_stall),
        .if1_if2_stall     (if1_if2_stall),
        .if2_id_stall      (if2_id_stall),
        .id_ex_stall       (id_ex_stall),
        .ex_mem1_stall     (ex_mem1_stall),
        .mem1_mem2_stall   (mem1_mem2_stall),
        .mem2_wb_stall     (mem2_wb_stall),
        .id_ex_flush       (id_ex_flush),
        .ex_mem1_flush     (ex_mem1_flush),
        .mem1_mem2_flush   (mem1_mem2_flush),
        .mem2_wb_flush     (mem2_wb_flush)
    );

    //mispredict checkpoint FF (EX->IF feedback cut)
    mispredict_reg u_mispredict_reg (
        .clk            (clk),
        .rst_n          (rst_n),
        .bru_mispredict (bru_mispredict),
        .bru_correct_pc (bru_correct_pc),
        .mispredict_r   (mispredict_r),
        .correct_pc_r   (correct_pc_r),
        .flush_refill_o (flush_refill_o)
    );

    //hdu
    hdu_7stg u_hdu (
        .ex_mem_req         (ex_mem_req),
        .ex_mem_we          (ex_mem_we),
        .ex_rd              (ex_rd),
        .mem1_mem_req       (mem1_mem_req),
        .mem1_mem_we        (mem1_mem_we),
        .mem1_rd            (mem1_rd),
        .id_rs1             (id_rs1),
        .id_rs2             (id_rs2),
        .mem1_mem_ready     (mem_ready_out),
        .mem2_mem_req       (mem2_mem_req),
        .mem2_mem_valid     (mem_valid_out),
        .load_use_stall     (load_use_stall),
        .dcache_mem1_stall  (dcache_mem1_stall),
        .dcache_mem2_stall  (dcache_mem2_stall)
    );

    //fcu1: IF1 PC launch side
    fcu1 u_fcu1 (
        .clk             (clk),
        .rst_n           (rst_n),
        .if_req          (if_req),
        .if_pc           (if_pc),
        .ex_mispredict   (mispredict_r),
        .ex_correct_pc   (correct_pc_r),
        .stall           (fcu1_stall),
        .if1_if2_pc      (if1_if2_pc),
        .if1_if2_flush   (if1_if2_flush),
        .if2_redirect    (if2_redirect),
        .if2_redirect_pc (if2_redirect_pc),
        .cache_advance   (cache_advance)
    );

    //if1_if2_pipeline
    if1_if2_pipeline u_if1_if2 (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall       (if1_if2_stall),
        .flush       (if1_if2_flush),
        .if1_pc_i    (if1_if2_pc),
        .if1_valid_i (if_req),
        .if2_pc_o    (if2_pc),
        .if2_valid_o (if2_valid)
    );

    //dbp_7stg: IF1 query, IF2 response
    dbp_7stg u_dbp (
        .clk              (clk),
        .rst_n            (rst_n),
        .if1_pc           (if_pc),
        .if1_valid        (if_req),
        .stall            (if1_if2_stall),
        .flush            (if1_if2_flush),
        .pred_taken       (if2_pred_taken),
        .pred_target      (if2_pred_target),
        .ex_update_en     (bru_update_en),
        .ex_pc            (ex_pc),
        .ex_actual_taken  (bru_actual_taken),
        .ex_actual_target (bru_actual_target)
    );

    //fcu2: IF2 response side
    fcu2 u_fcu2 (
        .clk                 (clk),
        .rst_n               (rst_n),
        .instr_i             (if_instr),
        .cache_valid         (if_icache_valid),
        .cache_ready         (if_icache_ready),
        .if2_valid           (if2_valid),
        .pred_taken          (if2_pred_taken),
        .pred_target         (if2_pred_target),
        .ex_mispredict       (mispredict_r),
        .cache_advance       (cache_advance),
        .if2_redirect        (if2_redirect),
        .if2_redirect_pc     (if2_redirect_pc),
        .stall               (if2_id_stall),
        .instr_o             (if2_instr),
        .if2_id_pred_taken   (if2_id_pred_taken),
        .if2_id_pred_target  (if2_id_pred_target),
        .if2_id_flush        (if2_id_flush)
    );

    //if2_id_pipeline
    if2_id_pipeline u_if2_id (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (if2_id_stall),
        .flush            (if2_id_flush),
        .if_pc_i          (if2_pc),
        .if_instr_i       (if2_instr),
        .if_pred_taken_i  (if2_id_pred_taken),
        .if_pred_target_i (if2_id_pred_target),
        .id_pc_o          (id_pc),
        .id_instr_o       (id_instr),
        .id_pred_taken_o  (id_pred_taken),
        .id_pred_target_o (id_pred_target)
    );

    //cu
    cu u_cu (
        .instr            (id_instr),
        .rs1              (id_rs1),
        .rs2              (id_rs2),
        .rd               (id_rd),
        .alu_op           (id_alu_op),
        .alu_src          (id_alu_src),
        .alu_src_a        (id_alu_src_a),
        .mem_req          (id_mem_req),
        .mem_we           (id_mem_we),
        .mem_size         (id_mem_size),
        .reg_we           (id_reg_we),
        .wb_sel           (id_wb_sel),
        .branch           (id_branch),
        .jump             (id_jump)
    );

    //rf
    rf u_rf (
        .clk              (clk),
        .instr            (id_instr),
        .rdata1           (id_rdata1),
        .rdata2           (id_rdata2),
        .reg_we           (wb_reg_we),
        .rd               (wb_rd),
        .wdata            (wb_wdata)
    );

    //immgen
    immgen u_immgen (
        .instr            (id_instr),
        .imm              (id_imm)
    );

    //id_ex_pipeline
    id_ex_pipeline u_id_ex (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (id_ex_stall),
        .flush            (id_ex_flush),
        .alu_op_i         (id_alu_op),
        .alu_src_i        (id_alu_src),
        .alu_src_a_i      (id_alu_src_a),
        .wb_sel_i         (id_wb_sel),
        .reg_we_i         (id_reg_we),
        .mem_req_i        (id_mem_req),
        .mem_we_i         (id_mem_we),
        .mem_size_i       (id_mem_size),
        .jump_i           (id_jump),
        .branch_i         (id_branch),
        .rdata1_i         (id_rdata1),
        .rdata2_i         (id_rdata2),
        .imm_i            (id_imm),
        .pc_i             (id_pc),
        .rs1_i            (id_rs1),
        .rs2_i            (id_rs2),
        .rd_i             (id_rd),
        .pred_taken_i     (id_pred_taken),
        .pred_target_i    (id_pred_target),
        .alu_op_o         (ex_alu_op),
        .alu_src_o        (ex_alu_src),
        .alu_src_a_o      (ex_alu_src_a),
        .wb_sel_o         (ex_wb_sel),
        .reg_we_o         (ex_reg_we),
        .mem_req_o        (ex_mem_req),
        .mem_we_o         (ex_mem_we),
        .mem_size_o       (ex_mem_size),
        .jump_o           (ex_jump),
        .branch_o         (ex_branch),
        .rdata1_o         (ex_rdata1),
        .rdata2_o         (ex_rdata2),
        .imm_o            (ex_imm),
        .pc_o             (ex_pc),
        .rs1_o            (ex_rs1),
        .rs2_o            (ex_rs2),
        .rd_o             (ex_rd),
        .pred_taken_o     (ex_pred_taken),
        .pred_target_o    (ex_pred_target)
    );

    //fu_7stg
    fu_7stg u_fu (
        .ex_rs1      (ex_rs1),
        .ex_rs2      (ex_rs2),
        .mem1_rd     (mem1_rd),
        .mem1_reg_we (mem1_reg_we),
        .mem2_rd     (mem2_rd),
        .mem2_reg_we (mem2_reg_we),
        .wb_rd       (wb_rd),
        .wb_reg_we   (wb_reg_we),
        .forward_a   (forward_a),
        .forward_b   (forward_b)
    );

    //fwd_mux_7stg
    fwd_mux_7stg u_fwd_mux (
        .forward_a       (forward_a),
        .forward_b       (forward_b),
        .ex_rdata1       (ex_rdata1),
        .ex_rdata2       (ex_rdata2),
        .mem1_wb_sel     (mem1_wb_sel),
        .mem1_alu_result (mem1_alu_result),
        .mem1_pc         (mem1_pc),
        .mem2_wb_sel     (mem2_wb_sel),
        .mem2_alu_result (mem2_alu_result),
        .mem2_pc         (mem2_pc),
        .wb_wdata        (wb_wdata),
        .fw_src_a        (fw_src_a),
        .fw_src_b        (fw_src_b)
    );

    //alu_operand_mux
    alu_operand_mux u_alu_operand_mux (
        .alu_src          (ex_alu_src),
        .alu_src_a        (ex_alu_src_a),
        .fw_src_a         (fw_src_a),
        .fw_src_b         (fw_src_b),
        .ex_pc            (ex_pc),
        .ex_imm           (ex_imm),
        .alu_src_a_val    (alu_src_a_val),
        .alu_src_b_val    (alu_src_b_val)
    );

    //alu
    alu u_alu (
        .alu_op           (ex_alu_op),
        .src_a            (alu_src_a_val),
        .src_b            (alu_src_b_val),
        .result           (ex_alu_result)
    );

    //bru
    bru u_bru (
        .branch           (ex_branch),
        .jump             (ex_jump),
        .alu_src          (ex_alu_src),
        .funct3           (ex_mem_size),
        .src_a            (fw_src_a),
        .src_b            (fw_src_b),
        .imm              (ex_imm),
        .pc               (ex_pc),
        .pred_taken       (ex_pred_taken),
        .pred_target      (ex_pred_target),
        .ex_update_en     (bru_update_en),
        .ex_actual_taken  (bru_actual_taken),
        .ex_actual_target (bru_actual_target),
        .ex_mispredict    (bru_mispredict),
        .ex_correct_pc    (bru_correct_pc)
    );

    //ex_mem1_pipeline
    ex_mem1_pipeline u_ex_mem1 (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (ex_mem1_stall),
        .flush            (ex_mem1_flush),
        .alu_result_i     (ex_alu_result),
        .rdata2_i         (fw_src_b),
        .pc_i             (ex_pc),
        .mem_req_i        (ex_mem_req),
        .mem_we_i         (ex_mem_we),
        .mem_size_i       (ex_mem_size),
        .reg_we_i         (ex_reg_we),
        .wb_sel_i         (ex_wb_sel),
        .rd_i             (ex_rd),
        .alu_result_o     (mem1_alu_result),
        .rdata2_o         (mem1_rdata2),
        .pc_o             (mem1_pc),
        .mem_req_o        (mem1_mem_req),
        .mem_we_o         (mem1_mem_we),
        .mem_size_o       (mem1_mem_size),
        .reg_we_o         (mem1_reg_we),
        .wb_sel_o         (mem1_wb_sel),
        .rd_o             (mem1_rd)
    );

    //lsu1: MEM1 request launch
    lsu1 u_lsu1 (
        .mem_req      (mem1_mem_req),
        .mem_we       (mem1_mem_we),
        .mem_size     (mem1_mem_size),
        .addr         (mem1_alu_result),
        .wdata        (mem1_rdata2),
        .dc_addr      (mem_addr),
        .dc_req       (mem_req),
        .dc_we        (mem_we),
        .dc_wdata     (mem_wdata),
        .dc_wstrb     (mem_wstrb),
        .addr_lsb     (mem1_addr_lsb),
        .mem_size_o   (mem1_lsu_mem_size)
    );

    //mem1_mem2_pipeline
    mem1_mem2_pipeline u_mem1_mem2 (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (mem1_mem2_stall),
        .flush        (mem1_mem2_flush),
        .alu_result_i (mem1_alu_result),
        .rdata2_i     (mem1_rdata2),
        .pc_i         (mem1_pc),
        .mem_req_i    (mem1_mem_req),
        .mem_we_i     (mem1_mem_we),
        .mem_size_i   (mem1_lsu_mem_size),
        .addr_lsb_i   (mem1_addr_lsb),
        .reg_we_i     (mem1_reg_we),
        .wb_sel_i     (mem1_wb_sel),
        .rd_i         (mem1_rd),
        .alu_result_o (mem2_alu_result),
        .rdata2_o     (mem2_rdata2),
        .pc_o         (mem2_pc),
        .mem_req_o    (mem2_mem_req),
        .mem_we_o     (mem2_mem_we),
        .mem_size_o   (mem2_mem_size),
        .addr_lsb_o   (mem2_addr_lsb),
        .reg_we_o     (mem2_reg_we),
        .wb_sel_o     (mem2_wb_sel),
        .rd_o         (mem2_rd)
    );

    //lsu2: MEM2 response consume
    lsu2 u_lsu2 (
        .dc_rdata   (mem_rdata),
        .dc_valid   (mem_dcache_valid),
        .dc_ready   (mem_dcache_ready),
        .addr_lsb   (mem2_addr_lsb),
        .mem_size   (mem2_mem_size),
        .mem_rdata  (mem2_rdata_ext),
        .mem_valid  (mem_valid_out),
        .mem_ready  (mem_ready_out)
    );

    //mem2_wb_pipeline
    mem2_wb_pipeline u_mem2_wb (
        .clk              (clk),
        .rst_n            (rst_n),
        .stall            (mem2_wb_stall),
        .flush            (mem2_wb_flush),
        .mem_rdata_i      (mem2_rdata_ext),
        .alu_result_i     (mem2_alu_result),
        .pc_i             (mem2_pc),
        .reg_we_i         (mem2_reg_we),
        .wb_sel_i         (mem2_wb_sel),
        .rd_i             (mem2_rd),
        .mem_rdata_o      (wb_mem_rdata),
        .alu_result_o     (wb_alu_result),
        .pc_o             (wb_pc),
        .reg_we_o         (mwb_reg_we),
        .wb_sel_o         (wb_wb_sel),
        .rd_o             (mwb_rd)
    );

    //wb
    wb u_wb (
        .alu_result_i     (wb_alu_result),
        .mem_rdata_i      (wb_mem_rdata),
        .pc_i             (wb_pc),
        .wb_sel_i         (wb_wb_sel),
        .reg_we_i         (mwb_reg_we),
        .rd_i             (mwb_rd),
        .wdata_o          (wb_wdata),
        .reg_we_o         (wb_reg_we),
        .rd_o             (wb_rd)
    );
endmodule
