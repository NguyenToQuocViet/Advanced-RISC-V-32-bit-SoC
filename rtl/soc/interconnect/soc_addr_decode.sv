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
// Module       : soc_addr_decode
// Description  : Combinational SoC address decoder and access-policy checker
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-25
// Version      : 1.0
// -----------------------------------------------------------------------------

module soc_addr_decode
    import soc_addr_map_pkg::*;
    import axi_pkg::*;
(
    input  logic [SOC_ADDR_WIDTH-1:0]  addr,
    input  logic                       is_write,
    input  logic                       is_fetch,
    input  logic [7:0]                 burst_len,
    input  logic [2:0]                 burst_size,
    input  logic [1:0]                 burst_type,

    output soc_target_t                target,
    output logic                       decode_error
);

    //region match
    logic [SOC_NUM_REGIONS-1:0] region_hit;
    logic                       hit;

    always_comb begin
        for (int i = 0; i < SOC_NUM_REGIONS; i++) begin
            region_hit[i] = (addr & SOC_REGION_TABLE[i].mask) == SOC_REGION_TABLE[i].base;
        end

        hit = |region_hit;
    end

    //matched descriptor mux
    soc_region_desc_t selected_desc;

    always_comb begin
        selected_desc = '0;

        for (int i = 0; i < SOC_NUM_REGIONS; i++) begin
            if (region_hit[i]) begin
                selected_desc = SOC_REGION_TABLE[i];
            end
        end
    end

    //decoded metadata
    assign target = selected_desc.target;

    //access permission
    logic permission_ok;
    logic readable;
    logic writable;
    logic executable;

    assign readable   = selected_desc.readable;
    assign writable   = selected_desc.writable;
    assign executable = selected_desc.executable;

    always_comb begin
        permission_ok = 1'b0;

        if (hit && !(is_fetch && is_write)) begin
            if (is_fetch) begin
                permission_ok = readable && executable;
            end else if (is_write) begin
                permission_ok = writable;
            end else begin
                permission_ok = readable;
            end
        end
    end

    //transfer size and alignment
    logic size_ok;
    logic aligned_ok;

    always_comb begin
        size_ok = 1'b1;

        case (burst_size)
            3'd0: begin
                aligned_ok = 1'b1;
            end

            3'd1: begin
                aligned_ok = (addr[0] == 1'b0);
            end

            3'd2: begin
                aligned_ok = (addr[1:0] == 2'b00);
            end

            default: begin
                size_ok    = 1'b0;
                aligned_ok = 1'b0;
            end
        endcase
    end
    //burst legality and span metadata
    logic        burst_type_ok;
    logic        burst_policy_ok;
    logic        allow_burst;
    logic        wrap_len_ok;
    logic        same_region_ok;
    logic        boundary_4k_ok;
    logic [8:0]  beat_count;
    logic [32:0] beat_bytes;
    logic [32:0] total_bytes;
    logic [32:0] span_start;
    logic [32:0] span_end;
    logic [32:0] wrap_mask;

    //burst protocol policy
    assign allow_burst = selected_desc.allow_burst;

    always_comb begin
        wrap_len_ok = (burst_len == 8'd1)
                   || (burst_len == 8'd3)
                   || (burst_len == 8'd7)
                   || (burst_len == 8'd15);

        burst_type_ok = 1'b0;
        case (burst_type)
            AXI_BURST_FIXED: burst_type_ok = 1'b1;
            AXI_BURST_INCR:  burst_type_ok = 1'b1;
            AXI_BURST_WRAP:  burst_type_ok = wrap_len_ok;
            default:         burst_type_ok = 1'b0;
        endcase

        burst_policy_ok = allow_burst || (burst_len == AXI_LEN_SINGLE);
    end

    //burst address span
    always_comb begin
        beat_count  = {1'b0, burst_len} + 9'd1;
        beat_bytes  = 33'd1 << burst_size;
        total_bytes = {24'd0, beat_count} << burst_size;
        wrap_mask   = ~(total_bytes - 33'd1);

        span_start = {1'b0, addr};
        span_end   = {1'b0, addr} + beat_bytes - 33'd1;

        case (burst_type)
            AXI_BURST_INCR: begin
                span_end = {1'b0, addr} + total_bytes - 33'd1;
            end

            AXI_BURST_WRAP: begin
                span_start = {1'b0, addr} & wrap_mask;
                span_end   = span_start + total_bytes - 33'd1;
            end

            default: begin
                span_start = {1'b0, addr};
                span_end   = {1'b0, addr} + beat_bytes - 33'd1;
            end
        endcase
    end

    //routing boundary checks
    always_comb begin
        same_region_ok = hit
                      && !span_start[32]
                      && !span_end[32]
                      && ((span_start[31:0] & selected_desc.mask)
                          == selected_desc.base)
                      && ((span_end[31:0] & selected_desc.mask)
                          == selected_desc.base);

        boundary_4k_ok = !span_start[32]
                      && !span_end[32]
                      && (span_start[31:12] == span_end[31:12]);
    end

    //final access decision
    logic access_ok;

    assign access_ok = permission_ok
                    && size_ok
                    && aligned_ok
                    && burst_type_ok
                    && burst_policy_ok
                    && same_region_ok
                    && boundary_4k_ok;

    assign decode_error = !access_ok;
endmodule
