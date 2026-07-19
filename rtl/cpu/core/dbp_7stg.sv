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
// Module       : dbp_7stg
// Description  : Platform selector for the seven-stage branch predictor.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-19
// Version      : 1.0
// -----------------------------------------------------------------------------

module dbp_7stg
    import cpu_pkg::*;
(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [ADDR_WIDTH-1:0] if1_pc,
    input  logic                  if1_valid,
    input  logic                  stall,
    input  logic                  flush,
    input  logic                  if2_consume,
    output logic                  pred_taken,
    output logic [ADDR_WIDTH-1:0] pred_target,
    input  logic                  ex_update_en,
    input  logic [ADDR_WIDTH-1:0] ex_pc,
    input  logic                  ex_actual_taken,
    input  logic [ADDR_WIDTH-1:0] ex_actual_target
);

`ifdef TARGET_ASAP7
    dbp_7stg_asap7 u_impl (
`else
    dbp_7stg_fpga u_impl (
`endif
        .clk              (clk),
        .rst_n            (rst_n),
        .if1_pc           (if1_pc),
        .if1_valid        (if1_valid),
        .stall            (stall),
        .flush            (flush),
        .if2_consume      (if2_consume),
        .pred_taken       (pred_taken),
        .pred_target      (pred_target),
        .ex_update_en     (ex_update_en),
        .ex_pc            (ex_pc),
        .ex_actual_taken  (ex_actual_taken),
        .ex_actual_target (ex_actual_target)
    );

endmodule
