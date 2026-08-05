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
// Module       : axi_write_router_tb
// Description  : Directed unit testbench for the registered AXI write router
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-29
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi_write_router_tb;
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
    } aw_cmd_t;

    typedef struct packed {
        logic [DATA_WIDTH-1:0] data;
        logic [STRB_WIDTH-1:0] strb;
        logic                  last;
    } w_beat_t;

    typedef struct packed {
        logic [ID_WIDTH-1:0] id;
        logic [1:0]          resp;
    } b_beat_t;

    logic clk;
    logic rst_n;

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

    logic [SOC_NUM_SLAVES-1:0]                     m_axi_awvalid;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_awready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_awid;
    logic [SOC_NUM_SLAVES-1:0][SOC_ADDR_WIDTH-1:0] m_axi_awaddr;
    logic [SOC_NUM_SLAVES-1:0][7:0]                m_axi_awlen;
    logic [SOC_NUM_SLAVES-1:0][2:0]                m_axi_awsize;
    logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_awburst;

    logic [SOC_NUM_SLAVES-1:0]                 m_axi_wvalid;
    logic [SOC_NUM_SLAVES-1:0]                 m_axi_wready;
    logic [SOC_NUM_SLAVES-1:0][DATA_WIDTH-1:0] m_axi_wdata;
    logic [SOC_NUM_SLAVES-1:0][STRB_WIDTH-1:0] m_axi_wstrb;
    logic [SOC_NUM_SLAVES-1:0]                 m_axi_wlast;

    logic [SOC_NUM_SLAVES-1:0]               m_axi_bvalid;
    logic [SOC_NUM_SLAVES-1:0]               m_axi_bready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0] m_axi_bid;
    logic [SOC_NUM_SLAVES-1:0][1:0]          m_axi_bresp;

    logic                         err_wr_req_valid;
    logic                         err_wr_req_ready;
    logic [ID_WIDTH-1:0]          err_wr_req_id;
    logic [7:0]                   err_wr_req_len;
    logic                         err_wr_data_valid;
    logic                         err_wr_data_ready;
    logic                         err_wr_data_last;
    logic                         err_wr_resp_valid;
    logic                         err_wr_resp_ready;
    logic [ID_WIDTH-1:0]          err_wr_resp_id;
    logic [1:0]                   err_wr_resp_resp;

    int pass_count;
    int fail_count;
    bit case_ok;

    axi_write_router #(
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic drive_idle;
        begin
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

            err_wr_req_ready  = 1'b0;
            err_wr_data_ready = 1'b0;
            err_wr_resp_valid = 1'b0;
            err_wr_resp_id    = '0;
            err_wr_resp_resp  = AXI_RESP_DECERR;

            for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
                m_axi_awready[i] = 1'b0;
                m_axi_wready[i]  = 1'b0;
                m_axi_bvalid[i]  = 1'b0;
                m_axi_bid[i]     = '0;
                m_axi_bresp[i]   = AXI_RESP_OKAY;
            end
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

    task automatic finish_case(input string test_name, input bit case_ok);
        if (case_ok) begin
            pass_count++;
            $display("PASS | %s", test_name);
        end else begin
            fail_count++;
        end
    endtask

    task automatic check_idle(input string test_name);
        check_condition(test_name, s_axi_awready === 1'b1, "AWREADY low in IDLE");
        check_condition(test_name, s_axi_wready === 1'b0, "WREADY high in IDLE");
        check_condition(test_name, s_axi_bvalid === 1'b0, "BVALID high in IDLE");
    endtask

    task automatic send_upstream_aw(
        input string   test_name,
        input aw_cmd_t cmd
    );
        @(negedge clk);
        s_axi_awvalid = 1'b1;
        {s_axi_awid, s_axi_awaddr, s_axi_awlen, s_axi_awsize, s_axi_awburst} = cmd;
        #1;
        check_condition(test_name, s_axi_awready === 1'b1, "upstream AW not accepted");

        @(posedge clk);
        #1 s_axi_awvalid = 1'b0;
    endtask

    task automatic check_selected_aw(
        input string       test_name,
        input soc_target_t target,
        input aw_cmd_t     cmd
    );
        for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
            check_condition(
                test_name,
                m_axi_awvalid[i] === (i == int'(target)),
                $sformatf("AWVALID[%0d] selected incorrectly", i)
            );
        end
        check_condition(
            test_name,
            {m_axi_awid[target], m_axi_awaddr[target], m_axi_awlen[target],
             m_axi_awsize[target], m_axi_awburst[target]} === cmd,
            "selected AW payload changed"
        );
        check_condition(test_name, err_wr_req_valid === 1'b0,
            "error path selected for legal AW");
        check_condition(test_name, s_axi_wready === 1'b0,
            "W accepted before destination AW");
    endtask

    task automatic start_real_write(
        input string       test_name,
        input soc_target_t target,
        input aw_cmd_t     cmd,
        input int          stall_cycles
    );
        if (stall_cycles == 0)
            m_axi_awready[target] = 1'b1;

        send_upstream_aw(test_name, cmd);

        repeat (stall_cycles) begin
            @(negedge clk);
            #1 check_selected_aw(test_name, target, cmd);
            @(posedge clk);
            #1;
        end

        if (stall_cycles != 0)
            m_axi_awready[target] = 1'b1;

        @(negedge clk);
        #1 check_selected_aw(test_name, target, cmd);
        @(posedge clk);
        #1 m_axi_awready[target] = 1'b0;
    endtask

    task automatic send_real_wbeat(
        input string       test_name,
        input soc_target_t target,
        input w_beat_t     beat,
        input logic        ready
    );
        s_axi_wvalid = 1'b1;
        {s_axi_wdata, s_axi_wstrb, s_axi_wlast} = beat;
        m_axi_wready[target] = ready;

        @(negedge clk);
        #1;
        check_condition(test_name, s_axi_wready === ready,
            "upstream WREADY routed incorrectly");
        for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
            check_condition(
                test_name,
                m_axi_wvalid[i] === (i == int'(target)),
                $sformatf("WVALID[%0d] selected incorrectly", i)
            );
        end
        check_condition(
            test_name,
            {m_axi_wdata[target], m_axi_wstrb[target], m_axi_wlast[target]} === beat,
            "selected W payload changed"
        );
        check_condition(test_name, err_wr_data_valid === 1'b0,
            "error W path selected for legal write");

        @(posedge clk);
        #1;
        if (ready)
            s_axi_wvalid = 1'b0;
        m_axi_wready[target] = 1'b0;
    endtask

    task automatic send_real_bresp(
        input string       test_name,
        input soc_target_t target,
        input b_beat_t     beat,
        input logic        ready
    );
        m_axi_bvalid[target] = 1'b1;
        {m_axi_bid[target], m_axi_bresp[target]} = beat;
        s_axi_bready = ready;

        @(negedge clk);
        #1;
        check_condition(test_name, s_axi_bvalid === 1'b1,
            "selected BVALID not forwarded");
        check_condition(test_name, {s_axi_bid, s_axi_bresp} === beat,
            "selected B payload changed");
        for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
            check_condition(
                test_name,
                m_axi_bready[i] === ((i == int'(target)) && ready),
                $sformatf("BREADY[%0d] routed incorrectly", i)
            );
        end

        @(posedge clk);
        #1;
        if (ready)
            m_axi_bvalid[target] = 1'b0;
        s_axi_bready = 1'b0;
    endtask

    task automatic run_single_real(
        input string       test_name,
        input soc_target_t target,
        input aw_cmd_t     cmd,
        input logic [31:0] data
    );
        start_real_write(test_name, target, cmd, 0);
        send_real_wbeat(test_name, target, '{data, 4'hF, 1'b1}, 1'b1);
        send_real_bresp(test_name, target, '{cmd.id, AXI_RESP_OKAY}, 1'b1);
        check_idle(test_name);
    endtask

    task automatic run_error_write(
        input string   test_name,
        input aw_cmd_t cmd
    );
        err_wr_req_ready = 1'b1;
        send_upstream_aw(test_name, cmd);

        @(negedge clk);
        #1;
        check_condition(test_name, err_wr_req_valid === 1'b1,
            "error request not selected");
        check_condition(test_name, {err_wr_req_id, err_wr_req_len} === {cmd.id, cmd.len},
            "error request metadata changed");
        for (int i = 0; i < SOC_NUM_SLAVES; i++)
            check_condition(test_name, m_axi_awvalid[i] === 1'b0,
                "real slave selected on error");

        @(posedge clk);
        #1 err_wr_req_ready = 1'b0;

        s_axi_wvalid       = 1'b1;
        s_axi_wdata        = 32'hDEAD_BEEF;
        s_axi_wstrb        = 4'hF;
        s_axi_wlast        = 1'b1;
        err_wr_data_ready  = 1'b1;

        @(negedge clk);
        #1;
        check_condition(test_name, s_axi_wready === 1'b1,
            "error WREADY not forwarded");
        check_condition(test_name, err_wr_data_valid === 1'b1,
            "error WVALID not forwarded");
        check_condition(test_name, err_wr_data_last === 1'b1,
            "error WLAST not forwarded");

        @(posedge clk);
        #1;
        s_axi_wvalid      = 1'b0;
        err_wr_data_ready = 1'b0;

        err_wr_resp_valid = 1'b1;
        err_wr_resp_id    = cmd.id;
        err_wr_resp_resp  = AXI_RESP_DECERR;
        s_axi_bready      = 1'b1;

        @(negedge clk);
        #1;
        check_condition(test_name, s_axi_bvalid === 1'b1,
            "error BVALID not forwarded");
        check_condition(test_name, {s_axi_bid, s_axi_bresp}
            === {cmd.id, AXI_RESP_DECERR}, "error B response changed");
        check_condition(test_name, err_wr_resp_ready === 1'b1,
            "error BREADY not forwarded");

        @(posedge clk);
        #1;
        err_wr_resp_valid = 1'b0;
        s_axi_bready      = 1'b0;
        check_idle(test_name);
    endtask

    initial begin
        aw_cmd_t cmd;
        w_beat_t beat;
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;
        reset_dut();

        //1. Every legal region routes to exactly one real slave; ownership can change next transaction.
        case_ok = 1'b1;
        run_single_real("WRITE_ROUTE_ALL_TARGETS", TARGET_MEM,
            '{2'd1, 32'h0000_0100, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0001);
        run_single_real("WRITE_ROUTE_ALL_TARGETS", TARGET_TINY,
            '{2'd1, 32'h1000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0002);
        run_single_real("WRITE_ROUTE_ALL_TARGETS", TARGET_ASCON,
            '{2'd2, 32'h2000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0003);
        run_single_real("WRITE_ROUTE_ALL_TARGETS", TARGET_APB,
            '{2'd3, 32'h3000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0004);
        finish_case("WRITE_ROUTE_ALL_TARGETS", case_ok);

        //2. AW payload remains stable while selected slave stalls.
        case_ok = 1'b1;
        cmd = '{2'd2, 32'h2000_0010, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_write("WRITE_AW_BACKPRESSURE", TARGET_ASCON, cmd, 2);
        send_real_wbeat("WRITE_AW_BACKPRESSURE", TARGET_ASCON,
            '{32'hA5A5_0001, 4'hF, 1'b1}, 1'b1);
        send_real_bresp("WRITE_AW_BACKPRESSURE", TARGET_ASCON,
            '{cmd.id, AXI_RESP_OKAY}, 1'b1);
        check_idle("WRITE_AW_BACKPRESSURE");
        finish_case("WRITE_AW_BACKPRESSURE", case_ok);

        //3. Early WVALID is held off until the registered AW destination handshake completes.
        case_ok = 1'b1;
        cmd = '{2'd1, 32'h1000_0020, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR};
        beat = '{32'hEA21_0001, 4'h3, 1'b1};
        @(negedge clk);
        s_axi_wvalid = 1'b1;
        {s_axi_wdata, s_axi_wstrb, s_axi_wlast} = beat;
        m_axi_wready[TARGET_TINY] = 1'b1;
        #1 check_condition("WRITE_W_EARLY", s_axi_wready === 1'b0,
            "W accepted in IDLE");
        send_upstream_aw("WRITE_W_EARLY", cmd);
        @(negedge clk);
        #1;
        check_selected_aw("WRITE_W_EARLY", TARGET_TINY, cmd);
        m_axi_awready[TARGET_TINY] = 1'b1;
        @(posedge clk);
        #1 m_axi_awready[TARGET_TINY] = 1'b0;
        @(negedge clk);
        #1;
        check_condition("WRITE_W_EARLY", s_axi_wready === 1'b1,
            "early W not released after AW handshake");
        check_condition("WRITE_W_EARLY", m_axi_wvalid[TARGET_TINY] === 1'b1,
            "early W not routed to latched target");
        check_condition("WRITE_W_EARLY",
            {m_axi_wdata[TARGET_TINY], m_axi_wstrb[TARGET_TINY], m_axi_wlast[TARGET_TINY]} === beat,
            "early W payload changed");
        @(posedge clk);
        #1;
        s_axi_wvalid = 1'b0;
        m_axi_wready[TARGET_TINY] = 1'b0;
        send_real_bresp("WRITE_W_EARLY", TARGET_TINY,
            '{cmd.id, AXI_RESP_OKAY}, 1'b1);
        check_idle("WRITE_W_EARLY");
        finish_case("WRITE_W_EARLY", case_ok);

        //4. Latched AW target owns every W beat through accepted WLAST.
        case_ok = 1'b1;
        cmd = '{2'd1, 32'h0000_0200, 8'd2, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_write("WRITE_BURST", TARGET_MEM, cmd, 0);
        send_real_wbeat("WRITE_BURST", TARGET_MEM,
            '{32'hB000_0000, 4'hF, 1'b0}, 1'b1);
        send_real_wbeat("WRITE_BURST", TARGET_MEM,
            '{32'hB000_0001, 4'hF, 1'b0}, 1'b1);
        send_real_wbeat("WRITE_BURST", TARGET_MEM,
            '{32'hB000_0002, 4'hF, 1'b1}, 1'b1);
        send_real_bresp("WRITE_BURST", TARGET_MEM,
            '{cmd.id, AXI_RESP_OKAY}, 1'b1);
        check_idle("WRITE_BURST");
        finish_case("WRITE_BURST", case_ok);

        //5. W payload and ownership remain stable while selected slave stalls.
        case_ok = 1'b1;
        cmd = '{2'd3, 32'h0000_0300, 8'd1, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_write("WRITE_W_BACKPRESSURE", TARGET_MEM, cmd, 0);
        beat = '{32'hC0DE_0001, 4'h5, 1'b0};
        send_real_wbeat("WRITE_W_BACKPRESSURE", TARGET_MEM, beat, 1'b0);
        send_real_wbeat("WRITE_W_BACKPRESSURE", TARGET_MEM, beat, 1'b0);
        send_real_wbeat("WRITE_W_BACKPRESSURE", TARGET_MEM, beat, 1'b1);
        send_real_wbeat("WRITE_W_BACKPRESSURE", TARGET_MEM,
            '{32'hC0DE_0002, 4'hA, 1'b1}, 1'b1);
        send_real_bresp("WRITE_W_BACKPRESSURE", TARGET_MEM,
            '{cmd.id, AXI_RESP_OKAY}, 1'b1);
        check_idle("WRITE_W_BACKPRESSURE");
        finish_case("WRITE_W_BACKPRESSURE", case_ok);

        //6. B response remains selected until upstream accepts it.
        case_ok = 1'b1;
        cmd = '{2'd3, 32'h3000_0010, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_write("WRITE_B_BACKPRESSURE", TARGET_APB, cmd, 0);
        send_real_wbeat("WRITE_B_BACKPRESSURE", TARGET_APB,
            '{32'hBAAC_0001, 4'hF, 1'b1}, 1'b1);
        send_real_bresp("WRITE_B_BACKPRESSURE", TARGET_APB,
            '{cmd.id, AXI_RESP_OKAY}, 1'b0);
        check_condition("WRITE_B_BACKPRESSURE", s_axi_awready === 1'b0,
            "stalled B completed transaction");
        send_real_bresp("WRITE_B_BACKPRESSURE", TARGET_APB,
            '{cmd.id, AXI_RESP_OKAY}, 1'b0);
        send_real_bresp("WRITE_B_BACKPRESSURE", TARGET_APB,
            '{cmd.id, AXI_RESP_OKAY}, 1'b1);
        check_idle("WRITE_B_BACKPRESSURE");
        finish_case("WRITE_B_BACKPRESSURE", case_ok);

        //7. Both unmapped and policy-rejected AW use the error path.
        case_ok = 1'b1;
        run_error_write("WRITE_DECODE_ERROR",
            '{2'd1, 32'h4000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR});
        run_error_write("WRITE_DECODE_ERROR",
            '{2'd2, 32'h2000_0000, 8'd1, AXI_SIZE_4B, AXI_BURST_INCR});
        finish_case("WRITE_DECODE_ERROR", case_ok);

        $display("SUMMARY | PASS=%0d FAIL=%0d", pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1, "axi_write_router_tb failed");
        $finish;
    end
endmodule
