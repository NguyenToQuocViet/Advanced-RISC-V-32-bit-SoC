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
// Version      : 2.0
// Changes      : 7-stage: if2_id_stall + mem1_mem2_stall added.
//                mispred flush: IF1/IF2 + IF2/ID + ID/EX + EX/MEM1.
//                MEM1/MEM2 + MEM2/WB: never flushed.
// -----------------------------------------------------------------------------

module hazard_ctrl
    import cpu_pkg::*;
(
    //hazard sources
    input  logic    load_use_stall,
    input  logic    dcache_stall,
    input  logic    ex_flush,
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
    //dcache miss: freeze toan pipeline
    //load-use: freeze IF1/IF2 + IF2/ID (cho consumer het stall)
    assign fcu1_stall     = dcache_stall | load_use_stall;
    assign if1_if2_stall  = dcache_stall | load_use_stall;
    assign if2_id_stall   = dcache_stall | load_use_stall;
    assign id_ex_stall    = dcache_stall;
    assign ex_mem1_stall  = dcache_stall;
    assign mem1_mem2_stall = dcache_stall;
    assign mem2_wb_stall  = dcache_stall;

    //mispredict: flush wrong-path stages (IF2/ID, ID/EX, EX/MEM1)
    //IF1/IF2 flush owned by FCU1 (if1_if2_flush = mispredict_r | if2_redirect)
    //load-use ex_flush: kill ID/EX only
    //MEM1/MEM2, MEM2/WB: never flushed (da commit)

    //note: IF2/ID flush do ben ngoai (FCU2 cung cap if2_id_flush)
    assign id_ex_flush    = mispredict_r | ex_flush;
    assign ex_mem1_flush  = mispredict_r;
    assign mem1_mem2_flush = 1'b0;
    assign mem2_wb_flush  = 1'b0;
endmodule
