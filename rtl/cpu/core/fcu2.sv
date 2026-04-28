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
//                validates against ignore_valid, manages cwf_consumed to
//                prevent duplicate CWF latch, generates if2_redirect when
//                BTB predicts taken.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-28
// Version      : 1.0
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

    //branch prediction interface
    input logic                     pred_taken,
    input logic [ADDR_WIDTH-1:0]    pred_target,

    //ex feedback interface
    input logic                     ex_mispredict,

    //fcu1 interface
    input logic                     ignore_valid,

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
    //set: valid=1, ready=0, !stall, !ignore_valid -> capture 1st cycle
    //clear: ready=1 (refill done) or redirect (ex or if2) -> discard
    logic cwf_consumed;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cwf_consumed <= 1'b0;
        else if (cache_ready || ex_mispredict || if2_redirect)
            cwf_consumed <= 1'b0;
        else if (cache_valid && !cache_ready && !stall && !ignore_valid)
            cwf_consumed <= 1'b1;
    end

    //output
    assign instr_o              = ignore_valid ? NOP_INSTR : instr_i;
    assign cache_advance        = cache_valid && cache_ready && !cwf_consumed && !ignore_valid;
    assign if2_redirect         = pred_taken && !ignore_valid && !ex_mispredict;
    assign if2_redirect_pc      = pred_target;
    assign if2_id_flush         = ex_mispredict | if2_redirect | ((!cache_valid || cwf_consumed) && !stall);
    assign if2_id_pred_taken    = ignore_valid ? 1'b0 : pred_taken;
    assign if2_id_pred_target   = ignore_valid ? '0 : pred_target;
endmodule
