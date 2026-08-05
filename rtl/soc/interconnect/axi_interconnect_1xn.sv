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
// Module       : axi_interconnect_1xn
// Description  : One-to-N AXI transaction router with internal error response
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-30
// Version      : 1.0
// -----------------------------------------------------------------------------

module axi_interconnect_1xn
    import soc_addr_map_pkg::*;
#(
    parameter ID_WIDTH   = 2,
    parameter DATA_WIDTH = 32
) (
    //system
    input  logic                         clk,
    input  logic                         rst_n,

    //upstream AXI read address channel
    input  logic                         s_axi_arvalid,
    output logic                         s_axi_arready,
    input  logic [ID_WIDTH-1:0]          s_axi_arid,
    input  logic [SOC_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  logic [7:0]                   s_axi_arlen,
    input  logic [2:0]                   s_axi_arsize,
    input  logic [1:0]                   s_axi_arburst,

    //upstream AXI read response channel
    output logic                         s_axi_rvalid,
    input  logic                         s_axi_rready,
    output logic [ID_WIDTH-1:0]          s_axi_rid,
    output logic [DATA_WIDTH-1:0]        s_axi_rdata,
    output logic [1:0]                   s_axi_rresp,
    output logic                         s_axi_rlast,

    //upstream AXI write address channel
    input  logic                         s_axi_awvalid,
    output logic                         s_axi_awready,
    input  logic [ID_WIDTH-1:0]          s_axi_awid,
    input  logic [SOC_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  logic [7:0]                   s_axi_awlen,
    input  logic [2:0]                   s_axi_awsize,
    input  logic [1:0]                   s_axi_awburst,

    //upstream AXI write data channel
    input  logic                         s_axi_wvalid,
    output logic                         s_axi_wready,
    input  logic [DATA_WIDTH-1:0]        s_axi_wdata,
    input  logic [(DATA_WIDTH/8)-1:0]    s_axi_wstrb,
    input  logic                         s_axi_wlast,

    //upstream AXI write response channel
    output logic                         s_axi_bvalid,
    input  logic                         s_axi_bready,
    output logic [ID_WIDTH-1:0]          s_axi_bid,
    output logic [1:0]                   s_axi_bresp,

    //downstream AXI read address channels
    output logic [SOC_NUM_SLAVES-1:0]                     m_axi_arvalid,
    input  logic [SOC_NUM_SLAVES-1:0]                     m_axi_arready,
    output logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_arid,
    output logic [SOC_NUM_SLAVES-1:0][SOC_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [SOC_NUM_SLAVES-1:0][7:0]                m_axi_arlen,
    output logic [SOC_NUM_SLAVES-1:0][2:0]                m_axi_arsize,
    output logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_arburst,

    //downstream AXI read response channels
    input  logic [SOC_NUM_SLAVES-1:0]                 m_axi_rvalid,
    output logic [SOC_NUM_SLAVES-1:0]                 m_axi_rready,
    input  logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]   m_axi_rid,
    input  logic [SOC_NUM_SLAVES-1:0][DATA_WIDTH-1:0] m_axi_rdata,
    input  logic [SOC_NUM_SLAVES-1:0][1:0]            m_axi_rresp,
    input  logic [SOC_NUM_SLAVES-1:0]                 m_axi_rlast,

    //downstream AXI write address channels
    output logic [SOC_NUM_SLAVES-1:0]                     m_axi_awvalid,
    input  logic [SOC_NUM_SLAVES-1:0]                     m_axi_awready,
    output logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_awid,
    output logic [SOC_NUM_SLAVES-1:0][SOC_ADDR_WIDTH-1:0] m_axi_awaddr,
    output logic [SOC_NUM_SLAVES-1:0][7:0]                m_axi_awlen,
    output logic [SOC_NUM_SLAVES-1:0][2:0]                m_axi_awsize,
    output logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_awburst,

    //downstream AXI write data channels
    output logic [SOC_NUM_SLAVES-1:0]                     m_axi_wvalid,
    input  logic [SOC_NUM_SLAVES-1:0]                     m_axi_wready,
    output logic [SOC_NUM_SLAVES-1:0][DATA_WIDTH-1:0]     m_axi_wdata,
    output logic [SOC_NUM_SLAVES-1:0][(DATA_WIDTH/8)-1:0] m_axi_wstrb,
    output logic [SOC_NUM_SLAVES-1:0]                     m_axi_wlast,

    //downstream AXI write response channels
    input  logic [SOC_NUM_SLAVES-1:0]               m_axi_bvalid,
    output logic [SOC_NUM_SLAVES-1:0]               m_axi_bready,
    input  logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0] m_axi_bid,
    input  logic [SOC_NUM_SLAVES-1:0][1:0]          m_axi_bresp
);
    //internal default-error read request
    logic                    err_rd_req_valid;
    logic                    err_rd_req_ready;
    logic [ID_WIDTH-1:0]     err_rd_req_id;
    logic [7:0]              err_rd_req_len;

    //internal default-error read response
    logic                    err_rd_resp_valid;
    logic                    err_rd_resp_ready;
    logic [ID_WIDTH-1:0]     err_rd_resp_id;
    logic [DATA_WIDTH-1:0]   err_rd_resp_data;
    logic [1:0]              err_rd_resp_resp;
    logic                    err_rd_resp_last;

    //internal default-error write request
    logic                    err_wr_req_valid;
    logic                    err_wr_req_ready;
    logic [ID_WIDTH-1:0]     err_wr_req_id;
    logic [7:0]              err_wr_req_len;

    //internal default-error write data
    logic                    err_wr_data_valid;
    logic                    err_wr_data_ready;
    logic                    err_wr_data_last;

    //internal default-error write response
    logic                    err_wr_resp_valid;
    logic                    err_wr_resp_ready;
    logic [ID_WIDTH-1:0]     err_wr_resp_id;
    logic [1:0]              err_wr_resp_resp;

    //read transaction router
    axi_read_router #(
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_read_router (
        .clk               (clk),
        .rst_n             (rst_n),
        .s_axi_arvalid     (s_axi_arvalid),
        .s_axi_arready     (s_axi_arready),
        .s_axi_arid        (s_axi_arid),
        .s_axi_araddr      (s_axi_araddr),
        .s_axi_arlen       (s_axi_arlen),
        .s_axi_arsize      (s_axi_arsize),
        .s_axi_arburst     (s_axi_arburst),
        .s_axi_rvalid      (s_axi_rvalid),
        .s_axi_rready      (s_axi_rready),
        .s_axi_rid         (s_axi_rid),
        .s_axi_rdata       (s_axi_rdata),
        .s_axi_rresp       (s_axi_rresp),
        .s_axi_rlast       (s_axi_rlast),
        .m_axi_arvalid     (m_axi_arvalid),
        .m_axi_arready     (m_axi_arready),
        .m_axi_arid        (m_axi_arid),
        .m_axi_araddr      (m_axi_araddr),
        .m_axi_arlen       (m_axi_arlen),
        .m_axi_arsize      (m_axi_arsize),
        .m_axi_arburst     (m_axi_arburst),
        .m_axi_rvalid      (m_axi_rvalid),
        .m_axi_rready      (m_axi_rready),
        .m_axi_rid         (m_axi_rid),
        .m_axi_rdata       (m_axi_rdata),
        .m_axi_rresp       (m_axi_rresp),
        .m_axi_rlast       (m_axi_rlast),
        .err_rd_req_valid  (err_rd_req_valid),
        .err_rd_req_ready  (err_rd_req_ready),
        .err_rd_req_id     (err_rd_req_id),
        .err_rd_req_len    (err_rd_req_len),
        .err_rd_resp_valid (err_rd_resp_valid),
        .err_rd_resp_ready (err_rd_resp_ready),
        .err_rd_resp_id    (err_rd_resp_id),
        .err_rd_resp_data  (err_rd_resp_data),
        .err_rd_resp_resp  (err_rd_resp_resp),
        .err_rd_resp_last  (err_rd_resp_last)
    );

    //write transaction router
    axi_write_router #(
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_write_router (
        .clk               (clk),
        .rst_n             (rst_n),
        .s_axi_awvalid     (s_axi_awvalid),
        .s_axi_awready     (s_axi_awready),
        .s_axi_awid        (s_axi_awid),
        .s_axi_awaddr      (s_axi_awaddr),
        .s_axi_awlen       (s_axi_awlen),
        .s_axi_awsize      (s_axi_awsize),
        .s_axi_awburst     (s_axi_awburst),
        .s_axi_wvalid      (s_axi_wvalid),
        .s_axi_wready      (s_axi_wready),
        .s_axi_wdata       (s_axi_wdata),
        .s_axi_wstrb       (s_axi_wstrb),
        .s_axi_wlast       (s_axi_wlast),
        .s_axi_bvalid      (s_axi_bvalid),
        .s_axi_bready      (s_axi_bready),
        .s_axi_bid         (s_axi_bid),
        .s_axi_bresp       (s_axi_bresp),
        .m_axi_awvalid     (m_axi_awvalid),
        .m_axi_awready     (m_axi_awready),
        .m_axi_awid        (m_axi_awid),
        .m_axi_awaddr      (m_axi_awaddr),
        .m_axi_awlen       (m_axi_awlen),
        .m_axi_awsize      (m_axi_awsize),
        .m_axi_awburst     (m_axi_awburst),
        .m_axi_wvalid      (m_axi_wvalid),
        .m_axi_wready      (m_axi_wready),
        .m_axi_wdata       (m_axi_wdata),
        .m_axi_wstrb       (m_axi_wstrb),
        .m_axi_wlast       (m_axi_wlast),
        .m_axi_bvalid      (m_axi_bvalid),
        .m_axi_bready      (m_axi_bready),
        .m_axi_bid         (m_axi_bid),
        .m_axi_bresp       (m_axi_bresp),
        .err_wr_req_valid  (err_wr_req_valid),
        .err_wr_req_ready  (err_wr_req_ready),
        .err_wr_req_id     (err_wr_req_id),
        .err_wr_req_len    (err_wr_req_len),
        .err_wr_data_valid (err_wr_data_valid),
        .err_wr_data_ready (err_wr_data_ready),
        .err_wr_data_last  (err_wr_data_last),
        .err_wr_resp_valid (err_wr_resp_valid),
        .err_wr_resp_ready (err_wr_resp_ready),
        .err_wr_resp_id    (err_wr_resp_id),
        .err_wr_resp_resp  (err_wr_resp_resp)
    );

    //internal decode-error response engine
    axi_default_error #(
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_default_error (
        .clk            (clk),
        .rst_n          (rst_n),
        .rd_req_valid   (err_rd_req_valid),
        .rd_req_ready   (err_rd_req_ready),
        .rd_req_id      (err_rd_req_id),
        .rd_req_len     (err_rd_req_len),
        .rd_resp_valid  (err_rd_resp_valid),
        .rd_resp_ready  (err_rd_resp_ready),
        .rd_resp_id     (err_rd_resp_id),
        .rd_resp_data   (err_rd_resp_data),
        .rd_resp_resp   (err_rd_resp_resp),
        .rd_resp_last   (err_rd_resp_last),
        .wr_req_valid   (err_wr_req_valid),
        .wr_req_ready   (err_wr_req_ready),
        .wr_req_id      (err_wr_req_id),
        .wr_req_len     (err_wr_req_len),
        .wr_data_valid  (err_wr_data_valid),
        .wr_data_ready  (err_wr_data_ready),
        .wr_data_last   (err_wr_data_last),
        .wr_resp_valid  (err_wr_resp_valid),
        .wr_resp_ready  (err_wr_resp_ready),
        .wr_resp_id     (err_wr_resp_id),
        .wr_resp_resp   (err_wr_resp_resp)
    );
endmodule
