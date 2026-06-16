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
// Module       : dcache_7stg
// Description  : 4KB 2-way set-associative D-Cache for 7-stage pipeline.
//                Request side launches synchronous SRAM read.
//                Response side consumes SRAM dout, checks tag, and returns data.
//                Write-through + write-buffer forwarding behavior is preserved.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-16
// Version      : 1.2
// Changes v1.2 : Store-hit update uses 1RW SRAM safely before next launch.
// -----------------------------------------------------------------------------

module dcache_7stg
    import cache_pkg::*;
(
    //system
    input logic clk, rst_n,

    //request side - launch SRAM read
    input logic [DC_IDX_BITS-1:0]   req_idx,
    input logic                     mem_req,

    //response metadata - from external pipeline
    input logic                     resp_valid,
    input logic                     resp_we,
    input logic [DC_TAG_BITS-1:0]   resp_tag,
    input logic [DC_IDX_BITS-1:0]   resp_idx,
    input logic [WORD_SEL_BITS-1:0] resp_word_sel,
    input logic                     resp_uncacheable,
    input logic [ADDR_WIDTH-1:0]    resp_line_addr,
    input logic [DATA_WIDTH-1:0]    resp_wdata,
    input logic [STRB_WIDTH-1:0]    resp_wstrb,

    //response side - to LSU2
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
    localparam LINE_WIDTH = DATA_WIDTH * WORDS_PER_LINE;

    //SRAM storage
    logic                           tag_csb;
    logic                           tag_web;
    logic [DC_IDX_BITS-1:0]         tag_addr;
    logic [DC_TAG_BITS*DC_WAYS-1:0] tag_din;
    logic [DC_TAG_BITS*DC_WAYS-1:0] tag_dout;
    logic [DC_WAYS-1:0]             tag_wmask;

    logic                           data0_csb;
    logic                           data0_web;
    logic [DC_IDX_BITS-1:0]         data0_addr;
    logic [LINE_WIDTH-1:0]          data0_din;
    logic [LINE_WIDTH-1:0]          data0_dout;
    logic [WORDS_PER_LINE-1:0]      data0_wmask;

    logic                           data1_csb;
    logic                           data1_web;
    logic [DC_IDX_BITS-1:0]         data1_addr;
    logic [LINE_WIDTH-1:0]          data1_din;
    logic [LINE_WIDTH-1:0]          data1_dout;
    logic [WORDS_PER_LINE-1:0]      data1_wmask;

    logic [DC_SETS-1:0][DC_WAYS-1:0] cache_valid;
    logic [DC_SETS-1:0]              lru;

    sram_1rw #(
        .ADDR_W  (DC_IDX_BITS),
        .DATA_W  (DC_TAG_BITS * DC_WAYS),
        .DEPTH   (DC_SETS),
        .WMASK_W (DC_WAYS)
    ) tag_sram (
        .clk   (clk),
        .csb   (tag_csb),
        .web   (tag_web),
        .wmask (tag_wmask),
        .addr  (tag_addr),
        .din   (tag_din),
        .dout  (tag_dout)
    );

    sram_1rw #(
        .ADDR_W  (DC_IDX_BITS),
        .DATA_W  (LINE_WIDTH),
        .DEPTH   (DC_SETS),
        .WMASK_W (WORDS_PER_LINE)
    ) data_way0_sram (
        .clk   (clk),
        .csb   (data0_csb),
        .web   (data0_web),
        .wmask (data0_wmask),
        .addr  (data0_addr),
        .din   (data0_din),
        .dout  (data0_dout)
    );

    sram_1rw #(
        .ADDR_W  (DC_IDX_BITS),
        .DATA_W  (LINE_WIDTH),
        .DEPTH   (DC_SETS),
        .WMASK_W (WORDS_PER_LINE)
    ) data_way1_sram (
        .clk   (clk),
        .csb   (data1_csb),
        .web   (data1_web),
        .wmask (data1_wmask),
        .addr  (data1_addr),
        .din   (data1_din),
        .dout  (data1_dout)
    );

    //response lookup
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

    assign way_hit[0] = resp_valid && cache_valid[resp_idx][0] && (tag_way0 == resp_tag);
    assign way_hit[1] = resp_valid && cache_valid[resp_idx][1] && (tag_way1 == resp_tag);
    assign cache_hit  = |way_hit && !resp_uncacheable;
    assign hit_way    = way_hit[1];

    assign data0_word  = data0_dout[resp_word_sel*DATA_WIDTH +: DATA_WIDTH];
    assign data1_word  = data1_dout[resp_word_sel*DATA_WIDTH +: DATA_WIDTH];
    assign cache_rdata = hit_way ? data1_word : data0_word;

    //write-buffer forwarding
    logic [DATA_WIDTH-1:0] merged_rdata;
    logic                  fwd_hit_eff;
    logic                  fwd_full_cover;

    assign fwd_addr       = resp_line_addr;
    assign fwd_hit_eff    = fwd_hit && !resp_uncacheable;
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
    logic req_launch_ok;

    assign load_req         = resp_valid && !resp_we;
    assign load_hit         = load_req && cache_hit;
    assign load_fwd_full    = load_req && fwd_full_cover;
    assign load_miss_real   = load_req && !cache_hit && !fwd_full_cover;
    assign store_req        = resp_valid && resp_we;
    assign store_accept     = store_req && !wb_full;
    assign store_hit_update = store_accept && cache_hit;

    //launch only when response side will not occupy SRAM next cycle
    assign req_launch_ok = !resp_valid ||
                           load_hit ||
                           load_fwd_full ||
                           (store_accept && !cache_hit);

    //store hit update
    logic [LINE_WIDTH-1:0]     hit_line;
    logic [LINE_WIDTH-1:0]     store_line_next;
    logic [WORDS_PER_LINE-1:0] store_wmask_next;
    logic [ADDR_WIDTH-1:0]     store_addr_q;
    logic [DATA_WIDTH-1:0]     store_wdata_q;
    logic [STRB_WIDTH-1:0]     store_wstrb_q;

    assign hit_line = hit_way ? data1_dout : data0_dout;

    always_comb begin
        store_line_next = hit_line;
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (resp_wstrb[b])
                store_line_next[resp_word_sel*DATA_WIDTH + b*8 +: 8] = resp_wdata[b*8 +: 8];
        end
    end

    always_comb begin
        store_wmask_next = '0;
        store_wmask_next[resp_word_sel] = 1'b1;
    end

    //refill buffer
    logic [DATA_WIDTH-1:0]      rf_buffer [WORDS_PER_LINE];
    logic [WORDS_PER_LINE-1:0]  rf_valid;
    logic [DC_TAG_BITS-1:0]     rf_tag;
    logic [DC_IDX_BITS-1:0]     rf_idx;
    logic [WORD_SEL_BITS-1:0]   rf_word_sel;
    logic                       rf_uncacheable;

    logic                       rf_buffer_hit;
    logic [DATA_WIDTH-1:0]      rf_merged_rdata;
    logic                       cwf_valid;

    assign rf_buffer_hit = rf_valid[resp_word_sel] &&
                           (rf_idx == resp_idx) &&
                           (rf_tag == resp_tag);
    assign cwf_valid     = load_req && rf_buffer_hit;

    always_comb begin
        for (int b = 0; b < STRB_WIDTH; b++) begin
            if (fwd_hit_eff && fwd_strb[b])
                rf_merged_rdata[b*8 +: 8] = fwd_data[b*8 +: 8];
            else
                rf_merged_rdata[b*8 +: 8] = rf_buffer[resp_word_sel][b*8 +: 8];
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

    //refill write data packing
    logic [LINE_WIDTH-1:0] refill_line;

    always_comb begin
        refill_line = '0;
        for (int w = 0; w < WORDS_PER_LINE; w++)
            refill_line[w*DATA_WIDTH +: DATA_WIDTH] = rf_buffer[w];
    end

    //fsm
    typedef enum logic [2:0] {
        IDLE,
        STORE_DONE,
        REFILL_REQ,
        REFILL_DATA,
        REFILL_DONE
    } state_t;

    state_t state, next_state;

    //FSM: next state logic
    always_comb begin
        next_state = state;

        case (state)
            IDLE: begin
                if (load_miss_real)
                    next_state = REFILL_REQ;
                else if (store_hit_update)
                    next_state = STORE_DONE;
            end

            STORE_DONE: begin
                if (!wb_full)
                    next_state = IDLE;
            end

            REFILL_REQ: begin
                if (arb_grant)
                    next_state = REFILL_DATA;
            end

            REFILL_DATA: begin
                if (arb_valid && arb_last)
                    next_state = REFILL_DONE;
            end

            REFILL_DONE: begin
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
            state       <= IDLE;
            cache_valid <= '0;
            rf_valid    <= '0;
            lru         <= '0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (load_hit)
                        lru[resp_idx] <= ~hit_way;
                    else if (store_hit_update)
                        lru[resp_idx] <= ~hit_way;
                    else if (load_miss_real)
                        rf_valid <= '0;
                end

                STORE_DONE: begin
                end

                REFILL_REQ: begin
                end

                REFILL_DATA: begin
                    if (arb_valid)
                        rf_valid[rf_word_sel] <= 1'b1;
                end

                REFILL_DONE: begin
                    if (!rf_uncacheable) begin
                        cache_valid[rf_idx][evict_way] <= 1'b1;
                        lru[rf_idx] <= ~evict_way;
                    end
                    rf_valid <= '0;
                end

                default: begin
                end
            endcase
        end
    end

    //FSM: data registers
    always_ff @(posedge clk) begin
        case (state)
            IDLE: begin
                if (load_miss_real) begin
                    rf_tag         <= resp_tag;
                    rf_idx         <= resp_idx;
                    rf_word_sel    <= resp_word_sel;
                    rf_uncacheable <= resp_uncacheable;
                end else if (store_hit_update) begin
                    store_addr_q  <= resp_line_addr;
                    store_wdata_q <= resp_wdata;
                    store_wstrb_q <= resp_wstrb;
                end
            end

            STORE_DONE: begin
            end

            REFILL_REQ: begin
            end

            REFILL_DATA: begin
                if (arb_valid) begin
                    rf_buffer[rf_word_sel] <= arb_rdata;
                    rf_word_sel            <= rf_word_sel + 1'b1;
                end
            end

            REFILL_DONE: begin
            end

            default: begin
            end
        endcase
    end

    //SRAM control
    always_comb begin
        tag_csb       = 1'b1;
        tag_web       = 1'b1;
        tag_addr      = req_idx;
        tag_din       = {DC_WAYS{rf_tag}};
        tag_wmask     = '0;

        data0_csb     = 1'b1;
        data0_web     = 1'b1;
        data0_addr    = req_idx;
        data0_din     = refill_line;
        data0_wmask   = '0;

        data1_csb     = 1'b1;
        data1_web     = 1'b1;
        data1_addr    = req_idx;
        data1_din     = refill_line;
        data1_wmask   = '0;

        case (state)
            IDLE: begin
                if (store_hit_update) begin
                    if (!hit_way) begin
                        data0_csb   = 1'b0;
                        data0_web   = 1'b0;
                        data0_addr  = resp_idx;
                        data0_din   = store_line_next;
                        data0_wmask = store_wmask_next;
                    end else begin
                        data1_csb   = 1'b0;
                        data1_web   = 1'b0;
                        data1_addr  = resp_idx;
                        data1_din   = store_line_next;
                        data1_wmask = store_wmask_next;
                    end
                end else if (mem_req && req_launch_ok) begin
                    tag_csb    = 1'b0;
                    tag_web    = 1'b1;
                    tag_addr   = req_idx;

                    data0_csb  = 1'b0;
                    data0_web  = 1'b1;
                    data0_addr = req_idx;

                    data1_csb  = 1'b0;
                    data1_web  = 1'b1;
                    data1_addr = req_idx;
                end
            end

            STORE_DONE: begin
                if (!wb_full && mem_req) begin
                    tag_csb    = 1'b0;
                    tag_web    = 1'b1;
                    tag_addr   = req_idx;

                    data0_csb  = 1'b0;
                    data0_web  = 1'b1;
                    data0_addr = req_idx;

                    data1_csb  = 1'b0;
                    data1_web  = 1'b1;
                    data1_addr = req_idx;
                end
            end

            REFILL_REQ: begin
            end

            REFILL_DATA: begin
            end

            REFILL_DONE: begin
                if (!rf_uncacheable) begin
                    tag_csb   = 1'b0;
                    tag_web   = 1'b0;
                    tag_addr  = rf_idx;
                    tag_din   = {DC_WAYS{rf_tag}};
                    tag_wmask = evict_way ? 2'b10 : 2'b01;

                    if (!evict_way) begin
                        data0_csb   = 1'b0;
                        data0_web   = 1'b0;
                        data0_addr  = rf_idx;
                        data0_din   = refill_line;
                        data0_wmask = {WORDS_PER_LINE{1'b1}};
                    end else begin
                        data1_csb   = 1'b0;
                        data1_web   = 1'b0;
                        data1_addr  = rf_idx;
                        data1_din   = refill_line;
                        data1_wmask = {WORDS_PER_LINE{1'b1}};
                    end
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
                if (!resp_valid) begin
                    dcache_ready = 1'b1;
                end else if (store_req) begin
                    if (!wb_full && !cache_hit) begin
                        wb_push      = 1'b1;
                        wb_addr      = resp_line_addr;
                        wb_data      = resp_wdata;
                        wb_strb      = resp_wstrb;
                        dcache_valid = 1'b1;
                        dcache_ready = 1'b1;
                    end
                end else begin
                    if (load_hit) begin
                        rdata        = merged_rdata;
                        dcache_valid = 1'b1;
                        dcache_ready = 1'b1;
                    end else if (load_fwd_full) begin
                        rdata        = fwd_data;
                        dcache_valid = 1'b1;
                        dcache_ready = 1'b1;
                    end
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

            REFILL_DONE: begin
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
