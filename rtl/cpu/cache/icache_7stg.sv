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
// Module       : icache_7stg
// Description  : Platform selector for the 7-stage instruction cache.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-19
// Version      : 1.0
// -----------------------------------------------------------------------------

module icache_7stg
    import cache_pkg::*;
(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [ADDR_WIDTH-1:0] pc,
    input  logic                  if_req,
    input  logic                  icache_consume,
    output logic [DATA_WIDTH-1:0] instr,
    output logic                  icache_ready,
    output logic                  icache_valid,
    input  logic                  flush_refill,
    input  logic [DATA_WIDTH-1:0] arb_rdata,
    input  logic                  arb_valid,
    input  logic                  arb_last,
    input  logic                  arb_grant,
    output logic                  icache_req,
    output logic [ADDR_WIDTH-1:0] icache_addr
);

`ifdef TARGET_ASAP7
    icache_7stg_asap7 u_impl (
`else
    icache_7stg_fpga u_impl (
`endif
        .clk            (clk),
        .rst_n          (rst_n),
        .pc             (pc),
        .if_req         (if_req),
        .icache_consume (icache_consume),
        .instr          (instr),
        .icache_ready   (icache_ready),
        .icache_valid   (icache_valid),
        .flush_refill   (flush_refill),
        .arb_rdata      (arb_rdata),
        .arb_valid      (arb_valid),
        .arb_last       (arb_last),
        .arb_grant      (arb_grant),
        .icache_req     (icache_req),
        .icache_addr    (icache_addr)
    );

endmodule
