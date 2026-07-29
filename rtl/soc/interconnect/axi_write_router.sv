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
// Module       : axi_write_router
// Description  : Registered AXI write command router and response multiplexer
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-29
// Version      : 1.0
// -----------------------------------------------------------------------------

module axi_write_router
    import soc_addr_map_pkg::*;
#(
    parameter ID_WIDTH   = 2,
    parameter DATA_WIDTH = 32
) (
    //system
    input  logic                         clk,
    input  logic                         rst_n,

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

    //downstream AXI write address channels
    output logic                         m_axi_awvalid [SOC_NUM_SLAVES-1:0],
    input  logic                         m_axi_awready [SOC_NUM_SLAVES-1:0],
    output logic [ID_WIDTH-1:0]          m_axi_awid    [SOC_NUM_SLAVES-1:0],
    output logic [SOC_ADDR_WIDTH-1:0]    m_axi_awaddr  [SOC_NUM_SLAVES-1:0],
    output logic [7:0]                   m_axi_awlen   [SOC_NUM_SLAVES-1:0],
    output logic [2:0]                   m_axi_awsize  [SOC_NUM_SLAVES-1:0],
    output logic [1:0]                   m_axi_awburst [SOC_NUM_SLAVES-1:0],

    //downstream AXI write data channels
    output logic                         m_axi_wvalid [SOC_NUM_SLAVES-1:0],
    input  logic                         m_axi_wready [SOC_NUM_SLAVES-1:0],
    output logic [DATA_WIDTH-1:0]        m_axi_wdata  [SOC_NUM_SLAVES-1:0],
    output logic [(DATA_WIDTH/8)-1:0]    m_axi_wstrb  [SOC_NUM_SLAVES-1:0],
    output logic                         m_axi_wlast  [SOC_NUM_SLAVES-1:0],

    //downstream AXI write response channels
    input  logic                         m_axi_bvalid [SOC_NUM_SLAVES-1:0],
    output logic                         m_axi_bready [SOC_NUM_SLAVES-1:0],
    input  logic [ID_WIDTH-1:0]          m_axi_bid    [SOC_NUM_SLAVES-1:0],
    input  logic [1:0]                   m_axi_bresp  [SOC_NUM_SLAVES-1:0],

    //internal default-error write request
    output logic                         err_wr_req_valid,
    input  logic                         err_wr_req_ready,
    output logic [ID_WIDTH-1:0]          err_wr_req_id,
    output logic [7:0]                   err_wr_req_len,

    //internal default-error write data
    output logic                         err_wr_data_valid,
    input  logic                         err_wr_data_ready,
    output logic                         err_wr_data_last,

    //internal default-error write response
    input  logic                         err_wr_resp_valid,
    output logic                         err_wr_resp_ready,
    input  logic [ID_WIDTH-1:0]          err_wr_resp_id,
    input  logic [1:0]                   err_wr_resp_resp
);
    //write transaction state
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_SEND_AW,
        WR_FORWARD_W,
        WR_FORWARD_B
    } wr_state_t;

    wr_state_t wr_state, wr_state_next;

    //registered upstream AW command
    logic [ID_WIDTH-1:0]       aw_id_q;
    logic [SOC_ADDR_WIDTH-1:0] aw_addr_q;
    logic [7:0]                aw_len_q;
    logic [2:0]                aw_size_q;
    logic [1:0]                aw_burst_q;

    //latched response source
    soc_target_t wr_target_q;
    logic        wr_error_q;

    //decoded registered command
    soc_target_t decoded_target;
    logic        decode_error;

    //handshake events
    logic s_aw_fire;
    logic destination_aw_fire;
    logic s_w_fire;
    logic s_b_fire;

    //decode the registered AW command
    soc_addr_decode u_addr_decode (
        .addr         (aw_addr_q),
        .is_write     (1'b1),
        .is_fetch     (1'b0),
        .burst_len    (aw_len_q),
        .burst_size   (aw_size_q),
        .burst_type   (aw_burst_q),
        .target       (decoded_target),
        .decode_error (decode_error)
    );

    //accepted handshakes
    assign s_aw_fire = s_axi_awvalid && s_axi_awready;

    assign destination_aw_fire = decode_error
                               ? (err_wr_req_valid && err_wr_req_ready)
                               : (m_axi_awvalid[decoded_target] && m_axi_awready[decoded_target]);

    assign s_w_fire = s_axi_wvalid && s_axi_wready;
    assign s_b_fire = s_axi_bvalid && s_axi_bready;

    //write update state
    always_ff @(posedge clk) begin
        if (!rst_n)
            wr_state <= WR_IDLE;
        else
            wr_state <= wr_state_next;
    end

    //registered command and response ownership
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            aw_id_q      <= '0;
            aw_addr_q    <= '0;
            aw_len_q     <= '0;
            aw_size_q    <= '0;
            aw_burst_q   <= '0;
            wr_target_q  <= TARGET_MEM;
            wr_error_q   <= 1'b0;
        end else begin
            if (s_aw_fire) begin
                aw_id_q    <= s_axi_awid;
                aw_addr_q  <= s_axi_awaddr;
                aw_len_q   <= s_axi_awlen;
                aw_size_q  <= s_axi_awsize;
                aw_burst_q <= s_axi_awburst;
            end

            if (destination_aw_fire) begin
                wr_target_q <= decoded_target;
                wr_error_q  <= decode_error;
            end
        end
    end

    //next-state fsm
    always_comb begin
        wr_state_next = wr_state;

        case (wr_state)
            WR_IDLE: begin
                if (s_aw_fire)
                    wr_state_next = WR_SEND_AW;
            end

            WR_SEND_AW: begin
                if (destination_aw_fire)
                    wr_state_next = WR_FORWARD_W;
            end

            WR_FORWARD_W: begin
                if (s_w_fire && s_axi_wlast)
                    wr_state_next = WR_FORWARD_B;
            end

            WR_FORWARD_B: begin
                if (s_b_fire)
                    wr_state_next = WR_IDLE;
            end

            default: wr_state_next = WR_IDLE;
        endcase
    end

    //AW/W demultiplexers and B multiplexer
    always_comb begin
        //upstream defaults
        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;
        s_axi_bvalid  = 1'b0;
        s_axi_bid     = '0;
        s_axi_bresp   = '0;

        //real-slave defaults
        for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
            m_axi_awvalid[i] = 1'b0;
            m_axi_awid[i]    = aw_id_q;
            m_axi_awaddr[i]  = aw_addr_q;
            m_axi_awlen[i]   = aw_len_q;
            m_axi_awsize[i]  = aw_size_q;
            m_axi_awburst[i] = aw_burst_q;

            m_axi_wvalid[i]  = 1'b0;
            m_axi_wdata[i]   = s_axi_wdata;
            m_axi_wstrb[i]   = s_axi_wstrb;
            m_axi_wlast[i]   = s_axi_wlast;

            m_axi_bready[i]  = 1'b0;
        end

        //default-error defaults
        err_wr_req_valid  = 1'b0;
        err_wr_req_id     = aw_id_q;
        err_wr_req_len    = aw_len_q;
        err_wr_data_valid = 1'b0;
        err_wr_data_last  = s_axi_wlast;
        err_wr_resp_ready = 1'b0;

        case (wr_state)
            WR_IDLE: begin
                s_axi_awready = 1'b1;
            end

            WR_SEND_AW: begin
                if (decode_error)
                    err_wr_req_valid = 1'b1;
                else
                    m_axi_awvalid[decoded_target] = 1'b1;
            end

            WR_FORWARD_W: begin
                if (wr_error_q) begin
                    s_axi_wready      = err_wr_data_ready;
                    err_wr_data_valid = s_axi_wvalid;
                end else begin
                    s_axi_wready              = m_axi_wready[wr_target_q];
                    m_axi_wvalid[wr_target_q] = s_axi_wvalid;
                end
            end

            WR_FORWARD_B: begin
                if (wr_error_q) begin
                    s_axi_bvalid      = err_wr_resp_valid;
                    s_axi_bid         = err_wr_resp_id;
                    s_axi_bresp       = err_wr_resp_resp;
                    err_wr_resp_ready = s_axi_bready;
                end else begin
                    s_axi_bvalid              = m_axi_bvalid[wr_target_q];
                    s_axi_bid                 = m_axi_bid[wr_target_q];
                    s_axi_bresp               = m_axi_bresp[wr_target_q];
                    m_axi_bready[wr_target_q] = s_axi_bready;
                end
            end

            default: begin
                s_axi_awready = 1'b0;
            end
        endcase
    end
endmodule
