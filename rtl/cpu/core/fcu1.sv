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
// Module       : Fetch Control Unit 1 (IF1 Stage)
// Description  : PC control only. Advances PC in blind (no cache data or
//                prediction at IF1). Accepts redirect from EX (mispredict)
//                and IF2 (BTB taken). cache_advance from fcu2 gates PC advance.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-15
// Version      : 2.1
// Changes v1.2 : optimize by remove redundant guard, documenting
// Changes v1.3 : migrate cwf_consumed + if_id_flush from riscv_core.sv
// Changes v2.0 : reconstruct all the pipeline to ASIC friendly. IF now split
//                into IF1 IF2. IF1 advances in blind, redirect from IF2 for
//                BTB taken branches.
// Changes v2.1 : remove ignore_valid — proven redundant after icache tag-compare
//                was added to all output paths (REFILL_DONE, CWF bypass, IDLE hit).
//                Verified: rv32ui 38/38 PASS without ignore_valid.
// -----------------------------------------------------------------------------

module fcu1
    import cpu_pkg::*;
(
    //system interface
    input logic clk, rst_n,

    output logic                    if_req,
    output logic [ADDR_WIDTH-1:0]   if_pc,

    //EX-Stage Feedback interface
    input logic                     ex_mispredict,
    input logic [ADDR_WIDTH-1:0]    ex_correct_pc,

    //Hazard Control Unit interface
    input logic                     stall,

    //IF1/IF2 Pipeline interface
    output logic [ADDR_WIDTH-1:0]   if1_if2_pc,
    output logic                    if1_if2_flush,

    //IF2 redirect interface
    input logic                     if2_redirect,
    input logic [ADDR_WIDTH-1:0]    if2_redirect_pc,
    input logic                     cache_advance
);
    //PC Control
    logic [ADDR_WIDTH-1:0] pc_reg;
    logic [ADDR_WIDTH-1:0] next_pc;

    always_comb begin
        next_pc = pc_reg + 4;
    end

    //PC Update
    //PRIORITY 1: EX mispredict redirect
    //PRIORITY 2: IF2 BTB taken redirect
    //PRIORITY 3: Normal advance (gated by cache_advance from fcu2)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg  <= PC_RESET_VEC;
        end else begin
            if (ex_mispredict)
                pc_reg  <= ex_correct_pc;
            else if (if2_redirect)
                pc_reg  <= if2_redirect_pc;
            else if (!stall && cache_advance)
                pc_reg  <= next_pc;
        end
    end

    //output to icache
    assign if_pc        = pc_reg;
    assign if_req       = !stall && !ex_mispredict;

    //output to IF1/IF2 pipeline
    assign if1_if2_pc   = pc_reg;
    assign if1_if2_flush = ex_mispredict | if2_redirect;
endmodule
