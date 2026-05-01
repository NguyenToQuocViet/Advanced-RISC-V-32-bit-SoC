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
// Module       : fwd_mux (7-stage)
// Description  : EX-stage operand forwarding (7-stage, 4-source).
//                11=MEM1, 10=MEM2, 01=WB, 00=RF.
//                JAL/JALR WB_PC4: forward pc+4 instead of alu_result.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-30
// Version      : 2.0
// Changes      : 7-stage: MEM1 + MEM2 separate sources, each with wb_sel check.
// -----------------------------------------------------------------------------

module fwd_mux
    import cpu_pkg::*;
(
    //forward select from FU
    input  logic [1:0]              forward_a,      //00=RF, 01=WB, 10=MEM2, 11=MEM1
    input  logic [1:0]              forward_b,

    //ID/EX register read
    input  logic [DATA_WIDTH-1:0]   ex_rdata1,
    input  logic [DATA_WIDTH-1:0]   ex_rdata2,

    //MEM1 source (ex_mem1_pipeline)
    input  logic [1:0]              mem1_wb_sel,
    input  logic [DATA_WIDTH-1:0]   mem1_alu_result,
    input  logic [ADDR_WIDTH-1:0]   mem1_pc,

    //MEM2 source (mem1_mem2_pipeline)
    input  logic [1:0]              mem2_wb_sel,
    input  logic [DATA_WIDTH-1:0]   mem2_alu_result,
    input  logic [ADDR_WIDTH-1:0]   mem2_pc,

    //WB-stage source (already muxed by wb module)
    input  logic [DATA_WIDTH-1:0]   wb_wdata,

    //forwarded operands
    output logic [DATA_WIDTH-1:0]   fw_src_a,
    output logic [DATA_WIDTH-1:0]   fw_src_b
);
    //MEM1 forward value: pc+4 if JAL/JALR, else alu_result
    logic [DATA_WIDTH-1:0] mem1_fwd_val;
    assign mem1_fwd_val = (mem1_wb_sel == WB_PC4) ? (mem1_pc + 32'd4) : mem1_alu_result;

    //MEM2 forward value: same logic
    logic [DATA_WIDTH-1:0] mem2_fwd_val;
    assign mem2_fwd_val = (mem2_wb_sel == WB_PC4) ? (mem2_pc + 32'd4) : mem2_alu_result;

    //4-to-1 mux: MEM1 > MEM2 > WB > RF (FU enforces priority)
    assign fw_src_a = (forward_a == 2'b11) ? mem1_fwd_val :
                      (forward_a == 2'b10) ? mem2_fwd_val :
                      (forward_a == 2'b01) ? wb_wdata    : ex_rdata1;

    assign fw_src_b = (forward_b == 2'b11) ? mem1_fwd_val :
                      (forward_b == 2'b10) ? mem2_fwd_val :
                      (forward_b == 2'b01) ? wb_wdata    : ex_rdata2;
endmodule