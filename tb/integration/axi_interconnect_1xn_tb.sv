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
// Module       : axi_interconnect_1xn_tb
// Description  : Directed integration test for AXI interconnect routing
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-08-04
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi_interconnect_1xn_tb;
    import soc_addr_map_pkg::*;
    import axi_pkg::*;

    localparam ID_WIDTH   = 2;
    localparam DATA_WIDTH = 32;
    localparam STRB_WIDTH = DATA_WIDTH / 8;

    typedef struct packed {
        logic [ID_WIDTH-1:0]       id;
        logic [SOC_ADDR_WIDTH-1:0] addr;
        logic [7:0]                len;
        logic [2:0]                size;
        logic [1:0]                burst;
    } addr_cmd_t;

    //system
    logic clk;
    logic rst_n;

    //upstream AXI interface
    logic                         s_axi_arvalid;
    logic                         s_axi_arready;
    logic [ID_WIDTH-1:0]          s_axi_arid;
    logic [SOC_ADDR_WIDTH-1:0]    s_axi_araddr;
    logic [7:0]                   s_axi_arlen;
    logic [2:0]                   s_axi_arsize;
    logic [1:0]                   s_axi_arburst;
    logic                         s_axi_rvalid;
    logic                         s_axi_rready;
    logic [ID_WIDTH-1:0]          s_axi_rid;
    logic [DATA_WIDTH-1:0]        s_axi_rdata;
    logic [1:0]                   s_axi_rresp;
    logic                         s_axi_rlast;

    logic                         s_axi_awvalid;
    logic                         s_axi_awready;
    logic [ID_WIDTH-1:0]          s_axi_awid;
    logic [SOC_ADDR_WIDTH-1:0]    s_axi_awaddr;
    logic [7:0]                   s_axi_awlen;
    logic [2:0]                   s_axi_awsize;
    logic [1:0]                   s_axi_awburst;
    logic                         s_axi_wvalid;
    logic                         s_axi_wready;
    logic [DATA_WIDTH-1:0]        s_axi_wdata;
    logic [STRB_WIDTH-1:0]        s_axi_wstrb;
    logic                         s_axi_wlast;
    logic                         s_axi_bvalid;
    logic                         s_axi_bready;
    logic [ID_WIDTH-1:0]          s_axi_bid;
    logic [1:0]                   s_axi_bresp;

    //downstream AXI interfaces
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_arvalid;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_arready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_arid;
    logic [SOC_NUM_SLAVES-1:0][SOC_ADDR_WIDTH-1:0] m_axi_araddr;
    logic [SOC_NUM_SLAVES-1:0][7:0]                m_axi_arlen;
    logic [SOC_NUM_SLAVES-1:0][2:0]                m_axi_arsize;
    logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_arburst;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_rvalid;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_rready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_rid;
    logic [SOC_NUM_SLAVES-1:0][DATA_WIDTH-1:0]     m_axi_rdata;
    logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_rresp;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_rlast;

    logic [SOC_NUM_SLAVES-1:0]                     m_axi_awvalid;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_awready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_awid;
    logic [SOC_NUM_SLAVES-1:0][SOC_ADDR_WIDTH-1:0] m_axi_awaddr;
    logic [SOC_NUM_SLAVES-1:0][7:0]                m_axi_awlen;
    logic [SOC_NUM_SLAVES-1:0][2:0]                m_axi_awsize;
    logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_awburst;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_wvalid;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_wready;
    logic [SOC_NUM_SLAVES-1:0][DATA_WIDTH-1:0]     m_axi_wdata;
    logic [SOC_NUM_SLAVES-1:0][STRB_WIDTH-1:0]     m_axi_wstrb;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_wlast;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_bvalid;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_bready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_bid;
    logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_bresp;

    int pass_count;
    int fail_count;
    bit case_ok;

    axi_interconnect_1xn #(
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_arid    (s_axi_arid),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arlen   (s_axi_arlen),
        .s_axi_arsize  (s_axi_arsize),
        .s_axi_arburst (s_axi_arburst),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .s_axi_rid     (s_axi_rid),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rlast   (s_axi_rlast),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_awid    (s_axi_awid),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awlen   (s_axi_awlen),
        .s_axi_awsize  (s_axi_awsize),
        .s_axi_awburst (s_axi_awburst),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wlast   (s_axi_wlast),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_bid     (s_axi_bid),
        .s_axi_bresp   (s_axi_bresp),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_arid    (m_axi_arid),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),
        .m_axi_rid     (m_axi_rid),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rlast   (m_axi_rlast),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),
        .m_axi_awid    (m_axi_awid),
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen   (m_axi_awlen),
        .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst (m_axi_awburst),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready),
        .m_axi_bid     (m_axi_bid),
        .m_axi_bresp   (m_axi_bresp)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic drive_idle;
        begin
            rst_n         = 1'b1;
            s_axi_arvalid = 1'b0;
            s_axi_arid    = '0;
            s_axi_araddr  = '0;
            s_axi_arlen   = '0;
            s_axi_arsize  = AXI_SIZE_4B;
            s_axi_arburst = AXI_BURST_INCR;
            s_axi_rready  = 1'b0;

            s_axi_awvalid = 1'b0;
            s_axi_awid    = '0;
            s_axi_awaddr  = '0;
            s_axi_awlen   = '0;
            s_axi_awsize  = AXI_SIZE_4B;
            s_axi_awburst = AXI_BURST_INCR;
            s_axi_wvalid  = 1'b0;
            s_axi_wdata   = '0;
            s_axi_wstrb   = '0;
            s_axi_wlast   = 1'b0;
            s_axi_bready  = 1'b0;

            m_axi_arready = '0;
            m_axi_rvalid  = '0;
            m_axi_rid     = '0;
            m_axi_rdata   = '0;
            m_axi_rresp   = '0;
            m_axi_rlast   = '0;
            m_axi_awready = '0;
            m_axi_wready  = '0;
            m_axi_bvalid  = '0;
            m_axi_bid     = '0;
            m_axi_bresp   = '0;
        end
    endtask

    task automatic reset_dut;
        begin
            drive_idle();
            rst_n = 1'b0;
            repeat (2) @(posedge clk);
            #1 rst_n = 1'b1;
        end
    endtask

    task automatic check_condition(
        input string test_name,
        input logic  condition,
        input string detail
    );
        if (condition !== 1'b1) begin
            if (case_ok)
                $display("FAIL | %s | %s", test_name, detail);
            else
                $display("     | %s", detail);
            case_ok = 1'b0;
        end
    endtask

    task automatic finish_case(
        input string test_name,
        input bit    case_result
    );
        if (case_result) begin
            pass_count++;
            $display("PASS | %s", test_name);
        end else begin
            fail_count++;
        end
    endtask

    task automatic set_arready(
        input soc_target_t target,
        input logic        value
    );
        case (target)
            TARGET_MEM:   m_axi_arready[0] = value;
            TARGET_TINY:  m_axi_arready[1] = value;
            TARGET_ASCON: m_axi_arready[2] = value;
            TARGET_APB:   m_axi_arready[3] = value;
            default: ;
        endcase
    endtask

    task automatic drive_rbeat(
        input soc_target_t             target,
        input logic                    valid,
        input logic [ID_WIDTH-1:0]     id,
        input logic [DATA_WIDTH-1:0]   data,
        input logic [1:0]              resp,
        input logic                    last
    );
        case (target)
            TARGET_MEM:
                {m_axi_rvalid[0], m_axi_rid[0], m_axi_rdata[0],
                 m_axi_rresp[0], m_axi_rlast[0]} = {valid, id, data, resp, last};
            TARGET_TINY:
                {m_axi_rvalid[1], m_axi_rid[1], m_axi_rdata[1],
                 m_axi_rresp[1], m_axi_rlast[1]} = {valid, id, data, resp, last};
            TARGET_ASCON:
                {m_axi_rvalid[2], m_axi_rid[2], m_axi_rdata[2],
                 m_axi_rresp[2], m_axi_rlast[2]} = {valid, id, data, resp, last};
            TARGET_APB:
                {m_axi_rvalid[3], m_axi_rid[3], m_axi_rdata[3],
                 m_axi_rresp[3], m_axi_rlast[3]} = {valid, id, data, resp, last};
            default: ;
        endcase
    endtask

    task automatic set_awready(
        input soc_target_t target,
        input logic        value
    );
        case (target)
            TARGET_MEM:   m_axi_awready[0] = value;
            TARGET_TINY:  m_axi_awready[1] = value;
            TARGET_ASCON: m_axi_awready[2] = value;
            TARGET_APB:   m_axi_awready[3] = value;
            default: ;
        endcase
    endtask

    task automatic set_wready(
        input soc_target_t target,
        input logic        value
    );
        case (target)
            TARGET_MEM:   m_axi_wready[0] = value;
            TARGET_TINY:  m_axi_wready[1] = value;
            TARGET_ASCON: m_axi_wready[2] = value;
            TARGET_APB:   m_axi_wready[3] = value;
            default: ;
        endcase
    endtask

    task automatic drive_bresp(
        input soc_target_t           target,
        input logic                  valid,
        input logic [ID_WIDTH-1:0]   id,
        input logic [1:0]            resp
    );
        case (target)
            TARGET_MEM:
                {m_axi_bvalid[0], m_axi_bid[0], m_axi_bresp[0]} = {valid, id, resp};
            TARGET_TINY:
                {m_axi_bvalid[1], m_axi_bid[1], m_axi_bresp[1]} = {valid, id, resp};
            TARGET_ASCON:
                {m_axi_bvalid[2], m_axi_bid[2], m_axi_bresp[2]} = {valid, id, resp};
            TARGET_APB:
                {m_axi_bvalid[3], m_axi_bid[3], m_axi_bresp[3]} = {valid, id, resp};
            default: ;
        endcase
    endtask

    task automatic check_read_idle(input string test_name);
        check_condition(test_name, s_axi_arready === 1'b1, "ARREADY low in IDLE");
        check_condition(test_name, s_axi_rvalid === 1'b0, "RVALID high in IDLE");
    endtask

    task automatic check_write_idle(input string test_name);
        check_condition(test_name, s_axi_awready === 1'b1, "AWREADY low in IDLE");
        check_condition(test_name, s_axi_wready === 1'b0, "WREADY high in IDLE");
        check_condition(test_name, s_axi_bvalid === 1'b0, "BVALID high in IDLE");
    endtask

    task automatic send_ar(
        input string     test_name,
        input addr_cmd_t cmd
    );
        @(negedge clk);
        s_axi_arvalid = 1'b1;
        {s_axi_arid, s_axi_araddr, s_axi_arlen, s_axi_arsize, s_axi_arburst} = cmd;
        #1 check_condition(test_name, s_axi_arready === 1'b1,
            "upstream AR was not accepted");
        @(posedge clk);
        #1 s_axi_arvalid = 1'b0;
    endtask

    task automatic send_aw(
        input string     test_name,
        input addr_cmd_t cmd
    );
        @(negedge clk);
        s_axi_awvalid = 1'b1;
        {s_axi_awid, s_axi_awaddr, s_axi_awlen, s_axi_awsize, s_axi_awburst} = cmd;
        #1 check_condition(test_name, s_axi_awready === 1'b1,
            "upstream AW was not accepted");
        @(posedge clk);
        #1 s_axi_awvalid = 1'b0;
    endtask

    task automatic run_real_read(
        input string               test_name,
        input soc_target_t         target,
        input addr_cmd_t           cmd,
        input logic [DATA_WIDTH-1:0] data_seed
    );
        int beat_count;
        begin
            beat_count = int'(cmd.len) + 1;
            set_arready(target, 1'b1);
            send_ar(test_name, cmd);

            @(negedge clk);
            #1;
            for (int i = 0; i < SOC_NUM_SLAVES; i++)
                check_condition(test_name, m_axi_arvalid[i] === (i == int'(target)),
                    $sformatf("ARVALID[%0d] routed incorrectly", i));
            check_condition(test_name,
                {m_axi_arid[target], m_axi_araddr[target], m_axi_arlen[target],
                 m_axi_arsize[target], m_axi_arburst[target]} === cmd,
                "selected AR payload changed");

            @(posedge clk);
            #1 set_arready(target, 1'b0);

            for (int beat = 0; beat < beat_count; beat++) begin
                @(negedge clk);
                drive_rbeat(target, 1'b1, cmd.id, data_seed + beat,
                    AXI_RESP_OKAY, (beat == beat_count - 1));
                s_axi_rready         = 1'b1;
                #1;
                check_condition(test_name, s_axi_rvalid === 1'b1,
                    "selected RVALID was not forwarded");
                check_condition(test_name,
                    {s_axi_rid, s_axi_rdata, s_axi_rresp, s_axi_rlast}
                    === {cmd.id, data_seed + beat, AXI_RESP_OKAY,
                         (beat == beat_count - 1)},
                    $sformatf("R payload changed at beat %0d", beat));
                for (int i = 0; i < SOC_NUM_SLAVES; i++)
                    check_condition(test_name, m_axi_rready[i] === (i == int'(target)),
                        $sformatf("RREADY[%0d] routed incorrectly", i));

                @(posedge clk);
                #1;
                drive_rbeat(target, 1'b0, '0, '0, AXI_RESP_OKAY, 1'b0);
                s_axi_rready = 1'b0;
            end

            @(negedge clk);
            #1 check_read_idle(test_name);
        end
    endtask

    task automatic run_real_write(
        input string                 test_name,
        input soc_target_t           target,
        input addr_cmd_t             cmd,
        input logic [DATA_WIDTH-1:0] data_seed
    );
        int beat_count;
        begin
            beat_count = int'(cmd.len) + 1;
            set_awready(target, 1'b1);
            send_aw(test_name, cmd);

            @(negedge clk);
            #1;
            for (int i = 0; i < SOC_NUM_SLAVES; i++)
                check_condition(test_name, m_axi_awvalid[i] === (i == int'(target)),
                    $sformatf("AWVALID[%0d] routed incorrectly", i));
            check_condition(test_name,
                {m_axi_awid[target], m_axi_awaddr[target], m_axi_awlen[target],
                 m_axi_awsize[target], m_axi_awburst[target]} === cmd,
                "selected AW payload changed");

            @(posedge clk);
            #1 set_awready(target, 1'b0);

            for (int beat = 0; beat < beat_count; beat++) begin
                @(negedge clk);
                s_axi_wvalid         = 1'b1;
                s_axi_wdata          = data_seed + beat;
                s_axi_wstrb          = '1;
                s_axi_wlast          = (beat == beat_count - 1);
                set_wready(target, 1'b1);
                #1;
                check_condition(test_name, s_axi_wready === 1'b1,
                    "selected WREADY was not forwarded");
                for (int i = 0; i < SOC_NUM_SLAVES; i++)
                    check_condition(test_name, m_axi_wvalid[i] === (i == int'(target)),
                        $sformatf("WVALID[%0d] routed incorrectly", i));
                check_condition(test_name,
                    {m_axi_wdata[target], m_axi_wstrb[target], m_axi_wlast[target]}
                    === {data_seed + beat, {STRB_WIDTH{1'b1}},
                         (beat == beat_count - 1)},
                    $sformatf("W payload changed at beat %0d", beat));

                @(posedge clk);
                #1;
                s_axi_wvalid         = 1'b0;
                s_axi_wlast          = 1'b0;
                set_wready(target, 1'b0);
            end

            @(negedge clk);
            drive_bresp(target, 1'b1, cmd.id, AXI_RESP_OKAY);
            s_axi_bready         = 1'b1;
            #1;
            check_condition(test_name, s_axi_bvalid === 1'b1,
                "selected BVALID was not forwarded");
            check_condition(test_name,
                {s_axi_bid, s_axi_bresp} === {cmd.id, AXI_RESP_OKAY},
                "selected B response changed");
            for (int i = 0; i < SOC_NUM_SLAVES; i++)
                check_condition(test_name, m_axi_bready[i] === (i == int'(target)),
                    $sformatf("BREADY[%0d] routed incorrectly", i));

            @(posedge clk);
            #1;
            drive_bresp(target, 1'b0, '0, AXI_RESP_OKAY);
            s_axi_bready = 1'b0;

            @(negedge clk);
            #1 check_write_idle(test_name);
        end
    endtask

    task automatic run_error_read(
        input string     test_name,
        input addr_cmd_t cmd
    );
        int beat_count;
        begin
            beat_count = int'(cmd.len) + 1;
            send_ar(test_name, cmd);

            @(negedge clk);
            #1;
            check_condition(test_name, m_axi_arvalid === '0,
                "rejected AR reached a real slave");
            @(posedge clk);
            #1;

            for (int beat = 0; beat < beat_count; beat++) begin
                @(negedge clk);
                s_axi_rready = 1'b1;
                #1;
                check_condition(test_name, s_axi_rvalid === 1'b1,
                    "default error RVALID was not forwarded");
                check_condition(test_name,
                    {s_axi_rid, s_axi_rdata, s_axi_rresp, s_axi_rlast}
                    === {cmd.id, {DATA_WIDTH{1'b0}}, AXI_RESP_DECERR,
                         (beat == beat_count - 1)},
                    $sformatf("default error R beat %0d changed", beat));
                check_condition(test_name, m_axi_rready === '0,
                    "default response selected a real R channel");

                @(posedge clk);
                #1 s_axi_rready = 1'b0;
            end

            @(negedge clk);
            #1 check_read_idle(test_name);
        end
    endtask

    task automatic run_error_write(
        input string     test_name,
        input addr_cmd_t cmd
    );
        int beat_count;
        begin
            beat_count = int'(cmd.len) + 1;
            send_aw(test_name, cmd);

            @(negedge clk);
            #1;
            check_condition(test_name, m_axi_awvalid === '0,
                "rejected AW reached a real slave");
            @(posedge clk);
            #1;

            for (int beat = 0; beat < beat_count; beat++) begin
                @(negedge clk);
                s_axi_wvalid = 1'b1;
                s_axi_wdata  = 32'hE000_0000 + beat;
                s_axi_wstrb  = '1;
                s_axi_wlast  = (beat == beat_count - 1);
                #1;
                check_condition(test_name, s_axi_wready === 1'b1,
                    "default error did not consume W beat");
                check_condition(test_name, m_axi_wvalid === '0,
                    "rejected W beat reached a real slave");
                check_condition(test_name, s_axi_bvalid === 1'b0,
                    "default error returned B before final W beat");

                @(posedge clk);
                #1;
                s_axi_wvalid = 1'b0;
                s_axi_wlast  = 1'b0;
            end

            @(negedge clk);
            s_axi_bready = 1'b1;
            #1;
            check_condition(test_name, s_axi_bvalid === 1'b1,
                "default error BVALID was not forwarded");
            check_condition(test_name,
                {s_axi_bid, s_axi_bresp} === {cmd.id, AXI_RESP_DECERR},
                "default error B response changed");
            check_condition(test_name, m_axi_bready === '0,
                "default response selected a real B channel");

            @(posedge clk);
            #1 s_axi_bready = 1'b0;

            @(negedge clk);
            #1 check_write_idle(test_name);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        reset_dut();

        //1. Every mapped region is reachable through the read hierarchy.
        case_ok = 1'b1;
        run_real_read("READ_ROUTE_ALL_TARGETS", TARGET_MEM,
            '{2'd1, 32'h0000_0100, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0000);
        run_real_read("READ_ROUTE_ALL_TARGETS", TARGET_TINY,
            '{2'd1, 32'h1000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_1000);
        run_real_read("READ_ROUTE_ALL_TARGETS", TARGET_ASCON,
            '{2'd2, 32'h2000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_2000);
        run_real_read("READ_ROUTE_ALL_TARGETS", TARGET_APB,
            '{2'd3, 32'h3000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_3000);
        finish_case("READ_ROUTE_ALL_TARGETS", case_ok);

        //2. Every mapped region is reachable through the write hierarchy.
        case_ok = 1'b1;
        run_real_write("WRITE_ROUTE_ALL_TARGETS", TARGET_MEM,
            '{2'd1, 32'h0000_0100, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h2000_0000);
        run_real_write("WRITE_ROUTE_ALL_TARGETS", TARGET_TINY,
            '{2'd1, 32'h1000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h2000_1000);
        run_real_write("WRITE_ROUTE_ALL_TARGETS", TARGET_ASCON,
            '{2'd2, 32'h2000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h2000_2000);
        run_real_write("WRITE_ROUTE_ALL_TARGETS", TARGET_APB,
            '{2'd3, 32'h3000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h2000_3000);
        finish_case("WRITE_ROUTE_ALL_TARGETS", case_ok);

        //3. A legal RAM burst keeps read ownership through its final beat.
        case_ok = 1'b1;
        run_real_read("READ_RAM_BURST", TARGET_MEM,
            '{2'd1, 32'h0000_0200, 8'd2, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h3000_0000);
        finish_case("READ_RAM_BURST", case_ok);

        //4. A legal RAM burst keeps write ownership through WLAST and B.
        case_ok = 1'b1;
        run_real_write("WRITE_RAM_BURST", TARGET_MEM,
            '{2'd2, 32'h0000_0300, 8'd2, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h4000_0000);
        finish_case("WRITE_RAM_BURST", case_ok);

        //5. An unmapped single read completes through the internal error responder.
        case_ok = 1'b1;
        run_error_read("READ_DEFAULT_SINGLE",
            '{2'd1, 32'h4000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR});
        finish_case("READ_DEFAULT_SINGLE", case_ok);

        //6. A policy-rejected MMIO read returns every requested DECERR beat.
        case_ok = 1'b1;
        run_error_read("READ_DEFAULT_BURST",
            '{2'd1, 32'h1000_0000, 8'd1, AXI_SIZE_4B, AXI_BURST_INCR});
        finish_case("READ_DEFAULT_BURST", case_ok);

        //7. An unmapped single write is consumed and completed with DECERR.
        case_ok = 1'b1;
        run_error_write("WRITE_DEFAULT_SINGLE",
            '{2'd1, 32'h4000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR});
        finish_case("WRITE_DEFAULT_SINGLE", case_ok);

        //8. A policy-rejected MMIO write consumes the burst before DECERR.
        case_ok = 1'b1;
        run_error_write("WRITE_DEFAULT_BURST",
            '{2'd2, 32'h2000_0000, 8'd1, AXI_SIZE_4B, AXI_BURST_INCR});
        finish_case("WRITE_DEFAULT_BURST", case_ok);

        $display("SUMMARY | PASS=%0d FAIL=%0d", pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1, "axi_interconnect_1xn_tb failed");
        $finish;
    end
endmodule
