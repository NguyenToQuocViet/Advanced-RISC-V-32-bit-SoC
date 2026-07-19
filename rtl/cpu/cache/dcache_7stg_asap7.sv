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
// Module       : dcache_7stg_asap7
// Description  : 4KB 2-way set-associative D-Cache for 7-stage pipeline.
//                D-Cache owns SRAM lookup metadata internally, same contract as
//                I-Cache: request in cycle N, response resolved in cycle N+1.
//                Write-through + write-buffer forwarding behavior is preserved.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-16
// Version      : 2.2
// Changes v2.0 : Restore 5-stage external interface; latch lookup metadata
//                inside cache for SRAM response alignment.
// Changes v2.1 : Uncacheable refill still returns data; only cache allocate is blocked.
// Changes v2.2 : Snapshot partial forwarding bytes for the full refill lifetime.
// -----------------------------------------------------------------------------

module dcache_7stg_asap7
    import cache_pkg::*;
(
    //system
    input logic clk, rst_n,

    //lsu - d-cache interface
    input logic [ADDR_WIDTH-1:0]    addr,
    input logic                     mem_req,
    input logic                     mem_we,

    input logic [DATA_WIDTH-1:0]    wdata,
    input logic [STRB_WIDTH-1:0]    wstrb,

    output logic [DATA_WIDTH-1:0]   rdata,
    output logic                    dcache_ready,
    output logic                    dcache_valid,

    //write buffer - d-cache interface
    output logic                    wb_push,
    output logic [ADDR_WIDTH-1:0]   wb_addr,
    output logic [DATA_WIDTH-1:0]   wb_data,
    output logic [STRB_WIDTH-1:0]   wb_strb,

    input logic                     wb_full,

    //write buffer forwarding
    output logic [ADDR_WIDTH-1:0]   fwd_addr,

    input logic                     fwd_hit,
    input logic [DATA_WIDTH-1:0]    fwd_data,
    input logic [STRB_WIDTH-1:0]    fwd_strb,

    //arbiter - d-cache interface
    input logic [DATA_WIDTH-1:0]    arb_rdata,
    input logic                     arb_valid,
    input logic                     arb_last,
    input logic                     arb_grant,

    output logic                    dcache_req,
    output logic [ADDR_WIDTH-1:0]   dcache_addr
);
    localparam PAIR_WIDTH       = DATA_WIDTH * 2;
    localparam PAIR_ADDR_WIDTH  = DC_IDX_BITS + 1;
    localparam TAG_ARRAY_WIDTH  = 48;
    localparam TAG_ADDR_WIDTH   = 8;
    localparam TAG_PAD_WIDTH    = TAG_ARRAY_WIDTH - (DC_TAG_BITS * DC_WAYS);

    //address decode - live MEM1 request
    logic [WORD_SEL_BITS-1:0] addr_word_sel;
    logic [DC_IDX_BITS-1:0]   addr_idx;
    logic [DC_TAG_BITS-1:0]   addr_tag;
    logic [ADDR_WIDTH-1:0]    addr_word_base;
    logic                     addr_uncacheable;

    assign addr_word_sel    = addr[WORD_OFF_BITS +: WORD_SEL_BITS];
    assign addr_idx         = addr[LINE_OFF_BITS +: DC_IDX_BITS];
    assign addr_tag         = addr[ADDR_WIDTH-1 -: DC_TAG_BITS];
    assign addr_word_base   = addr & {{(ADDR_WIDTH-WORD_OFF_BITS){1'b1}}, {WORD_OFF_BITS{1'b0}}};
    assign addr_uncacheable = (addr[ADDR_WIDTH-1 -: 4] == 4'h1);

    //lookup metadata - delayed to align with SRAM dout
    logic                       lookup_valid_q;
    logic                       lookup_we_q;
    logic [DC_TAG_BITS-1:0]     lookup_tag_q;
    logic [DC_IDX_BITS-1:0]     lookup_idx_q;
    logic [WORD_SEL_BITS-1:0]   lookup_word_sel_q;
    logic                       lookup_uncacheable_q;
    logic [ADDR_WIDTH-1:0]      lookup_word_base_q;
    logic [DATA_WIDTH-1:0]      lookup_wdata_q;
    logic [STRB_WIDTH-1:0]      lookup_wstrb_q;

    //SRAM storage
    logic                           tag_en;
    logic                           tag_we;
    logic [TAG_ADDR_WIDTH-1:0]      tag_addr;
    logic [TAG_ARRAY_WIDTH-1:0]     tag_din;
    logic [TAG_ARRAY_WIDTH-1:0]     tag_dout;

    logic                           data0_en;
    logic                           data0_we;
    logic [PAIR_ADDR_WIDTH-1:0]     data0_addr;
    logic [PAIR_WIDTH-1:0]          data0_din;
    logic [PAIR_WIDTH-1:0]          data0_dout;

    logic                           data1_en;
    logic                           data1_we;
    logic [PAIR_ADDR_WIDTH-1:0]     data1_addr;
    logic [PAIR_WIDTH-1:0]          data1_din;
    logic [PAIR_WIDTH-1:0]          data1_dout;

    logic [DC_SETS-1:0][DC_WAYS-1:0] cache_valid;
    logic [DC_SETS-1:0]              lru;

    sram_256x48_1rw tag_sram (
        .clk   (clk),
        .en    (tag_en),
        .we    (tag_we),
        .addr  (tag_addr),
        .wdata (tag_din),
        .rdata (tag_dout)
    );

    sram_256x64_1rw data_way0_sram (
        .clk   (clk),
        .en    (data0_en),
        .we    (data0_we),
        .addr  (data0_addr),
        .wdata (data0_din),
        .rdata (data0_dout)
    );

    sram_256x64_1rw data_way1_sram (
        .clk   (clk),
        .en    (data1_en),
        .we    (data1_we),
        .addr  (data1_addr),
        .wdata (data1_din),
        .rdata (data1_dout)
    );

    //lookup result
    logic [DC_TAG_BITS-1:0] tag_way0;
    logic [DC_TAG_BITS-1:0] tag_way1;
    logic [DC_WAYS-1:0]     way_hit;
    logic                   cache_hit;
    logic                   hit_way;
    logic [DATA_WIDTH-1:0]  data0_word;
    logic [DATA_WIDTH-1:0]  data1_word;
    logic [DATA_WIDTH-1:0]  cache_rdata;

    assign tag_way0 = tag_dout[0*DC_TAG_BITS +: DC_TAG_BITS];
    assign tag_way1 = tag_dout[1*DC_TAG_BITS +: DC_TAG_BITS];

    assign way_hit[0] = lookup_valid_q && cache_valid[lookup_idx_q][0] && (tag_way0 == lookup_tag_q);
    assign way_hit[1] = lookup_valid_q && cache_valid[lookup_idx_q][1] && (tag_way1 == lookup_tag_q);
    assign cache_hit  = |way_hit && !lookup_uncacheable_q;
    assign hit_way    = way_hit[1];

    assign data0_word  = data0_dout[lookup_word_sel_q[0]*DATA_WIDTH +: DATA_WIDTH];
    assign data1_word  = data1_dout[lookup_word_sel_q[0]*DATA_WIDTH +: DATA_WIDTH];
    assign cache_rdata = hit_way ? data1_word : data0_word;

    //write-buffer forwarding
    logic [DATA_WIDTH-1:0] merged_rdata;
    logic                  fwd_hit_eff;
    logic                  fwd_full_cover;

    assign fwd_addr       = lookup_word_base_q;
    assign fwd_hit_eff    = fwd_hit && !lookup_uncacheable_q;
    assign fwd_full_cover = fwd_hit_eff && (&fwd_strb);

    always_comb begin
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (fwd_hit_eff && fwd_strb[b])
                merged_rdata[b*8 +: 8] = fwd_data[b*8 +: 8];
            else
                merged_rdata[b*8 +: 8] = cache_rdata[b*8 +: 8];
        end
    end

    //request class
    logic load_req;
    logic load_hit;
    logic load_fwd_full;
    logic load_miss_real;
    logic store_req;
    logic store_accept;
    logic store_hit_update;
    logic store_miss_accept;
    logic lookup_done;

    assign load_req         = lookup_valid_q && !lookup_we_q;
    assign load_hit         = load_req && cache_hit;
    assign load_fwd_full    = load_req && fwd_full_cover;
    assign load_miss_real   = load_req && !cache_hit && !fwd_full_cover;
    assign store_req        = lookup_valid_q && lookup_we_q;
    assign store_accept     = store_req && !wb_full;
    assign store_hit_update = store_accept && cache_hit;
    assign store_miss_accept = store_accept && !cache_hit;
    assign lookup_done      = load_hit || load_fwd_full || store_miss_accept;

    //store hit update
    logic [PAIR_WIDTH-1:0]     hit_pair;
    logic [PAIR_WIDTH-1:0]     store_pair_next;
    logic [ADDR_WIDTH-1:0]     store_addr_q;
    logic [DATA_WIDTH-1:0]     store_wdata_q;
    logic [STRB_WIDTH-1:0]     store_wstrb_q;

    assign hit_pair = hit_way ? data1_dout : data0_dout;

    always_comb begin
        store_pair_next = hit_pair;
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (lookup_wstrb_q[b])
                store_pair_next[lookup_word_sel_q[0]*DATA_WIDTH + b*8 +: 8] = lookup_wdata_q[b*8 +: 8];
        end
    end

    //refill buffer
    logic [DATA_WIDTH-1:0]      rf_buffer [WORDS_PER_LINE];
    logic [WORDS_PER_LINE-1:0]  rf_valid;
    logic [DC_TAG_BITS-1:0]     rf_tag;
    logic [DC_IDX_BITS-1:0]     rf_idx;
    logic [WORD_SEL_BITS-1:0]   rf_word_sel;
    logic                       rf_uncacheable;
    logic [DATA_WIDTH-1:0]      rf_fwd_data;
    logic [STRB_WIDTH-1:0]      rf_fwd_strb;

    logic                       rf_buffer_hit;
    logic [DATA_WIDTH-1:0]      rf_merged_rdata;
    logic                       cwf_valid;

    assign rf_buffer_hit = lookup_valid_q &&
                           rf_valid[lookup_word_sel_q] &&
                           (rf_idx == lookup_idx_q) &&
                           (rf_tag == lookup_tag_q);
    assign cwf_valid     = load_req && rf_buffer_hit;

    always_comb begin
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (rf_fwd_strb[b])
                rf_merged_rdata[b*8 +: 8] = rf_fwd_data[b*8 +: 8];
            else
                rf_merged_rdata[b*8 +: 8] = rf_buffer[lookup_word_sel_q][b*8 +: 8];
        end
    end

    //eviction way selection
    logic evict_way;

    always_comb begin
        if (!cache_valid[rf_idx][0])
            evict_way = 1'b0;
        else if (!cache_valid[rf_idx][1])
            evict_way = 1'b1;
        else
            evict_way = lru[rf_idx];
    end

    //tag full-write merge
    logic [DC_TAG_BITS-1:0]     tag_write_way0;
    logic [DC_TAG_BITS-1:0]     tag_write_way1;
    logic [TAG_ARRAY_WIDTH-1:0] tag_write_data;

    always_comb begin
        tag_write_way0 = tag_way0;
        tag_write_way1 = tag_way1;

        if (evict_way)
            tag_write_way1 = rf_tag;
        else
            tag_write_way0 = rf_tag;

        tag_write_data = {{TAG_PAD_WIDTH{1'b0}}, tag_write_way1, tag_write_way0};
    end

    //refill write data packing
    logic [PAIR_WIDTH-1:0] refill_pair_lo;
    logic [PAIR_WIDTH-1:0] refill_pair_hi;

    assign refill_pair_lo = {rf_buffer[1], rf_buffer[0]};
    assign refill_pair_hi = {rf_buffer[3], rf_buffer[2]};

    //fsm
    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        STORE_DONE,
        REFILL_REQ,
        REFILL_DATA,
        REFILL_COMMIT_LO,
        REFILL_COMMIT_HI
    } state_t;

    state_t state, next_state;

    //FSM: next state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (mem_req)
                    next_state = LOOKUP;
            end

            LOOKUP: begin
                if (load_miss_real)
                    next_state = REFILL_REQ;
                else if (store_hit_update)
                    next_state = STORE_DONE;
                else if (lookup_done)
                    next_state = mem_req ? LOOKUP : IDLE;
            end

            STORE_DONE: begin
                if (!wb_full)
                    next_state = mem_req ? LOOKUP : IDLE;
            end

            REFILL_REQ: begin
                if (arb_grant)
                    next_state = REFILL_DATA;
            end

            REFILL_DATA: begin
                if (arb_valid && arb_last)
                    next_state = rf_uncacheable ? IDLE : REFILL_COMMIT_LO;
            end

            REFILL_COMMIT_LO: begin
                next_state = REFILL_COMMIT_HI;
            end

            REFILL_COMMIT_HI: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    //FSM: control registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            cache_valid    <= '0;
            rf_valid       <= '0;
            lru            <= '0;
            lookup_valid_q <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    lookup_valid_q <= mem_req;
                end

                LOOKUP: begin
                    if (load_hit)
                        lru[lookup_idx_q] <= ~hit_way;
                    else if (store_hit_update)
                        lru[lookup_idx_q] <= ~hit_way;
                    else if (load_miss_real)
                        rf_valid <= '0;

                    if (lookup_done)
                        lookup_valid_q <= mem_req;
                    else if (store_hit_update || load_miss_real)
                        lookup_valid_q <= lookup_valid_q;
                end

                STORE_DONE: begin
                    if (!wb_full)
                        lookup_valid_q <= mem_req;
                end

                REFILL_REQ: begin
                end

                REFILL_DATA: begin
                    if (arb_valid)
                        rf_valid[rf_word_sel] <= 1'b1;
                    if (arb_valid && arb_last && rf_uncacheable) begin
                        rf_valid       <= '0;
                        lookup_valid_q <= 1'b0;
                    end
                end

                REFILL_COMMIT_LO: begin
                end

                REFILL_COMMIT_HI: begin
                    cache_valid[rf_idx][evict_way] <= 1'b1;
                    lru[rf_idx] <= ~evict_way;
                    rf_valid       <= '0;
                    lookup_valid_q <= 1'b0;
                end

                default: begin
                    lookup_valid_q <= 1'b0;
                end
            endcase
        end
    end

    //FSM: data registers
    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                if (mem_req) begin
                    lookup_we_q          <= mem_we;
                    lookup_tag_q         <= addr_tag;
                    lookup_idx_q         <= addr_idx;
                    lookup_word_sel_q    <= addr_word_sel;
                    lookup_uncacheable_q <= addr_uncacheable;
                    lookup_word_base_q   <= addr_word_base;
                    lookup_wdata_q       <= wdata;
                    lookup_wstrb_q       <= wstrb;
                end
            end

            LOOKUP: begin
                if (lookup_done && mem_req) begin
                    lookup_we_q          <= mem_we;
                    lookup_tag_q         <= addr_tag;
                    lookup_idx_q         <= addr_idx;
                    lookup_word_sel_q    <= addr_word_sel;
                    lookup_uncacheable_q <= addr_uncacheable;
                    lookup_word_base_q   <= addr_word_base;
                    lookup_wdata_q       <= wdata;
                    lookup_wstrb_q       <= wstrb;
                end

                if (load_miss_real) begin
                    rf_tag         <= lookup_tag_q;
                    rf_idx         <= lookup_idx_q;
                    rf_word_sel    <= lookup_word_sel_q;
                    rf_uncacheable <= lookup_uncacheable_q;
                    rf_fwd_data    <= fwd_data;
                    rf_fwd_strb    <= fwd_hit_eff ? fwd_strb : '0;
                end else if (store_hit_update) begin
                    store_addr_q  <= lookup_word_base_q;
                    store_wdata_q <= lookup_wdata_q;
                    store_wstrb_q <= lookup_wstrb_q;
                end
            end

            STORE_DONE: begin
                if (!wb_full && mem_req) begin
                    lookup_we_q          <= mem_we;
                    lookup_tag_q         <= addr_tag;
                    lookup_idx_q         <= addr_idx;
                    lookup_word_sel_q    <= addr_word_sel;
                    lookup_uncacheable_q <= addr_uncacheable;
                    lookup_word_base_q   <= addr_word_base;
                    lookup_wdata_q       <= wdata;
                    lookup_wstrb_q       <= wstrb;
                end
            end

            REFILL_REQ: begin
            end

            REFILL_DATA: begin
                if (arb_valid) begin
                    rf_buffer[rf_word_sel] <= arb_rdata;
                    rf_word_sel            <= rf_word_sel + 1'b1;
                end
            end

            REFILL_COMMIT_LO: begin
            end

            REFILL_COMMIT_HI: begin
            end

            default: begin
            end
        endcase
    end

    //SRAM control
    always_comb begin
        tag_en        = 1'b0;
        tag_we        = 1'b0;
        tag_addr      = {{(TAG_ADDR_WIDTH-DC_IDX_BITS){1'b0}}, addr_idx};
        tag_din       = tag_write_data;

        data0_en      = 1'b0;
        data0_we      = 1'b0;
        data0_addr    = {addr_idx, addr_word_sel[1]};
        data0_din     = '0;

        data1_en      = 1'b0;
        data1_we      = 1'b0;
        data1_addr    = {addr_idx, addr_word_sel[1]};
        data1_din     = '0;

        case (state)
            IDLE: begin
                if (mem_req) begin
                    tag_en     = 1'b1;
                    tag_we     = 1'b0;
                    tag_addr   = {{(TAG_ADDR_WIDTH-DC_IDX_BITS){1'b0}}, addr_idx};

                    data0_en   = 1'b1;
                    data0_we   = 1'b0;
                    data0_addr = {addr_idx, addr_word_sel[1]};

                    data1_en   = 1'b1;
                    data1_we   = 1'b0;
                    data1_addr = {addr_idx, addr_word_sel[1]};
                end
            end

            LOOKUP: begin
                if (store_hit_update) begin
                    if (!hit_way) begin
                        data0_en   = 1'b1;
                        data0_we   = 1'b1;
                        data0_addr = {lookup_idx_q, lookup_word_sel_q[1]};
                        data0_din  = store_pair_next;
                    end else begin
                        data1_en   = 1'b1;
                        data1_we   = 1'b1;
                        data1_addr = {lookup_idx_q, lookup_word_sel_q[1]};
                        data1_din  = store_pair_next;
                    end
                end else if (lookup_done && mem_req) begin
                    tag_en     = 1'b1;
                    tag_we     = 1'b0;
                    tag_addr   = {{(TAG_ADDR_WIDTH-DC_IDX_BITS){1'b0}}, addr_idx};

                    data0_en   = 1'b1;
                    data0_we   = 1'b0;
                    data0_addr = {addr_idx, addr_word_sel[1]};

                    data1_en   = 1'b1;
                    data1_we   = 1'b0;
                    data1_addr = {addr_idx, addr_word_sel[1]};
                end
            end

            STORE_DONE: begin
                if (!wb_full && mem_req) begin
                    tag_en     = 1'b1;
                    tag_we     = 1'b0;
                    tag_addr   = {{(TAG_ADDR_WIDTH-DC_IDX_BITS){1'b0}}, addr_idx};

                    data0_en   = 1'b1;
                    data0_we   = 1'b0;
                    data0_addr = {addr_idx, addr_word_sel[1]};

                    data1_en   = 1'b1;
                    data1_we   = 1'b0;
                    data1_addr = {addr_idx, addr_word_sel[1]};
                end
            end

            REFILL_REQ: begin
            end

            REFILL_DATA: begin
            end

            REFILL_COMMIT_LO: begin
                if (!evict_way) begin
                    data0_en   = 1'b1;
                    data0_we   = 1'b1;
                    data0_addr = {rf_idx, 1'b0};
                    data0_din  = refill_pair_lo;
                end else begin
                    data1_en   = 1'b1;
                    data1_we   = 1'b1;
                    data1_addr = {rf_idx, 1'b0};
                    data1_din  = refill_pair_lo;
                end
            end

            REFILL_COMMIT_HI: begin
                tag_en   = 1'b1;
                tag_we   = 1'b1;
                tag_addr = {{(TAG_ADDR_WIDTH-DC_IDX_BITS){1'b0}}, rf_idx};
                tag_din  = tag_write_data;

                if (!evict_way) begin
                    data0_en   = 1'b1;
                    data0_we   = 1'b1;
                    data0_addr = {rf_idx, 1'b1};
                    data0_din  = refill_pair_hi;
                end else begin
                    data1_en   = 1'b1;
                    data1_we   = 1'b1;
                    data1_addr = {rf_idx, 1'b1};
                    data1_din  = refill_pair_hi;
                end
            end

            default: begin
            end
        endcase
    end

    //FSM: output logic
    always_comb begin
        rdata        = '0;
        dcache_valid = 1'b0;
        dcache_ready = 1'b0;

        wb_push      = 1'b0;
        wb_addr      = '0;
        wb_data      = '0;
        wb_strb      = '0;

        case (state)
            IDLE: begin
                dcache_ready = 1'b1;
            end

            LOOKUP: begin
                if (load_hit) begin
                    rdata        = merged_rdata;
                    dcache_valid = 1'b1;
                    dcache_ready = 1'b1;
                end else if (load_fwd_full) begin
                    rdata        = fwd_data;
                    dcache_valid = 1'b1;
                    dcache_ready = 1'b1;
                end else if (store_miss_accept) begin
                    wb_push      = 1'b1;
                    wb_addr      = lookup_word_base_q;
                    wb_data      = lookup_wdata_q;
                    wb_strb      = lookup_wstrb_q;
                    dcache_valid = 1'b1;
                    dcache_ready = 1'b1;
                end
            end

            STORE_DONE: begin
                if (!wb_full) begin
                    wb_push      = 1'b1;
                    wb_addr      = store_addr_q;
                    wb_data      = store_wdata_q;
                    wb_strb      = store_wstrb_q;
                    dcache_valid = 1'b1;
                    dcache_ready = 1'b1;
                end
            end

            REFILL_REQ: begin
                dcache_ready = 1'b0;
            end

            REFILL_DATA: begin
                if (cwf_valid) begin
                    rdata        = rf_merged_rdata;
                    dcache_valid = 1'b1;
                end
                dcache_ready = 1'b0;
            end

            REFILL_COMMIT_LO: begin
                if (cwf_valid) begin
                    rdata        = rf_merged_rdata;
                    dcache_valid = 1'b1;
                end
                dcache_ready = 1'b0;
            end

            REFILL_COMMIT_HI: begin
                if (cwf_valid) begin
                    rdata        = rf_merged_rdata;
                    dcache_valid = 1'b1;
                end
                dcache_ready = 1'b0;
            end

            default: begin
                dcache_ready = 1'b0;
            end
        endcase
    end

    //Bus Arbiter
    assign dcache_req  = (state == REFILL_REQ);
    assign dcache_addr = {rf_tag, rf_idx, rf_word_sel, {WORD_OFF_BITS{1'b0}}};
endmodule
