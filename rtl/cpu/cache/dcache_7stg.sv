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
// Module       : dcache_7stg
// Description  : Platform selector for the 7-stage data cache.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-19
// Version      : 1.0
// -----------------------------------------------------------------------------

module dcache_7stg
    import cache_pkg::*;
(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic                  mem_req,
    input  logic                  mem_we,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic [STRB_WIDTH-1:0] wstrb,
    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  dcache_ready,
    output logic                  dcache_valid,
    output logic                  wb_push,
    output logic [ADDR_WIDTH-1:0] wb_addr,
    output logic [DATA_WIDTH-1:0] wb_data,
    output logic [STRB_WIDTH-1:0] wb_strb,
    input  logic                  wb_full,
    output logic [ADDR_WIDTH-1:0] fwd_addr,
    input  logic                  fwd_hit,
    input  logic [DATA_WIDTH-1:0] fwd_data,
    input  logic [STRB_WIDTH-1:0] fwd_strb,
    input  logic [DATA_WIDTH-1:0] arb_rdata,
    input  logic                  arb_valid,
    input  logic                  arb_last,
    input  logic                  arb_grant,
    output logic                  dcache_req,
    output logic [ADDR_WIDTH-1:0] dcache_addr
);

`ifdef TARGET_ASAP7
    dcache_7stg_asap7 u_impl (
`else
    dcache_7stg_fpga u_impl (
`endif
        .clk          (clk),
        .rst_n        (rst_n),
        .addr         (addr),
        .mem_req      (mem_req),
        .mem_we       (mem_we),
        .wdata        (wdata),
        .wstrb        (wstrb),
        .rdata        (rdata),
        .dcache_ready (dcache_ready),
        .dcache_valid (dcache_valid),
        .wb_push      (wb_push),
        .wb_addr      (wb_addr),
        .wb_data      (wb_data),
        .wb_strb      (wb_strb),
        .wb_full      (wb_full),
        .fwd_addr     (fwd_addr),
        .fwd_hit      (fwd_hit),
        .fwd_data     (fwd_data),
        .fwd_strb     (fwd_strb),
        .arb_rdata    (arb_rdata),
        .arb_valid    (arb_valid),
        .arb_last     (arb_last),
        .arb_grant    (arb_grant),
        .dcache_req   (dcache_req),
        .dcache_addr  (dcache_addr)
    );

endmodule
