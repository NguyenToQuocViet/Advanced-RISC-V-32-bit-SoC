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
// Module       : bus_arbiter
// Description  : AXI4 Read Arbiter and Write Controller
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-08
// Version      : 1.0
// -----------------------------------------------------------------------------

module bus_arbiter
    import cache_pkg::*;
    import axi_pkg::*;
(
    //system
    input logic clk, rst_n,

    //icache - arbiter read interface
    input logic                     icache_req,
    input logic [ADDR_WIDTH-1:0]    icache_addr,

    output logic                    icache_grant,
    output logic [DATA_WIDTH-1:0]   icache_rdata,
    output logic                    icache_valid,
    output logic                    icache_last,

    //dcache - arbiter read interface
    input logic                     dcache_req,
    input logic [ADDR_WIDTH-1:0]    dcache_addr,

    output logic                    dcache_grant,
    output logic [DATA_WIDTH-1:0]   dcache_rdata,
    output logic                    dcache_valid,
    output logic                    dcache_last,

    //AXI4 master - read addr channel
    output logic                    m_axi_arvalid,
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,

    input logic                     m_axi_arready,

    //AXI4 master - read data channel
    input logic                     m_axi_rvalid,
    input logic [DATA_WIDTH-1:0]    m_axi_rdata,
    input logic [1:0]               m_axi_rresp,
    input logic                     m_axi_rlast,

    output logic                    m_axi_rready,
    
    //AXI4 master - write address channel   
    output logic                    m_axi_awvalid,
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,
    
    input logic                     m_axi_awready

    //AXI4 master - write data channel
    output logic                    m_axi_wvalid,
    output logic [DATA_WIDTH-1:0]   m_axi_wdata,
    output logic [STRB_WIDTH-1:0]   m_axi_wstrb,
    output logic                    m_axi_wlast,

    input logic                     m_axi_wready,

    //AXI4 master - write response channel
    input logic         m_axi_bvalid,
    input logic [1:0]   m_axi_bresp,

    output logic        m_axi_bready
);
    
endmodule
