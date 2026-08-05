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
// Module       : axi_read_router
// Description  : Registered AXI read command router and response multiplexer
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-27
// Version      : 1.0
// -----------------------------------------------------------------------------

module axi_read_router
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

    //downstream AXI read address channels
    output logic [SOC_NUM_SLAVES-1:0]                     m_axi_arvalid,
    input  logic [SOC_NUM_SLAVES-1:0]                     m_axi_arready,
    output logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_arid,
    output logic [SOC_NUM_SLAVES-1:0][SOC_ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [SOC_NUM_SLAVES-1:0][7:0]                m_axi_arlen,
    output logic [SOC_NUM_SLAVES-1:0][2:0]                m_axi_arsize,
    output logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_arburst,

    //downstream AXI read response channels
    input  logic [SOC_NUM_SLAVES-1:0]                  m_axi_rvalid,
    output logic [SOC_NUM_SLAVES-1:0]                  m_axi_rready,
    input  logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]    m_axi_rid,
    input  logic [SOC_NUM_SLAVES-1:0][DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [SOC_NUM_SLAVES-1:0][1:0]             m_axi_rresp,
    input  logic [SOC_NUM_SLAVES-1:0]                  m_axi_rlast,

    //internal default-error read request
    output logic                         err_rd_req_valid,
    input  logic                         err_rd_req_ready,
    output logic [ID_WIDTH-1:0]          err_rd_req_id,
    output logic [7:0]                   err_rd_req_len,

    //internal default-error read response
    input  logic                         err_rd_resp_valid,
    output logic                         err_rd_resp_ready,
    input  logic [ID_WIDTH-1:0]          err_rd_resp_id,
    input  logic [DATA_WIDTH-1:0]        err_rd_resp_data,
    input  logic [1:0]                   err_rd_resp_resp,
    input  logic                         err_rd_resp_last
);
    //read transaction state
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_SEND_AR,
        RD_FORWARD_R
    } rd_state_t;

    rd_state_t rd_state, rd_state_next;

    //registered upstream AR command
    logic [ID_WIDTH-1:0]       ar_id_q;
    logic [SOC_ADDR_WIDTH-1:0] ar_addr_q;
    logic [7:0]                ar_len_q;
    logic [2:0]                ar_size_q;
    logic [1:0]                ar_burst_q;

    //latched response source
    soc_target_t rd_target_q;
    logic        rd_error_q;

    //decoded registered command
    soc_target_t decoded_target;
    logic        decode_error;

    //handshake events
    logic s_ar_fire;
    logic destination_ar_fire;
    logic s_r_fire;

    //decode the registered AR command
    soc_addr_decode u_addr_decode (
        .addr         (ar_addr_q),
        .is_write     (1'b0),
        .is_fetch     (ar_id_q == '0),
        .burst_len    (ar_len_q),
        .burst_size   (ar_size_q),
        .burst_type   (ar_burst_q),
        .hit          (),
        .target       (decoded_target),
        .readable     (),
        .writable     (),
        .executable   (),
        .cacheable    (),
        .device       (),
        .decode_error (decode_error)
    );

    //accepted handshakes
    assign s_ar_fire = s_axi_arvalid && s_axi_arready;

    assign destination_ar_fire = decode_error
                               ? (err_rd_req_valid && err_rd_req_ready)
                               : (m_axi_arvalid[decoded_target] && m_axi_arready[decoded_target]);

    assign s_r_fire = s_axi_rvalid && s_axi_rready;

    //read update state
    always_ff @(posedge clk) begin
        if (!rst_n)
            rd_state <= RD_IDLE;
        else
            rd_state <= rd_state_next;
    end

    //registered command and response ownership
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ar_id_q      <= '0;
            ar_addr_q    <= '0;
            ar_len_q     <= '0;
            ar_size_q    <= '0;
            ar_burst_q   <= '0;
            rd_target_q  <= TARGET_MEM;
            rd_error_q   <= 1'b0;
        end else begin
            if (s_ar_fire) begin
                ar_id_q    <= s_axi_arid;
                ar_addr_q  <= s_axi_araddr;
                ar_len_q   <= s_axi_arlen;
                ar_size_q  <= s_axi_arsize;
                ar_burst_q <= s_axi_arburst;
            end

            if (destination_ar_fire) begin
                rd_target_q <= decoded_target;
                rd_error_q  <= decode_error;
            end
        end
    end

    //next-state fsm
    always_comb begin
        rd_state_next = rd_state;

        case (rd_state)
            RD_IDLE: begin
                if (s_ar_fire)
                    rd_state_next = RD_SEND_AR;
            end

            RD_SEND_AR: begin
                if (destination_ar_fire)
                    rd_state_next = RD_FORWARD_R;
            end

            RD_FORWARD_R: begin
                if (s_r_fire && s_axi_rlast)
                    rd_state_next = RD_IDLE;
            end

            default: rd_state_next = RD_IDLE;
        endcase
    end

    //AR demultiplexer and R multiplexer
    always_comb begin
        //upstream defaults
        s_axi_arready = 1'b0;
        s_axi_rvalid  = 1'b0;
        s_axi_rid     = '0;
        s_axi_rdata   = '0;
        s_axi_rresp   = '0;
        s_axi_rlast   = 1'b0;

        //real-slave defaults
        for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
            m_axi_arvalid[i] = 1'b0;
            m_axi_arid[i]    = ar_id_q;
            m_axi_araddr[i]  = ar_addr_q;
            m_axi_arlen[i]   = ar_len_q;
            m_axi_arsize[i]  = ar_size_q;
            m_axi_arburst[i] = ar_burst_q;
            m_axi_rready[i]  = 1'b0;
        end

        //default-error defaults
        err_rd_req_valid  = 1'b0;
        err_rd_req_id     = ar_id_q;
        err_rd_req_len    = ar_len_q;
        err_rd_resp_ready = 1'b0;

        case (rd_state)
            RD_IDLE: begin
                s_axi_arready = 1'b1;
            end

            RD_SEND_AR: begin
                if (decode_error)
                    err_rd_req_valid = 1'b1;
                else
                    m_axi_arvalid[decoded_target] = 1'b1;
            end

            RD_FORWARD_R: begin
                if (rd_error_q) begin
                    s_axi_rvalid      = err_rd_resp_valid;
                    s_axi_rid         = err_rd_resp_id;
                    s_axi_rdata       = err_rd_resp_data;
                    s_axi_rresp       = err_rd_resp_resp;
                    s_axi_rlast       = err_rd_resp_last;
                    err_rd_resp_ready = s_axi_rready;
                end else begin
                    s_axi_rvalid              = m_axi_rvalid[rd_target_q];
                    s_axi_rid                 = m_axi_rid[rd_target_q];
                    s_axi_rdata               = m_axi_rdata[rd_target_q];
                    s_axi_rresp               = m_axi_rresp[rd_target_q];
                    s_axi_rlast               = m_axi_rlast[rd_target_q];
                    m_axi_rready[rd_target_q] = s_axi_rready;
                end
            end

            default: begin
                s_axi_arready = 1'b0;
            end
        endcase
    end
endmodule
