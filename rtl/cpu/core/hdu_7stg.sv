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
// Module       : hazard detection unit (7-stage)
// Description  : load-use (check EX+MEM1 -> 2-cycle stall) + D-cache wait detect
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-30
// Version      : 2.3
// Changes v2.1 : D-cache wait is detected from MEM2 response phase, not MEM1
//                request launch phase.
// Changes v2.2 : HDU owns both MEM1 request wait and MEM2 response wait detect.
// Changes v2.3 : HDU owns MEM2 response cleanup detect.
// -----------------------------------------------------------------------------

module hdu_7stg
    import cpu_pkg::*;
(
    //load in EX
    input logic         ex_mem_req,
    input logic         ex_mem_we,
    input logic [4:0]   ex_rd,

    //load in MEM1
    input logic         mem1_mem_req,
    input logic         mem1_mem_we,
    input logic [4:0]   mem1_rd,

    //consumer in ID
    input logic [4:0]   id_rs1,
    input logic [4:0]   id_rs2,

    //MEM1 dcache status
    input logic         mem1_mem_ready,

    //MEM2 dcache status
    input logic         mem2_mem_req,
    input logic         mem2_mem_valid,

    //load-use detect
    output logic        load_use_stall,

    //D-cache wait detect
    output logic        dcache_mem1_stall,
    output logic        dcache_mem2_stall,
    output logic        dcache_resp_flush
);
    logic load_in_ex, load_in_mem1;

    //stall when consumer in ID matches load in EX or MEM1
    assign load_in_ex   = ex_mem_req   && !ex_mem_we   && ex_rd   != 5'b0;
    assign load_in_mem1 = mem1_mem_req && !mem1_mem_we && mem1_rd != 5'b0;

    assign load_use_stall = (load_in_ex   && (ex_rd   == id_rs1 || ex_rd   == id_rs2))
                          || (load_in_mem1 && (mem1_rd == id_rs1 || mem1_rd == id_rs2));

    //MEM1 waits until D-cache can accept request launch
    assign dcache_mem1_stall = mem1_mem_req && !mem1_mem_ready;

    //MEM2 waits after MEM1 request has moved across the stage boundary
    assign dcache_mem2_stall = mem2_mem_req && !mem2_mem_valid;

    //Clear retired MEM2 slot when MEM1 remains blocked
    assign dcache_resp_flush = mem2_mem_req && mem2_mem_valid && dcache_mem1_stall;
endmodule
