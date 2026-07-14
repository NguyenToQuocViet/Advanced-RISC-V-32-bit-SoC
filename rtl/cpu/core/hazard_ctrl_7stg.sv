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
// Module       : hazard_ctrl (7-stage)
// Description  : stall/flush distribution across 7-stage pipeline registers.
//                if2_id_flush owned by FCU2 (CWF + mispredict + redirect).
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-30
// Version      : 2.4
// Changes      : 7-stage: if2_id_stall + mem1_mem2_stall added.
//                mispred flush: IF1/IF2 + IF2/ID + ID/EX + EX/MEM1.
// Changes v2.1 : Split MEM1 launch wait from MEM2 response wait.
// Changes v2.2 : ID/EX load-use flush uses load_use_stall directly.
// Changes v2.3 : MEM1/MEM2 response flush no longer shares stall semantic.
// Changes v2.4 : Defer load-use bubble while D-cache freezes the EX stage.
// -----------------------------------------------------------------------------

module hazard_ctrl_7stg
    import cpu_pkg::*;
(
    //hazard sources
    input  logic    load_use_stall,
    input  logic    dcache_mem1_stall,
    input  logic    dcache_mem2_stall,
    input  logic    dcache_resp_flush,
    input  logic    mispredict_r,

    //per-stage stall (freeze pipeline reg)
    output logic    fcu1_stall,
    output logic    if1_if2_stall,
    output logic    if2_id_stall,
    output logic    id_ex_stall,
    output logic    ex_mem1_stall,
    output logic    mem1_mem2_stall,
    output logic    mem2_wb_stall,

    //per-stage flush (insert NOP into pipeline reg)
    output logic    id_ex_flush,
    output logic    ex_mem1_flush,
    output logic    mem1_mem2_flush,
    output logic    mem2_wb_flush
);
    logic dcache_upstream_stall;

    assign dcache_upstream_stall = dcache_mem1_stall | dcache_mem2_stall;

    //load-use: hold fetch/decode, inject bubble into EX
    //D-cache wait: hold upstream until MEM1 can launch or MEM2 can retire
    assign fcu1_stall      = dcache_upstream_stall | load_use_stall;
    assign if1_if2_stall   = dcache_upstream_stall | load_use_stall;
    assign if2_id_stall    = dcache_upstream_stall | load_use_stall;
    assign id_ex_stall     = dcache_upstream_stall;
    assign ex_mem1_stall   = dcache_upstream_stall;
    assign mem1_mem2_stall = dcache_upstream_stall & !dcache_resp_flush;
    assign mem2_wb_stall   = dcache_mem2_stall;

    //mispredict: flush wrong-path stages
    //MEM2 response flush clears stale MEM1 payload after a waited response
    assign id_ex_flush     = mispredict_r | (load_use_stall && !dcache_upstream_stall);
    assign ex_mem1_flush   = mispredict_r;
    assign mem1_mem2_flush = dcache_resp_flush;
    assign mem2_wb_flush   = 1'b0;
endmodule
