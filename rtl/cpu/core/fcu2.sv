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
// Module       : Fetch Control Unit 2 (IF2 Stage)
// Description  : Instruction capture, CWF guard, BTB redirect generation.
//                Receives raw instruction from I-Cache (SRAM data available),
//                manages cwf_consumed to prevent duplicate CWF latch, generates
//                if2_redirect when BTB predicts taken.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-28
// Version      : 1.3
// Changes v1.1 : remove ignore_valid — proven redundant after icache tag-compare
//                was added to all output paths (REFILL_DONE, CWF bypass, IDLE hit).
//                Verified: rv32ui 38/38 PASS without ignore_valid.
// Changes v1.2 : qualify IF2 side effects with if2_valid. BTB redirect no longer
//                flushes the producer branch before it reaches EX.
// Changes v1.3 : keep cwf_consumed set across IF2 redirect to block duplicate CWF.
// -----------------------------------------------------------------------------

module fcu2
    import cpu_pkg::*;
(
    //system interface
    input logic                     clk, rst_n,

    //icache interface
    input logic [DATA_WIDTH-1:0]    instr_i,
    input logic                     cache_valid,
    input logic                     cache_ready,

    //IF1/IF2 metadata
    input logic                     if2_valid,

    //branch prediction interface
    input logic                     pred_taken,
    input logic [ADDR_WIDTH-1:0]    pred_target,

    //ex feedback interface
    input logic                     ex_mispredict,

    //fcu1 interface
    output logic                    cache_advance,
    output logic                    if2_redirect,
    output logic [ADDR_WIDTH-1:0]   if2_redirect_pc,

    //hdu interface
    input logic                     stall,

    //if2_id pipeline
    output logic [DATA_WIDTH-1:0]   instr_o,
    output logic                    if2_id_pred_taken,
    output logic [ADDR_WIDTH-1:0]   if2_id_pred_target,
    output logic                    if2_id_flush
);
    //cwf_consumed: CWF instr da duoc IF2/ID capture
    //set: valid=1, ready=0, !stall -> capture 1st cycle
    //clear: ready=1 (refill done) or EX redirect -> discard
    logic cwf_consumed;
    logic if2_fire;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cwf_consumed <= 1'b0;
        else if (cache_ready || ex_mispredict)
            cwf_consumed <= 1'b0;
        else if (if2_valid && cache_valid && !cache_ready && !stall)
            cwf_consumed <= 1'b1;
    end

    //IF2 fire: valid metadata + valid cache response accepted into IF2/ID
    assign if2_fire            = if2_valid && cache_valid && !cwf_consumed && !stall;

    //output
    assign instr_o              = instr_i;

    //advance PC only for a live IF2 response
    assign cache_advance        = if2_valid && cache_valid && cache_ready && !cwf_consumed;

    //BTB taken redirects younger fetch; producer branch still enters IF2/ID
    //EX correction takes priority over BTB redirect
    assign if2_redirect         = if2_fire && pred_taken && !ex_mispredict;
    assign if2_redirect_pc      = pred_target;

    //flush IF2/ID only when current IF2 slot is not a real instruction
    assign if2_id_flush         = ex_mispredict | ((!if2_valid || !cache_valid || cwf_consumed) && !stall);

    assign if2_id_pred_taken    = pred_taken;
    assign if2_id_pred_target   = pred_target;
endmodule
