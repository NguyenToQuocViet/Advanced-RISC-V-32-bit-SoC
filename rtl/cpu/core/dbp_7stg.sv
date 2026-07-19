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
// Module       : Dynamic Branch Predictor (7-stage)
// Description  : IF1 query, IF2 prediction response. BTB uses 1RW SRAM with a
//                four-entry update queue; BHT remains a registered flop-array.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-22
// Version      : 1.1
// -----------------------------------------------------------------------------

module dbp_7stg
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
    localparam int BTB_DATA_WIDTH   = BTB_TAG_BITS + ADDR_WIDTH;
    localparam int BTB_SRAM_WIDTH   = 64;
    localparam int BTB_PAD_WIDTH    = BTB_SRAM_WIDTH - BTB_DATA_WIDTH;
    localparam int BTB_UPDATE_DEPTH = 4;

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
    logic                    if2_shadow_q;
    logic                    if2_forward_tag_match_q;
    logic [ADDR_WIDTH-1:0]   if2_forward_target_q;

    logic                    query_shadow;
    logic                    query_forward_tag_match;
    logic [ADDR_WIDTH-1:0]   query_forward_target;

    logic                    btb_write;
    logic [BP_IDX_BITS-1:0]  btb_addr;

    logic if1_fire;
    assign if1_fire = if1_valid && !stall && !flush;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if2_query_valid_q <= 1'b0;
            if2_tag_q         <= '0;
            if2_bht_q         <= STRONGLY_NT;
            if2_btb_valid_q   <= 1'b0;
            if2_shadow_q      <= 1'b0;
            if2_forward_tag_match_q <= 1'b0;
            if2_forward_target_q    <= '0;
            btb_valid         <= '0;
        end else begin
            if (flush) begin
                if2_query_valid_q <= 1'b0;
                if2_tag_q         <= '0;
                if2_bht_q         <= STRONGLY_NT;
                if2_btb_valid_q   <= 1'b0;
                if2_shadow_q      <= 1'b0;
                if2_forward_tag_match_q <= 1'b0;
                if2_forward_target_q    <= '0;
            end else if (if1_fire) begin
                if2_query_valid_q <= 1'b1;
                if2_tag_q         <= if1_tag;
                if2_bht_q         <= bht[if1_idx];
                if2_btb_valid_q   <= btb_valid[if1_idx];
                if2_shadow_q      <= query_shadow;
                if2_forward_tag_match_q <= query_forward_tag_match;
                if2_forward_target_q    <= query_forward_target;
            end else if (if2_consume) begin
                if2_query_valid_q <= 1'b0;
            end

            if (btb_write)
                btb_valid[btb_addr] <= 1'b1;
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

    //BTB update queue: entry 0 is oldest
    logic [BP_IDX_BITS-1:0]  update_idx_q    [0:BTB_UPDATE_DEPTH-1];
    logic [BTB_TAG_BITS-1:0] update_tag_q    [0:BTB_UPDATE_DEPTH-1];
    logic [ADDR_WIDTH-1:0]   update_target_q [0:BTB_UPDATE_DEPTH-1];
    logic [BTB_UPDATE_DEPTH-1:0] update_valid_q;

    logic [BP_IDX_BITS-1:0]  update_idx_d    [0:BTB_UPDATE_DEPTH-1];
    logic [BTB_TAG_BITS-1:0] update_tag_d    [0:BTB_UPDATE_DEPTH-1];
    logic [ADDR_WIDTH-1:0]   update_target_d [0:BTB_UPDATE_DEPTH-1];
    logic [BTB_UPDATE_DEPTH-1:0] update_valid_d;

    logic btb_update_req;
    logic queue_pop;
    logic queue_capture;
    logic queue_match_found;
    logic queue_append_done;

    assign btb_update_req = ex_update_en && ex_actual_taken;

    //1RW arbitration: IF1 read, then queued write, then direct EX write
    logic [BTB_TAG_BITS-1:0]   btb_write_tag;
    logic [ADDR_WIDTH-1:0]     btb_write_target;
    logic [BTB_SRAM_WIDTH-1:0] btb_wdata;
    logic [BTB_SRAM_WIDTH-1:0] btb_rdata;

    always_comb begin
        btb_write        = 1'b0;
        btb_addr         = if1_idx;
        btb_write_tag    = '0;
        btb_write_target = '0;

        if (!if1_fire) begin
            if (update_valid_q[0]) begin
                btb_write        = 1'b1;
                btb_addr         = update_idx_q[0];
                btb_write_tag    = update_tag_q[0];
                btb_write_target = update_target_q[0];
            end else if (btb_update_req) begin
                btb_write        = 1'b1;
                btb_addr         = ex_idx;
                btb_write_tag    = ex_tag;
                btb_write_target = ex_actual_target;
            end
        end
    end

    assign btb_wdata = {{BTB_PAD_WIDTH{1'b0}}, btb_write_tag, btb_write_target};
    assign queue_pop = btb_write && update_valid_q[0];
    assign queue_capture = btb_update_req && !(btb_write && !update_valid_q[0]);

    //queue pop, coalesce, append, then drop-oldest on overflow
    integer queue_i;
    always_comb begin
        for (queue_i = 0; queue_i < BTB_UPDATE_DEPTH; queue_i++) begin
            update_idx_d[queue_i]    = update_idx_q[queue_i];
            update_tag_d[queue_i]    = update_tag_q[queue_i];
            update_target_d[queue_i] = update_target_q[queue_i];
        end
        update_valid_d    = update_valid_q;
        queue_match_found = 1'b0;
        queue_append_done = 1'b0;

        if (queue_pop) begin
            for (queue_i = 0; queue_i < BTB_UPDATE_DEPTH-1; queue_i++) begin
                update_idx_d[queue_i]    = update_idx_q[queue_i+1];
                update_tag_d[queue_i]    = update_tag_q[queue_i+1];
                update_target_d[queue_i] = update_target_q[queue_i+1];
            end
            update_idx_d[BTB_UPDATE_DEPTH-1]    = '0;
            update_tag_d[BTB_UPDATE_DEPTH-1]    = '0;
            update_target_d[BTB_UPDATE_DEPTH-1] = '0;
            update_valid_d = {1'b0, update_valid_q[BTB_UPDATE_DEPTH-1:1]};
        end

        if (queue_capture) begin
            for (queue_i = 0; queue_i < BTB_UPDATE_DEPTH; queue_i++) begin
                if (update_valid_d[queue_i] && (update_idx_d[queue_i] == ex_idx)) begin
                    update_tag_d[queue_i]    = ex_tag;
                    update_target_d[queue_i] = ex_actual_target;
                    queue_match_found        = 1'b1;
                end
            end

            if (!queue_match_found) begin
                if (&update_valid_d) begin
                    for (queue_i = 0; queue_i < BTB_UPDATE_DEPTH-1; queue_i++) begin
                        update_idx_d[queue_i]    = update_idx_d[queue_i+1];
                        update_tag_d[queue_i]    = update_tag_d[queue_i+1];
                        update_target_d[queue_i] = update_target_d[queue_i+1];
                    end
                    update_idx_d[BTB_UPDATE_DEPTH-1]    = ex_idx;
                    update_tag_d[BTB_UPDATE_DEPTH-1]    = ex_tag;
                    update_target_d[BTB_UPDATE_DEPTH-1] = ex_actual_target;
                    update_valid_d = '1;
                end else begin
                    for (queue_i = 0; queue_i < BTB_UPDATE_DEPTH; queue_i++) begin
                        if (!update_valid_d[queue_i] && !queue_append_done) begin
                            update_idx_d[queue_i]    = ex_idx;
                            update_tag_d[queue_i]    = ex_tag;
                            update_target_d[queue_i] = ex_actual_target;
                            update_valid_d[queue_i]  = 1'b1;
                            queue_append_done        = 1'b1;
                        end
                    end
                end
            end
        end
    end

    integer queue_ff_i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            update_valid_q <= '0;
            for (queue_ff_i = 0; queue_ff_i < BTB_UPDATE_DEPTH; queue_ff_i++) begin
                update_idx_q[queue_ff_i]    <= '0;
                update_tag_q[queue_ff_i]    <= '0;
                update_target_q[queue_ff_i] <= '0;
            end
        end else begin
            update_valid_q <= update_valid_d;
            for (queue_ff_i = 0; queue_ff_i < BTB_UPDATE_DEPTH; queue_ff_i++) begin
                update_idx_q[queue_ff_i]    <= update_idx_d[queue_ff_i];
                update_tag_q[queue_ff_i]    <= update_tag_d[queue_ff_i];
                update_target_q[queue_ff_i] <= update_target_d[queue_ff_i];
            end
        end
    end

    sram_1024x64_1rw btb_sram (
        .clk   (clk),
        .en    (if1_fire || btb_write),
        .we    (btb_write),
        .addr  (btb_addr),
        .wdata (btb_wdata),
        .rdata (btb_rdata)
    );

    //pending update lookup is captured with the IF1 query
    integer query_i;
    always_comb begin
        query_shadow            = 1'b0;
        query_forward_tag_match = 1'b0;
        query_forward_target    = '0;

        for (query_i = 0; query_i < BTB_UPDATE_DEPTH; query_i++) begin
            if (update_valid_q[query_i] && (update_idx_q[query_i] == if1_idx)) begin
                query_shadow            = 1'b1;
                query_forward_tag_match = (update_tag_q[query_i] == if1_tag);
                query_forward_target    = update_target_q[query_i];
            end
        end

        if (btb_update_req && (ex_idx == if1_idx)) begin
            query_shadow            = 1'b1;
            query_forward_tag_match = (ex_tag == if1_tag);
            query_forward_target    = ex_actual_target;
        end
    end

    //IF2 prediction response
    logic [BTB_TAG_BITS-1:0] btb_read_tag;
    logic [ADDR_WIDTH-1:0]   btb_read_target;
    logic                    btb_sram_hit;
    logic                    btb_forward_hit;
    logic                    btb_hit;

    assign btb_read_tag    = btb_rdata[BTB_DATA_WIDTH-1 -: BTB_TAG_BITS];
    assign btb_read_target = btb_rdata[0 +: ADDR_WIDTH];
    assign btb_sram_hit    = if2_query_valid_q && !if2_shadow_q &&
                             if2_btb_valid_q && (btb_read_tag == if2_tag_q);
    assign btb_forward_hit = if2_query_valid_q && if2_shadow_q &&
                             if2_forward_tag_match_q;
    assign btb_hit     = btb_sram_hit || btb_forward_hit;
    assign pred_taken  = btb_hit && (if2_bht_q >= WEAKLY_T);
    assign pred_target = btb_forward_hit ? if2_forward_target_q :
                         btb_sram_hit ? btb_read_target : '0;
endmodule
