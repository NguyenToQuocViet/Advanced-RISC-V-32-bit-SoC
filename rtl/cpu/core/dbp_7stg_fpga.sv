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
// Module       : dbp_7stg_fpga
// Description  : IF1 query, IF2 prediction response. BTB uses sync SRAM timing;
//                BHT remains flop-array and is registered to align with BTB.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-22
// Version      : 1.0
// -----------------------------------------------------------------------------

module dbp_7stg_fpga
    import cpu_pkg::*;
(
    //system interface
    input  logic                    clk,
    input  logic                    rst_n,

    //IF1 query interface
    input  logic [ADDR_WIDTH-1:0]   if1_pc,
    input  logic                    if1_valid,
    input  logic                    stall,
    input  logic                    flush,
    input  logic                    if2_consume,

    //IF2 prediction response
    output logic                    pred_taken,
    output logic [ADDR_WIDTH-1:0]   pred_target,

    //EX update interface
    input  logic                    ex_update_en,
    input  logic [ADDR_WIDTH-1:0]   ex_pc,
    input  logic                    ex_actual_taken,
    input  logic [ADDR_WIDTH-1:0]   ex_actual_target
);
    localparam int BTB_DATA_WIDTH = BTB_TAG_BITS + ADDR_WIDTH;

    //IF1 address decode
    logic [BP_IDX_BITS-1:0]  if1_idx;
    logic [BTB_TAG_BITS-1:0] if1_tag;

    assign if1_idx = if1_pc[2 +: BP_IDX_BITS];
    assign if1_tag = if1_pc[ADDR_WIDTH-1 -: BTB_TAG_BITS];

    //EX address decode
    logic [BP_IDX_BITS-1:0]  ex_idx;
    logic [BTB_TAG_BITS-1:0] ex_tag;

    assign ex_idx = ex_pc[2 +: BP_IDX_BITS];
    assign ex_tag = ex_pc[ADDR_WIDTH-1 -: BTB_TAG_BITS];

    //BHT: small flop-array, registered for IF2 timing
    logic [PRED_BITS-1:0] bht [BP_ENTRIES];
    initial foreach (bht[i]) bht[i] = STRONGLY_NT;

    //BTB valid is a small flop-array, aligned with BTB SRAM response
    logic [BP_ENTRIES-1:0] btb_valid;

    //IF1 -> IF2 prediction metadata
    logic                    if2_query_valid_q;
    logic [BTB_TAG_BITS-1:0] if2_tag_q;
    logic [PRED_BITS-1:0]    if2_bht_q;
    logic                    if2_btb_valid_q;

    logic if1_fire;
    assign if1_fire = if1_valid && !stall && !flush;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if2_query_valid_q <= 1'b0;
            if2_tag_q         <= '0;
            if2_bht_q         <= STRONGLY_NT;
            if2_btb_valid_q   <= 1'b0;
            btb_valid         <= '0;
        end else begin
            if (flush) begin
                if2_query_valid_q <= 1'b0;
                if2_tag_q         <= '0;
                if2_bht_q         <= STRONGLY_NT;
                if2_btb_valid_q   <= 1'b0;
            end else if (if1_fire) begin
                if2_query_valid_q <= 1'b1;
                if2_tag_q         <= if1_tag;
                if2_bht_q         <= bht[if1_idx];
                if2_btb_valid_q   <= btb_valid[if1_idx];
            end else if (if2_consume) begin
                if2_query_valid_q <= 1'b0;
            end

            if (ex_update_en && ex_actual_taken)
                btb_valid[ex_idx] <= 1'b1;
        end
    end

    //BHT update: 2-bit saturating counter
    always_ff @(posedge clk) begin
        if (ex_update_en) begin
            if (ex_actual_taken) begin
                if (bht[ex_idx] != STRONGLY_T)
                    bht[ex_idx] <= bht[ex_idx] + 1'b1;
            end else begin
                if (bht[ex_idx] != STRONGLY_NT)
                    bht[ex_idx] <= bht[ex_idx] - 1'b1;
            end
        end
    end

    //BTB SRAM: IF1 read, EX write
    logic [BTB_DATA_WIDTH-1:0] btb_rd_dout;
    logic [BTB_DATA_WIDTH-1:0] btb_wr_din;

    logic [BTB_TAG_BITS-1:0] btb_rd_tag;
    logic [ADDR_WIDTH-1:0]   btb_rd_target;

    assign btb_wr_din    = {ex_tag, ex_actual_target};
    assign btb_rd_tag    = btb_rd_dout[BTB_DATA_WIDTH-1 -: BTB_TAG_BITS];
    assign btb_rd_target = btb_rd_dout[0 +: ADDR_WIDTH];

    sram_1r1w #(
        .ADDR_W (BP_IDX_BITS),
        .DATA_W (BTB_DATA_WIDTH),
        .DEPTH  (BP_ENTRIES)
    ) btb_sram (
        .clk     (clk),
        .rd_csb  (!if1_fire),
        .rd_addr (if1_idx),
        .rd_dout (btb_rd_dout),
        .wr_csb  (!(ex_update_en && ex_actual_taken)),
        .wr_web  (!(ex_update_en && ex_actual_taken)),
        .wr_addr (ex_idx),
        .wr_din  (btb_wr_din)
    );

    //IF2 prediction response
    logic btb_hit;
    assign btb_hit     = if2_query_valid_q && if2_btb_valid_q && (btb_rd_tag == if2_tag_q);
    assign pred_taken  = btb_hit && (if2_bht_q >= WEAKLY_T);
    assign pred_target = btb_hit ? btb_rd_target : '0;
endmodule
