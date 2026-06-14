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
// Description  : load-use (check EX+mem1 -> 2-cycle stall) + dcache-miss
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-30
// Version      : 2.0
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
    input logic         mem_req,
    input logic         mem_valid,

    //stall IF+ID, flush ID/EX
    output logic        load_use_stall,
    output logic        ex_flush,

    //stall toan pipeline
    output logic        dcache_stall
);
    logic load_in_ex, load_in_mem1;

    //stall when consumer in ID matches load in EX or MEM1
    assign load_in_ex   = ex_mem_req   && !ex_mem_we   && ex_rd   != 5'b0;
    assign load_in_mem1 = mem1_mem_req && !mem1_mem_we && mem1_rd != 5'b0;

    assign load_use_stall = (load_in_ex   && (ex_rd   == id_rs1 || ex_rd   == id_rs2))
                          || (load_in_mem1 && (mem1_rd == id_rs1 || mem1_rd == id_rs2));

    //flush ID/EX when stalling
    assign ex_flush       = load_use_stall;

    //freeze toan pipeline khi dcache miss
    assign dcache_stall   = mem_req && !mem_valid;
endmodule
