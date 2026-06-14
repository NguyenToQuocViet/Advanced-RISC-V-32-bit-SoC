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
// Module       : forwarding unit
// Description  : Detects data hazards and generates forwarding mux select signals
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-30
// Version      : 2.0
// -----------------------------------------------------------------------------

module fu_7stg
    import cpu_pkg::*;
(
    //ex stage (register dang duoc dung)
    input logic [4:0]   ex_rs1,
    input logic [4:0]   ex_rs2,

    //mem1 stage
    input logic [4:0]   mem1_rd,
    input logic         mem1_reg_we,

    //mem2 stage
    input logic [4:0]   mem2_rd,
    input logic         mem2_reg_we,

    //wb stage (ai dang o wb)
    input logic [4:0]   wb_rd,
    input logic         wb_reg_we,

    //forward signals
    output logic [1:0]  forward_a,
    output logic [1:0]  forward_b
);
    // 2'b00 = no forward (register file)
    // 2'b01 = WB  (mem2_wb_pipeline)
    // 2'b10 = MEM2 (mem1_mem2_pipeline)
    // 2'b11 = MEM1 (ex_mem1_pipeline)
    always_comb begin
        //forward_a
        if (mem1_reg_we && mem1_rd != 5'b0 && ex_rs1 == mem1_rd)
            forward_a = 2'b11;
        else if (mem2_reg_we && mem2_rd != 5'b0 && ex_rs1 == mem2_rd)
            forward_a = 2'b10;
        else if (wb_reg_we && wb_rd != 5'b0 && ex_rs1 == wb_rd)
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        //forward_b
        if (mem1_reg_we && mem1_rd != 5'b0 && ex_rs2 == mem1_rd)
            forward_b = 2'b11;
        else if (mem2_reg_we && mem2_rd != 5'b0 && ex_rs2 == mem2_rd)
            forward_b = 2'b10;
        else if (wb_reg_we && wb_rd != 5'b0 && ex_rs2 == wb_rd)
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end
endmodule
