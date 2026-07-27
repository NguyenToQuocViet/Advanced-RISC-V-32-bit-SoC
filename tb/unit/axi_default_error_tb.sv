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
// Module       : axi_default_error_tb
// Description  : Directed unit testbench for the AXI default error responder
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-27
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module axi_default_error_tb;
    localparam ID_WIDTH   = 2;
    localparam DATA_WIDTH = 32;

    localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

    //system
    logic clk;
    logic rst_n;

    //read request
    logic                    rd_req_valid;
    logic                    rd_req_ready;
    logic [ID_WIDTH-1:0]     rd_req_id;
    logic [7:0]              rd_req_len;

    //read response
    logic                    rd_resp_valid;
    logic                    rd_resp_ready;
    logic [ID_WIDTH-1:0]     rd_resp_id;
    logic [DATA_WIDTH-1:0]   rd_resp_data;
    logic [1:0]              rd_resp_resp;
    logic                    rd_resp_last;

    //write request
    logic                    wr_req_valid;
    logic                    wr_req_ready;
    logic [ID_WIDTH-1:0]     wr_req_id;
    logic [7:0]              wr_req_len;

    //write data
    logic                    wr_data_valid;
    logic                    wr_data_ready;
    logic                    wr_data_last;

    //write response
    logic                    wr_resp_valid;
    logic                    wr_resp_ready;
    logic [ID_WIDTH-1:0]     wr_resp_id;
    logic [1:0]              wr_resp_resp;

    int pass_count;
    int fail_count;

    axi_default_error #(
        .ID_WIDTH   (ID_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .rd_req_valid  (rd_req_valid),
        .rd_req_ready  (rd_req_ready),
        .rd_req_id     (rd_req_id),
        .rd_req_len    (rd_req_len),
        .rd_resp_valid (rd_resp_valid),
        .rd_resp_ready (rd_resp_ready),
        .rd_resp_id    (rd_resp_id),
        .rd_resp_data  (rd_resp_data),
        .rd_resp_resp  (rd_resp_resp),
        .rd_resp_last  (rd_resp_last),
        .wr_req_valid  (wr_req_valid),
        .wr_req_ready  (wr_req_ready),
        .wr_req_id     (wr_req_id),
        .wr_req_len    (wr_req_len),
        .wr_data_valid (wr_data_valid),
        .wr_data_ready (wr_data_ready),
        .wr_data_last  (wr_data_last),
        .wr_resp_valid (wr_resp_valid),
        .wr_resp_ready (wr_resp_ready),
        .wr_resp_id    (wr_resp_id),
        .wr_resp_resp  (wr_resp_resp)
    );

    //clock: 10 ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic drive_idle;
        begin
            rd_req_valid  = 1'b0;
            rd_req_id     = '0;
            rd_req_len    = '0;
            rd_resp_ready = 1'b0;
            wr_req_valid  = 1'b0;
            wr_req_id     = '0;
            wr_req_len    = '0;
            wr_data_valid = 1'b0;
            wr_data_last  = 1'b0;
            wr_resp_ready = 1'b0;
        end
    endtask

    task automatic reset_dut;
        begin
            drive_idle();
            rst_n = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            rst_n = 1'b1;
        end
    endtask

    task automatic flag_failure(
        input string test_name,
        input string detail,
        inout bit   case_ok
    );
        begin
            if (case_ok)
                $display("FAIL | %s | %s", test_name, detail);
            else
                $display("     | %s", detail);
            case_ok = 1'b0;
        end
    endtask

    task automatic finish_case(
        input string               test_name,
        input logic [ID_WIDTH-1:0] test_id,
        input logic [7:0]          test_len,
        input int                  expected_beats,
        input bit                  case_ok
    );
        begin
            if (case_ok) begin
                pass_count++;
                $display(
                    "PASS | %-24s | id=%0d len=%0d beats=%0d",
                    test_name,
                    test_id,
                    test_len,
                    expected_beats
                );
            end else begin
                fail_count++;
            end
        end
    endtask

    task automatic run_read_case(
        input string               test_name,
        input logic [ID_WIDTH-1:0] test_id,
        input logic [7:0]          test_len,
        input bit                  inject_stall
    );
        int                        expected_beats;
        int                        accepted_beats;
        int                        stall_cycles;
        bit                        case_ok;
        bit                        hold_valid;
        logic [ID_WIDTH-1:0]       held_id;
        logic [DATA_WIDTH-1:0]     held_data;
        logic [1:0]                held_resp;
        logic                      held_last;
        logic                      ready_this_cycle;
        logic                      expected_last;
        begin
            expected_beats = int'(test_len) + 1;
            accepted_beats = 0;
            stall_cycles   = 0;
            case_ok        = 1'b1;
            hold_valid     = 1'b0;

            @(negedge clk);
            rd_req_valid = 1'b1;
            rd_req_id    = test_id;
            rd_req_len   = test_len;
            #1;
            if (rd_req_ready !== 1'b1)
                flag_failure(test_name, "read request was not accepted from IDLE", case_ok);

            @(posedge clk);
            #1;
            rd_req_valid = 1'b0;

            while (accepted_beats < expected_beats) begin
                @(negedge clk);

                ready_this_cycle = 1'b1;
                if (inject_stall && (accepted_beats == 1) && (stall_cycles < 2)) begin
                    ready_this_cycle = 1'b0;
                    stall_cycles++;
                end
                rd_resp_ready = ready_this_cycle;

                //Present a second request while busy to prove it is not accepted.
                if (inject_stall && (accepted_beats == 1) && (stall_cycles == 1)) begin
                    rd_req_valid = 1'b1;
                    rd_req_id    = ~test_id;
                    rd_req_len   = 8'd0;
                end else begin
                    rd_req_valid = 1'b0;
                end

                #1;
                expected_last = (accepted_beats == (expected_beats - 1));

                if (rd_req_ready !== 1'b0)
                    flag_failure(test_name, "rd_req_ready asserted while response active", case_ok);
                if (rd_resp_valid !== 1'b1)
                    flag_failure(test_name, $sformatf("RVALID low at beat %0d", accepted_beats), case_ok);
                if (rd_resp_id !== test_id)
                    flag_failure(test_name, $sformatf("RID=%0d expected=%0d", rd_resp_id, test_id), case_ok);
                if (rd_resp_data !== '0)
                    flag_failure(test_name, $sformatf("RDATA=%08h expected=00000000", rd_resp_data), case_ok);
                if (rd_resp_resp !== AXI_RESP_DECERR)
                    flag_failure(test_name, $sformatf("RRESP=%02b expected=11", rd_resp_resp), case_ok);
                if (rd_resp_last !== expected_last)
                    flag_failure(
                        test_name,
                        $sformatf("RLAST=%0b expected=%0b at beat %0d", rd_resp_last, expected_last, accepted_beats),
                        case_ok
                    );

                if (!ready_this_cycle) begin
                    if (!hold_valid) begin
                        held_id    = rd_resp_id;
                        held_data  = rd_resp_data;
                        held_resp  = rd_resp_resp;
                        held_last  = rd_resp_last;
                        hold_valid = 1'b1;
                    end else if ({rd_resp_id, rd_resp_data, rd_resp_resp, rd_resp_last}
                              !== {held_id, held_data, held_resp, held_last}) begin
                        flag_failure(test_name, "read payload changed while RREADY was low", case_ok);
                    end
                end else begin
                    hold_valid = 1'b0;
                    accepted_beats++;
                end

                @(posedge clk);
                #1;
            end

            @(negedge clk);
            rd_req_valid  = 1'b0;
            rd_resp_ready = 1'b0;
            #1;
            if (rd_resp_valid !== 1'b0)
                flag_failure(test_name, "RVALID remained asserted after final beat", case_ok);
            if (rd_req_ready !== 1'b1)
                flag_failure(test_name, "read path did not return to IDLE", case_ok);

            finish_case(test_name, test_id, test_len, expected_beats, case_ok);
        end
    endtask

    task automatic run_write_case(
        input string               test_name,
        input logic [ID_WIDTH-1:0] test_id,
        input logic [7:0]          test_len,
        input bit                  inject_stall
    );
        int                    expected_beats;
        int                    accepted_beats;
        int                    gap_cycles;
        int                    response_stalls;
        bit                    case_ok;
        bit                    hold_valid;
        logic [ID_WIDTH-1:0]   held_id;
        logic [1:0]            held_resp;
        begin
            expected_beats = int'(test_len) + 1;
            accepted_beats = 0;
            gap_cycles     = 0;
            case_ok        = 1'b1;
            hold_valid     = 1'b0;

            @(negedge clk);
            wr_req_valid = 1'b1;
            wr_req_id    = test_id;
            wr_req_len   = test_len;
            #1;
            if (wr_req_ready !== 1'b1)
                flag_failure(test_name, "write request was not accepted from IDLE", case_ok);

            @(posedge clk);
            #1;
            wr_req_valid = 1'b0;

            while (accepted_beats < expected_beats) begin
                if (inject_stall && (accepted_beats == 1) && (gap_cycles < 2)) begin
                    @(negedge clk);
                    wr_data_valid = 1'b0;
                    wr_data_last  = 1'b0;

                    //Present a second request while busy to prove it is not accepted.
                    if (gap_cycles == 0) begin
                        wr_req_valid = 1'b1;
                        wr_req_id    = ~test_id;
                        wr_req_len   = 8'd0;
                    end else begin
                        wr_req_valid = 1'b0;
                    end

                    #1;
                    if (wr_req_ready !== 1'b0)
                        flag_failure(test_name, "wr_req_ready asserted while write data active", case_ok);
                    if (wr_data_ready !== 1'b1)
                        flag_failure(test_name, "WREADY low while draining rejected write", case_ok);
                    if (wr_resp_valid !== 1'b0)
                        flag_failure(test_name, "BVALID asserted before final W beat", case_ok);

                    gap_cycles++;
                    @(posedge clk);
                    #1;
                end else begin
                    @(negedge clk);
                    wr_req_valid  = 1'b0;
                    wr_data_valid = 1'b1;
                    wr_data_last  = (accepted_beats == (expected_beats - 1));
                    #1;

                    if (wr_req_ready !== 1'b0)
                        flag_failure(test_name, "wr_req_ready asserted while write data active", case_ok);
                    if (wr_data_ready !== 1'b1)
                        flag_failure(test_name, $sformatf("WREADY low at beat %0d", accepted_beats), case_ok);
                    if (wr_resp_valid !== 1'b0)
                        flag_failure(test_name, "BVALID asserted before final W beat", case_ok);

                    accepted_beats++;
                    @(posedge clk);
                    #1;
                    wr_data_valid = 1'b0;
                    wr_data_last  = 1'b0;
                end
            end

            response_stalls = inject_stall ? 2 : 0;
            repeat (response_stalls) begin
                @(negedge clk);
                wr_resp_ready = 1'b0;
                #1;
                if (wr_resp_valid !== 1'b1)
                    flag_failure(test_name, "BVALID low while response stalled", case_ok);
                if (wr_resp_id !== test_id)
                    flag_failure(test_name, $sformatf("BID=%0d expected=%0d", wr_resp_id, test_id), case_ok);
                if (wr_resp_resp !== AXI_RESP_DECERR)
                    flag_failure(test_name, $sformatf("BRESP=%02b expected=11", wr_resp_resp), case_ok);

                if (!hold_valid) begin
                    held_id    = wr_resp_id;
                    held_resp  = wr_resp_resp;
                    hold_valid = 1'b1;
                end else if ({wr_resp_id, wr_resp_resp} !== {held_id, held_resp}) begin
                    flag_failure(test_name, "write response changed while BREADY was low", case_ok);
                end

                @(posedge clk);
                #1;
            end

            @(negedge clk);
            wr_resp_ready = 1'b1;
            #1;
            if (wr_resp_valid !== 1'b1)
                flag_failure(test_name, "BVALID low before response handshake", case_ok);
            if (wr_resp_id !== test_id)
                flag_failure(test_name, $sformatf("BID=%0d expected=%0d", wr_resp_id, test_id), case_ok);
            if (wr_resp_resp !== AXI_RESP_DECERR)
                flag_failure(test_name, $sformatf("BRESP=%02b expected=11", wr_resp_resp), case_ok);

            @(posedge clk);
            #1;
            wr_resp_ready = 1'b0;

            @(negedge clk);
            #1;
            if (wr_resp_valid !== 1'b0)
                flag_failure(test_name, "BVALID remained asserted after response handshake", case_ok);
            if (wr_req_ready !== 1'b1)
                flag_failure(test_name, "write path did not return to IDLE", case_ok);

            finish_case(test_name, test_id, test_len, expected_beats, case_ok);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst_n      = 1'b1;

        reset_dut();

        run_read_case("READ-SINGLE",         2'd0, 8'd0,   1'b0);
        run_read_case("READ-BURST-2",        2'd1, 8'd1,   1'b1);
        run_read_case("READ-BURST-BOUNDARY", 2'd2, 8'hFF,  1'b0);

        run_write_case("WRITE-SINGLE",         2'd2, 8'd0,  1'b0);
        run_write_case("WRITE-BURST-2",        2'd3, 8'd1,  1'b1);
        run_write_case("WRITE-BURST-BOUNDARY", 2'd1, 8'hFF, 1'b0);

        $display("SUMMARY | PASS=%0d FAIL=%0d", pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1, "axi_default_error_tb failed");
        $finish;
    end

endmodule
