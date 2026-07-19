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
// Module       : icache_7stg_fpga
// Description  : 4KB direct-mapped I-Cache for 7-stage pipeline.
//                IF1 launches synchronous SRAM read.
//                IF2 receives SRAM dout, performs tag compare, and returns instr.
//                Refill buffer supports same-line early restart.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-05-07
// Version      : 2.6
// Changes v2.6 : keep speculative refill and commit line after lookup flush.
// Changes v2.5 : use lookup metadata as one-entry request slot.
//                Serve any available word from the active refill buffer.
// Changes v2.4 : keep flush_refill out of same-cycle response-valid path.
// Changes v2.3 : REFILL_DONE deasserts ready while 1RW SRAM commits refill line.
// Changes v2.2 : SRAM-based tag/data storage using sram_1rw wrappers.
//                Adds LOOKUP state for sync-read return timing.
//                Hit/refill/CWF decisions use delayed PC metadata.
//                LOOKUP returns current hit and launches next lookup in
//                the same cycle to preserve 1 instr/cycle clean-hit throughput.
// -----------------------------------------------------------------------------

module icache_7stg_fpga
    import cache_pkg::*;
(
    //system
    input logic clk, rst_n,

    //IF - i-cache interface
    input logic [ADDR_WIDTH-1:0] pc,
    input logic if_req,
    input logic icache_consume,

    output logic [DATA_WIDTH-1:0] instr,
    output logic icache_ready,
    output logic icache_valid,

    //refill abandon - core mispredict feedback
    input logic flush_refill,

    //arbiter - i-cache interface
    input logic [DATA_WIDTH-1:0] arb_rdata,
    input logic arb_valid,
    input logic arb_last,
    input logic arb_grant,

    output logic icache_req,
    output logic [ADDR_WIDTH-1:0] icache_addr
);
    localparam LINE_WIDTH = DATA_WIDTH * WORDS_PER_LINE;

    //address decode - live IF1 request
    logic [WORD_SEL_BITS-1:0]   pc_word_sel;
    logic [IC_IDX_BITS-1:0]     pc_idx;
    logic [IC_TAG_BITS-1:0]     pc_tag;

    assign pc_word_sel  = pc[WORD_OFF_BITS +: WORD_SEL_BITS];
    assign pc_idx       = pc[LINE_OFF_BITS +: IC_IDX_BITS];
    assign pc_tag       = pc[ADDR_WIDTH-1 -: IC_TAG_BITS];

    //lookup metadata - delayed to align with SRAM dout
    logic [WORD_SEL_BITS-1:0]   lookup_word_sel_q;
    logic [IC_IDX_BITS-1:0]     lookup_idx_q;
    logic [IC_TAG_BITS-1:0]     lookup_tag_q;
    logic                       lookup_valid_q;
    logic                       lookup_accept;

    //SRAM storage
    logic                       tag_csb;
    logic                       tag_web;
    logic [IC_IDX_BITS-1:0]     tag_addr;
    logic [IC_TAG_BITS-1:0]     tag_din;
    logic [IC_TAG_BITS-1:0]     tag_dout;

    logic                       data_csb;
    logic                       data_web;
    logic [IC_IDX_BITS-1:0]     data_addr;
    logic [LINE_WIDTH-1:0]      data_din;
    logic [LINE_WIDTH-1:0]      data_dout;

    logic [IC_SETS-1:0]         cache_valid;

    sram_1rw #(
        .ADDR_W  (IC_IDX_BITS),
        .DATA_W  (IC_TAG_BITS),
        .DEPTH   (IC_SETS),
        .WMASK_W (1)
    ) tag_sram (
        .clk   (clk),
        .csb   (tag_csb),
        .web   (tag_web),
        .wmask (1'b1),
        .addr  (tag_addr),
        .din   (tag_din),
        .dout  (tag_dout)
    );

    sram_1rw #(
        .ADDR_W  (IC_IDX_BITS),
        .DATA_W  (LINE_WIDTH),
        .DEPTH   (IC_SETS),
        .WMASK_W (WORDS_PER_LINE)
    ) data_sram (
        .clk   (clk),
        .csb   (data_csb),
        .web   (data_web),
        .wmask ({WORDS_PER_LINE{1'b1}}),
        .addr  (data_addr),
        .din   (data_din),
        .dout  (data_dout)
    );

    //lookup result
    logic cache_hit;
    logic [DATA_WIDTH-1:0] hit_data;

    assign cache_hit = lookup_valid_q && cache_valid[lookup_idx_q] && (tag_dout == lookup_tag_q);
    assign hit_data  = data_dout[lookup_word_sel_q*DATA_WIDTH +: DATA_WIDTH];

    //refill buffer
    logic [DATA_WIDTH-1:0]      rf_buffer [WORDS_PER_LINE];
    logic [WORDS_PER_LINE-1:0]  rf_valid;
    logic [IC_TAG_BITS-1:0]     rf_tag;
    logic [IC_IDX_BITS-1:0]     rf_idx;
    logic [WORD_SEL_BITS-1:0]   rf_word_sel;

    logic rf_buffer_hit;
    assign rf_buffer_hit = lookup_valid_q && rf_valid[lookup_word_sel_q] &&
                           (rf_idx == lookup_idx_q) &&
                           (rf_tag == lookup_tag_q);

    //one-entry request slot
    assign icache_ready  = !lookup_valid_q || icache_consume;
    assign lookup_accept = if_req && icache_ready;

    //fsm
    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
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
                if (lookup_valid_q || lookup_accept)
                    next_state = LOOKUP;
            end

            LOOKUP: begin
                if (lookup_valid_q && (cache_hit || rf_buffer_hit)) begin
                    if (icache_consume)
                        next_state = lookup_accept ? LOOKUP : IDLE;
                end else if (lookup_valid_q) begin
                    next_state = REFILL_REQ;
                end else begin
                    next_state = lookup_accept ? LOOKUP : IDLE;
                end
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
        endcase
    end

    //FSM: control registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= IDLE;
            cache_valid    <= '0;
            rf_valid       <= '0;
            lookup_valid_q <= 1'b0;
        end else begin
            state <= next_state;

            if (flush_refill) begin
                lookup_valid_q <= 1'b0;
            end else if (lookup_accept) begin
                lookup_valid_q    <= 1'b1;
                lookup_tag_q      <= pc_tag;
                lookup_idx_q      <= pc_idx;
                lookup_word_sel_q <= pc_word_sel;
            end else if (icache_consume) begin
                lookup_valid_q <= 1'b0;
            end

            case (state)
                LOOKUP: begin
                    if (lookup_valid_q && !cache_hit && !rf_buffer_hit) begin
                        rf_valid <= '0;
                    end
                end

                REFILL_DATA: begin
                    if (arb_valid)
                        rf_valid[rf_word_sel] <= 1'b1;
                end

                REFILL_DONE: begin
                    cache_valid[rf_idx] <= 1'b1;
                end
            endcase
        end
    end

    //FSM: data + refill address registers
    always_ff @(posedge clk) begin
        case (state)
            LOOKUP: begin
                if (lookup_valid_q && !cache_hit && !rf_buffer_hit) begin
                    rf_tag      <= lookup_tag_q;
                    rf_idx      <= lookup_idx_q;
                    rf_word_sel <= lookup_word_sel_q;
                end
            end

            REFILL_DATA: begin
                if (arb_valid) begin
                    rf_buffer[rf_word_sel] <= arb_rdata;
                    rf_word_sel            <= rf_word_sel + 1'b1;
                end
            end
        endcase
    end

    //SRAM write data packing
    always_comb begin
        data_din = '0;
        for (int w = 0; w < WORDS_PER_LINE; w++)
            data_din[w*DATA_WIDTH +: DATA_WIDTH] = rf_buffer[w];
    end

    //SRAM control
    always_comb begin
        tag_csb   = 1'b1;
        tag_web   = 1'b1;
        tag_addr  = pc_idx;
        tag_din   = rf_tag;

        data_csb  = 1'b1;
        data_web  = 1'b1;
        data_addr = pc_idx;

        case (state)
            IDLE: begin
                if (lookup_accept || lookup_valid_q) begin
                    tag_csb   = 1'b0;
                    tag_web   = 1'b1;
                    tag_addr  = lookup_accept ? pc_idx : lookup_idx_q;

                    data_csb  = 1'b0;
                    data_web  = 1'b1;
                    data_addr = lookup_accept ? pc_idx : lookup_idx_q;
                end
            end

            LOOKUP: begin
                if (lookup_accept) begin
                    tag_csb   = 1'b0;
                    tag_web   = 1'b1;
                    tag_addr  = pc_idx;

                    data_csb  = 1'b0;
                    data_web  = 1'b1;
                    data_addr = pc_idx;
                end
            end

            REFILL_DONE: begin
                tag_csb   = 1'b0;
                tag_web   = 1'b0;
                tag_addr  = rf_idx;
                tag_din   = rf_tag;

                data_csb  = 1'b0;
                data_web  = 1'b0;
                data_addr = rf_idx;
            end
        endcase
    end

    //response mux
    always_comb begin
        instr        = '0;
        icache_valid = 1'b0;

        if (rf_buffer_hit) begin
            instr        = rf_buffer[lookup_word_sel_q];
            icache_valid = 1'b1;
        end else if ((state == LOOKUP) && cache_hit) begin
            instr        = hit_data;
            icache_valid = 1'b1;
        end
    end

    //Bus Arbiter
    assign icache_req  = (state == REFILL_REQ);
    assign icache_addr = {rf_tag, rf_idx, rf_word_sel, {WORD_OFF_BITS{1'b0}}};
endmodule
