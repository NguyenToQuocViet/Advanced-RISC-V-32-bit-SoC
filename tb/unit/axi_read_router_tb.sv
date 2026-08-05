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
// Module       : axi_read_router_tb
// Description  : Directed unit testbench for the registered AXI read router
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-29
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi_read_router_tb;
    import soc_addr_map_pkg::*;
    import axi_pkg::*;

    localparam ID_WIDTH   = 2;
    localparam DATA_WIDTH = 32;

    typedef struct packed {
        logic [ID_WIDTH-1:0]       id;
        logic [SOC_ADDR_WIDTH-1:0] addr;
        logic [7:0]                len;
        logic [2:0]                size;
        logic [1:0]                burst;
    } ar_cmd_t;

    typedef struct packed {
        logic [ID_WIDTH-1:0]   id;
        logic [DATA_WIDTH-1:0] data;
        logic [1:0]            resp;
        logic                  last;
    } r_beat_t;

    logic clk;
    logic rst_n;

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

    logic [SOC_NUM_SLAVES-1:0]                     m_axi_arvalid;
    logic [SOC_NUM_SLAVES-1:0]                     m_axi_arready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]       m_axi_arid;
    logic [SOC_NUM_SLAVES-1:0][SOC_ADDR_WIDTH-1:0] m_axi_araddr;
    logic [SOC_NUM_SLAVES-1:0][7:0]                m_axi_arlen;
    logic [SOC_NUM_SLAVES-1:0][2:0]                m_axi_arsize;
    logic [SOC_NUM_SLAVES-1:0][1:0]                m_axi_arburst;

    logic [SOC_NUM_SLAVES-1:0]                 m_axi_rvalid;
    logic [SOC_NUM_SLAVES-1:0]                 m_axi_rready;
    logic [SOC_NUM_SLAVES-1:0][ID_WIDTH-1:0]   m_axi_rid;
    logic [SOC_NUM_SLAVES-1:0][DATA_WIDTH-1:0] m_axi_rdata;
    logic [SOC_NUM_SLAVES-1:0][1:0]            m_axi_rresp;
    logic [SOC_NUM_SLAVES-1:0]                 m_axi_rlast;

    logic                         err_rd_req_valid;
    logic                         err_rd_req_ready;
    logic [ID_WIDTH-1:0]          err_rd_req_id;
    logic [7:0]                   err_rd_req_len;
    logic                         err_rd_resp_valid;
    logic                         err_rd_resp_ready;
    logic [ID_WIDTH-1:0]          err_rd_resp_id;
    logic [DATA_WIDTH-1:0]        err_rd_resp_data;
    logic [1:0]                   err_rd_resp_resp;
    logic                         err_rd_resp_last;

    int pass_count;
    int fail_count;
    bit case_ok;

    axi_read_router #(
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic drive_idle;
        begin
            s_axi_arvalid = 1'b0;
            s_axi_arid    = '0;
            s_axi_araddr  = '0;
            s_axi_arlen   = '0;
            s_axi_arsize  = AXI_SIZE_4B;
            s_axi_arburst = AXI_BURST_INCR;
            s_axi_rready  = 1'b0;

            err_rd_req_ready  = 1'b0;
            err_rd_resp_valid = 1'b0;
            err_rd_resp_id    = '0;
            err_rd_resp_data  = '0;
            err_rd_resp_resp  = AXI_RESP_DECERR;
            err_rd_resp_last  = 1'b0;

            for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
                m_axi_arready[i] = 1'b0;
                m_axi_rvalid[i]  = 1'b0;
                m_axi_rid[i]     = '0;
                m_axi_rdata[i]   = '0;
                m_axi_rresp[i]   = AXI_RESP_OKAY;
                m_axi_rlast[i]   = 1'b0;
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

    task automatic set_arready(input soc_target_t target, input logic value);
        case (target)
            TARGET_MEM:   m_axi_arready[0] = value;
            TARGET_TINY:  m_axi_arready[1] = value;
            TARGET_ASCON: m_axi_arready[2] = value;
            TARGET_APB:   m_axi_arready[3] = value;
            default: ;
        endcase
    endtask

    task automatic set_rbeat(
        input soc_target_t target,
        input logic        valid,
        input r_beat_t     beat
    );
        case (target)
            TARGET_MEM: begin
                m_axi_rvalid[0] = valid;
                {m_axi_rid[0], m_axi_rdata[0], m_axi_rresp[0], m_axi_rlast[0]} = beat;
            end
            TARGET_TINY: begin
                m_axi_rvalid[1] = valid;
                {m_axi_rid[1], m_axi_rdata[1], m_axi_rresp[1], m_axi_rlast[1]} = beat;
            end
            TARGET_ASCON: begin
                m_axi_rvalid[2] = valid;
                {m_axi_rid[2], m_axi_rdata[2], m_axi_rresp[2], m_axi_rlast[2]} = beat;
            end
            TARGET_APB: begin
                m_axi_rvalid[3] = valid;
                {m_axi_rid[3], m_axi_rdata[3], m_axi_rresp[3], m_axi_rlast[3]} = beat;
            end
            default: ;
        endcase
    endtask

    task automatic check_idle(input string test_name);
        check_condition(test_name, s_axi_arready === 1'b1, "ARREADY low in IDLE");
        check_condition(test_name, s_axi_rvalid === 1'b0, "RVALID high in IDLE");
    endtask

    task automatic send_upstream_ar(
        input string   test_name,
        input ar_cmd_t cmd
    );
        @(negedge clk);
        s_axi_arvalid = 1'b1;
        {s_axi_arid, s_axi_araddr, s_axi_arlen, s_axi_arsize, s_axi_arburst} = cmd;
        #1;
        check_condition(test_name, s_axi_arready === 1'b1, "upstream AR not accepted");

        @(posedge clk);
        #1 s_axi_arvalid = 1'b0;
    endtask

    task automatic check_selected_ar(
        input string       test_name,
        input soc_target_t target,
        input ar_cmd_t     cmd
    );
        for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
            check_condition(
                test_name,
                m_axi_arvalid[i] === (i == target),
                $sformatf("ARVALID[%0d] selected incorrectly", i)
            );
        end
        check_condition(
            test_name,
            {m_axi_arid[target], m_axi_araddr[target], m_axi_arlen[target],
             m_axi_arsize[target], m_axi_arburst[target]} === cmd,
            "selected AR payload changed"
        );
        check_condition(test_name, err_rd_req_valid === 1'b0, "error path selected for legal AR");
    endtask

    task automatic start_real_read(
        input string       test_name,
        input soc_target_t target,
        input ar_cmd_t     cmd,
        input int          stall_cycles
    );
        if (stall_cycles == 0)
            set_arready(target, 1'b1);

        send_upstream_ar(test_name, cmd);

        repeat (stall_cycles) begin
            @(negedge clk);
            #1;
            check_selected_ar(test_name, target, cmd);
            check_condition(test_name, s_axi_arready === 1'b0, "accepted second AR while busy");
            @(posedge clk);
            #1;
        end

        if (stall_cycles != 0)
            set_arready(target, 1'b1);

        @(negedge clk);
        #1 check_selected_ar(test_name, target, cmd);
        @(posedge clk);
        #1 set_arready(target, 1'b0);
    endtask

    task automatic send_real_beat(
        input string       test_name,
        input soc_target_t target,
        input r_beat_t     beat,
        input logic        ready
    );
        set_rbeat(target, 1'b1, beat);
        s_axi_rready = ready;

        @(negedge clk);
        #1;
        check_condition(test_name, s_axi_rvalid === 1'b1, "selected RVALID not forwarded");
        check_condition(
            test_name,
            {s_axi_rid, s_axi_rdata, s_axi_rresp, s_axi_rlast} === beat,
            "selected R payload changed"
        );
        for (int i = 0; i < SOC_NUM_SLAVES; i++) begin
            check_condition(
                test_name,
                m_axi_rready[i] === ((i == target) && ready),
                $sformatf("RREADY[%0d] routed incorrectly", i)
            );
        end

        @(posedge clk);
        #1;
        if (ready)
            set_rbeat(target, 1'b0, '0);
        s_axi_rready = 1'b0;
    endtask

    task automatic run_single_real(
        input string       test_name,
        input soc_target_t target,
        input ar_cmd_t     cmd,
        input logic [31:0] data
    );
        r_beat_t beat;
        beat = '{id: cmd.id, data: data, resp: AXI_RESP_OKAY, last: 1'b1};
        start_real_read(test_name, target, cmd, 0);
        send_real_beat(test_name, target, beat, 1'b1);
        check_idle(test_name);
    endtask

    task automatic run_error_read(
        input string   test_name,
        input ar_cmd_t cmd
    );
        err_rd_req_ready = 1'b1;
        send_upstream_ar(test_name, cmd);

        @(negedge clk);
        #1;
        check_condition(test_name, err_rd_req_valid === 1'b1, "error request not selected");
        check_condition(
            test_name,
            {err_rd_req_id, err_rd_req_len} === {cmd.id, cmd.len},
            "error request metadata changed"
        );
        for (int i = 0; i < SOC_NUM_SLAVES; i++)
            check_condition(test_name, m_axi_arvalid[i] === 1'b0, "real slave selected on error");

        @(posedge clk);
        #1 err_rd_req_ready = 1'b0;

        err_rd_resp_valid = 1'b1;
        err_rd_resp_id    = cmd.id;
        err_rd_resp_data  = '0;
        err_rd_resp_resp  = AXI_RESP_DECERR;
        err_rd_resp_last  = 1'b1;
        s_axi_rready      = 1'b1;

        @(negedge clk);
        #1;
        check_condition(test_name, s_axi_rvalid === 1'b1, "error RVALID not forwarded");
        check_condition(
            test_name,
            {s_axi_rid, s_axi_rdata, s_axi_rresp, s_axi_rlast}
                === {cmd.id, 32'b0, AXI_RESP_DECERR, 1'b1},
            "error response changed"
        );
        check_condition(test_name, err_rd_resp_ready === 1'b1, "error RREADY not forwarded");

        @(posedge clk);
        #1;
        err_rd_resp_valid = 1'b0;
        s_axi_rready      = 1'b0;
        check_idle(test_name);
    endtask

    initial begin
        ar_cmd_t cmd;
        r_beat_t beat;
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;
        reset_dut();

        //1. Every legal region routes to exactly one real slave.
        case_ok = 1'b1;
        run_single_real("READ_ROUTE_ALL_TARGETS", TARGET_MEM,
            '{2'd1, 32'h0000_0100, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0001);
        run_single_real("READ_ROUTE_ALL_TARGETS", TARGET_TINY,
            '{2'd1, 32'h1000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0002);
        run_single_real("READ_ROUTE_ALL_TARGETS", TARGET_ASCON,
            '{2'd2, 32'h2000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0003);
        run_single_real("READ_ROUTE_ALL_TARGETS", TARGET_APB,
            '{2'd3, 32'h3000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR}, 32'h1000_0004);
        finish_case("READ_ROUTE_ALL_TARGETS", case_ok);
        finish_case("READ_TARGET_SWITCH", case_ok);

        //2. AR payload remains stable while selected slave stalls.
        case_ok = 1'b1;
        cmd = '{2'd2, 32'h2000_0010, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_read("READ_AR_BACKPRESSURE", TARGET_ASCON, cmd, 2);
        beat = '{cmd.id, 32'hA5A5_0001, AXI_RESP_OKAY, 1'b1};
        send_real_beat("READ_AR_BACKPRESSURE", TARGET_ASCON, beat, 1'b1);
        check_idle("READ_AR_BACKPRESSURE");
        finish_case("READ_AR_BACKPRESSURE", case_ok);

        //3. Target ownership remains locked through every R beat.
        case_ok = 1'b1;
        cmd = '{2'd1, 32'h0000_0200, 8'd2, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_read("READ_BURST", TARGET_MEM, cmd, 0);
        send_real_beat("READ_BURST", TARGET_MEM,
            '{cmd.id, 32'hB000_0000, AXI_RESP_OKAY, 1'b0}, 1'b1);
        send_real_beat("READ_BURST", TARGET_MEM,
            '{cmd.id, 32'hB000_0001, AXI_RESP_OKAY, 1'b0}, 1'b1);
        send_real_beat("READ_BURST", TARGET_MEM,
            '{cmd.id, 32'hB000_0002, AXI_RESP_OKAY, 1'b1}, 1'b1);
        check_idle("READ_BURST");
        finish_case("READ_BURST", case_ok);

        //4. Non-final R beat remains selected while upstream stalls.
        case_ok = 1'b1;
        cmd = '{2'd3, 32'h0000_0300, 8'd1, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_read("READ_R_BACKPRESSURE", TARGET_MEM, cmd, 0);
        beat = '{cmd.id, 32'hC0DE_0001, AXI_RESP_OKAY, 1'b0};
        send_real_beat("READ_R_BACKPRESSURE", TARGET_MEM, beat, 1'b0);
        send_real_beat("READ_R_BACKPRESSURE", TARGET_MEM, beat, 1'b0);
        send_real_beat("READ_R_BACKPRESSURE", TARGET_MEM, beat, 1'b1);
        send_real_beat("READ_R_BACKPRESSURE", TARGET_MEM,
            '{cmd.id, 32'hC0DE_0002, AXI_RESP_OKAY, 1'b1}, 1'b1);
        check_idle("READ_R_BACKPRESSURE");
        finish_case("READ_R_BACKPRESSURE", case_ok);

        //5. RLAST without RREADY does not complete the transaction.
        case_ok = 1'b1;
        cmd = '{2'd1, 32'h1000_0020, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR};
        start_real_read("READ_LAST_STALLED", TARGET_TINY, cmd, 0);
        beat = '{cmd.id, 32'h1A57_0001, AXI_RESP_OKAY, 1'b1};
        send_real_beat("READ_LAST_STALLED", TARGET_TINY, beat, 1'b0);
        check_condition("READ_LAST_STALLED", s_axi_arready === 1'b0,
            "stalled RLAST completed transaction");
        send_real_beat("READ_LAST_STALLED", TARGET_TINY, beat, 1'b1);
        check_idle("READ_LAST_STALLED");
        finish_case("READ_LAST_STALLED", case_ok);

        //6. Both unmapped and permission-rejected AR use the error path.
        case_ok = 1'b1;
        run_error_read("READ_DECODE_ERROR",
            '{2'd1, 32'h4000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR});
        run_error_read("READ_DECODE_ERROR",
            '{2'd0, 32'h1000_0000, 8'd0, AXI_SIZE_4B, AXI_BURST_INCR});
        finish_case("READ_DECODE_ERROR", case_ok);

        $display("SUMMARY | PASS=%0d FAIL=%0d", pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1, "axi_read_router_tb failed");
        $finish;
    end
endmodule
