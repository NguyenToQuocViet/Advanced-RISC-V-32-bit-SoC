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
// Module       : cache_subsystem_7stg
// Description  : 7-stage cache subsystem wrapper.
//                Keeps the 5-stage subsystem contract, swaps cache internals
//                to SRAM request/response timing.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-19
// Version      : 1.0
// -----------------------------------------------------------------------------

module cache_subsystem_7stg
    import cache_pkg::*;
(
    //system
    input  logic                    clk, rst_n,

    //if stage
    input  logic [ADDR_WIDTH-1:0]   if_pc,
    input  logic                    if_req,
    output logic [DATA_WIDTH-1:0]   if_instr,
    output logic                    if_icache_ready,
    output logic                    if_icache_valid,

    //refill abandon - core mispredict feedback
    input  logic                    flush_refill,

    //mem stage
    input  logic [ADDR_WIDTH-1:0]   mem_addr,
    input  logic                    mem_req,
    input  logic                    mem_we,
    input  logic [DATA_WIDTH-1:0]   mem_wdata,
    input  logic [STRB_WIDTH-1:0]   mem_wstrb,
    output logic [DATA_WIDTH-1:0]   mem_rdata,
    output logic                    mem_dcache_ready,
    output logic                    mem_dcache_valid,

    //fence
    input  logic                    fence,
    output logic                    fence_done,

    //axi4 master - read address
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,

    //axi4 master - read data
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,
    input  logic [DATA_WIDTH-1:0]   m_axi_rdata,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rlast,

    //axi4 master - write address
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,

    //axi4 master - write data
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [STRB_WIDTH-1:0]   m_axi_wstrb,
    output logic                    m_axi_wlast,

    //axi4 master - write response
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    input  logic [1:0]              m_axi_bresp
);
    //i-cache refill path
    logic                   ic_arb_req;
    logic [ADDR_WIDTH-1:0]  ic_arb_addr;
    logic                   ic_arb_grant;
    logic [DATA_WIDTH-1:0]  ic_arb_rdata;
    logic                   ic_arb_valid;
    logic                   ic_arb_last;

    //d-cache refill path
    logic                   dc_arb_req;
    logic [ADDR_WIDTH-1:0]  dc_arb_addr;
    logic                   dc_arb_grant;
    logic [DATA_WIDTH-1:0]  dc_arb_rdata;
    logic                   dc_arb_valid;
    logic                   dc_arb_last;

    //d-cache store push
    logic                   dc_wb_push;
    logic [ADDR_WIDTH-1:0]  dc_wb_addr;
    logic [DATA_WIDTH-1:0]  dc_wb_data;
    logic [STRB_WIDTH-1:0]  dc_wb_strb;
    logic                   wb_full;

    //store-to-load forwarding
    logic [ADDR_WIDTH-1:0]  fwd_addr;
    logic                   fwd_hit;
    logic [DATA_WIDTH-1:0]  fwd_data;
    logic [STRB_WIDTH-1:0]  fwd_strb;

    //write buffer drain
    logic                   wb_arb_wr_req;
    logic [ADDR_WIDTH-1:0]  wb_arb_wr_addr;
    logic [DATA_WIDTH-1:0]  wb_arb_wr_data;
    logic [STRB_WIDTH-1:0]  wb_arb_wr_strb;
    logic                   wb_arb_wr_done;

    //i-cache: IF1 request, IF2 response
    icache_7stg u_icache (
        .clk            (clk),
        .rst_n          (rst_n),
        .pc             (if_pc),
        .if_req         (if_req),
        .instr          (if_instr),
        .icache_ready   (if_icache_ready),
        .icache_valid   (if_icache_valid),
        .flush_refill   (flush_refill),
        .arb_rdata      (ic_arb_rdata),
        .arb_valid      (ic_arb_valid),
        .arb_last       (ic_arb_last),
        .arb_grant      (ic_arb_grant),
        .icache_req     (ic_arb_req),
        .icache_addr    (ic_arb_addr)
    );

    //d-cache: MEM1 request, MEM2 response
    dcache_7stg u_dcache (
        .clk            (clk),
        .rst_n          (rst_n),
        .addr           (mem_addr),
        .mem_req        (mem_req),
        .mem_we         (mem_we),
        .wdata          (mem_wdata),
        .wstrb          (mem_wstrb),
        .rdata          (mem_rdata),
        .dcache_ready   (mem_dcache_ready),
        .dcache_valid   (mem_dcache_valid),
        .wb_push        (dc_wb_push),
        .wb_addr        (dc_wb_addr),
        .wb_data        (dc_wb_data),
        .wb_strb        (dc_wb_strb),
        .wb_full        (wb_full),
        .fwd_addr       (fwd_addr),
        .fwd_hit        (fwd_hit),
        .fwd_data       (fwd_data),
        .fwd_strb       (fwd_strb),
        .arb_rdata      (dc_arb_rdata),
        .arb_valid      (dc_arb_valid),
        .arb_last       (dc_arb_last),
        .arb_grant      (dc_arb_grant),
        .dcache_req     (dc_arb_req),
        .dcache_addr    (dc_arb_addr)
    );

    //write buffer: store queue + forwarding source
    write_buffer u_write_buffer (
        .clk            (clk),
        .rst_n          (rst_n),
        .push           (dc_wb_push),
        .push_addr      (dc_wb_addr),
        .push_data      (dc_wb_data),
        .push_strb      (dc_wb_strb),
        .wb_full        (wb_full),
        .fwd_addr       (fwd_addr),
        .fwd_hit        (fwd_hit),
        .fwd_data       (fwd_data),
        .fwd_strb       (fwd_strb),
        .fence          (fence),
        .fence_done     (fence_done),
        .wb_req         (wb_arb_wr_req),
        .wb_addr        (wb_arb_wr_addr),
        .wb_data        (wb_arb_wr_data),
        .wb_strb        (wb_arb_wr_strb),
        .arb_wr_done    (wb_arb_wr_done)
    );

    //arbiter: refill read + write-buffer drain
    bus_arbiter u_bus_arbiter (
        .clk            (clk),
        .rst_n          (rst_n),
        .icache_req     (ic_arb_req),
        .icache_addr    (ic_arb_addr),
        .icache_grant   (ic_arb_grant),
        .icache_rdata   (ic_arb_rdata),
        .icache_valid   (ic_arb_valid),
        .icache_last    (ic_arb_last),
        .dcache_req     (dc_arb_req),
        .dcache_addr    (dc_arb_addr),
        .dcache_grant   (dc_arb_grant),
        .dcache_rdata   (dc_arb_rdata),
        .dcache_valid   (dc_arb_valid),
        .dcache_last    (dc_arb_last),
        .arb_wr_req     (wb_arb_wr_req),
        .arb_wr_addr    (wb_arb_wr_addr),
        .arb_wr_data    (wb_arb_wr_data),
        .arb_wr_strb    (wb_arb_wr_strb),
        .arb_wr_done    (wb_arb_wr_done),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bresp    (m_axi_bresp)
    );
endmodule
