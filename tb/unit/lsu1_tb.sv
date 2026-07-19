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
// Module       : lsu1_tb
// Description  : Directed tests for LSU1 MEM1 request formatting.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-23
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module lsu1_tb;
    import cpu_pkg::*;
    import cache_pkg::STRB_WIDTH;

    //pipeline input
    logic                     mem_req;
    logic                     mem_we;
    logic [2:0]               mem_size;
    logic [DATA_WIDTH-1:0]    addr;
    logic [DATA_WIDTH-1:0]    wdata;

    //dcache output
    logic [ADDR_WIDTH-1:0]    dc_addr;
    logic                     dc_req;
    logic                     dc_we;
    logic [DATA_WIDTH-1:0]    dc_wdata;
    logic [STRB_WIDTH-1:0]    dc_wstrb;

    //pipeline metadata
    logic [1:0]               addr_lsb;
    logic [2:0]               mem_size_o;

    //DUT
    lsu1 dut (
        .mem_req      (mem_req),
        .mem_we       (mem_we),
        .mem_size     (mem_size),
        .addr         (addr),
        .wdata        (wdata),
        .dc_addr      (dc_addr),
        .dc_req       (dc_req),
        .dc_we        (dc_we),
        .dc_wdata     (dc_wdata),
        .dc_wstrb     (dc_wstrb),
        .addr_lsb     (addr_lsb),
        .mem_size_o   (mem_size_o)
    );

    int pass_count;
    int fail_count;

    task automatic drive_req;
        input logic                  t_mem_req;
        input logic                  t_mem_we;
        input logic [2:0]            t_mem_size;
        input logic [ADDR_WIDTH-1:0] t_addr;
        input logic [DATA_WIDTH-1:0] t_wdata;
        begin
            mem_req  = t_mem_req;
            mem_we   = t_mem_we;
            mem_size = t_mem_size;
            addr     = t_addr;
            wdata    = t_wdata;
            #1;
        end
    endtask

    task automatic expect_req;
        input logic [ADDR_WIDTH-1:0] exp_addr;
        input logic                  exp_req;
        input logic                  exp_we;
        input logic [1:0]            exp_addr_lsb;
        input logic [2:0]            exp_mem_size;
        input string                 desc;
        begin
            if ((dc_addr === exp_addr) &&
                (dc_req === exp_req) &&
                (dc_we === exp_we) &&
                (addr_lsb === exp_addr_lsb) &&
                (mem_size_o === exp_mem_size)) begin
                $display("PASS | %-42s addr=%h req=%0b we=%0b", desc, dc_addr, dc_req, dc_we);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (dc_addr !== exp_addr)       $display("       dc_addr   : got=%h exp=%h", dc_addr, exp_addr);
                if (dc_req !== exp_req)         $display("       dc_req    : got=%0b exp=%0b", dc_req, exp_req);
                if (dc_we !== exp_we)           $display("       dc_we     : got=%0b exp=%0b", dc_we, exp_we);
                if (addr_lsb !== exp_addr_lsb)  $display("       addr_lsb  : got=%0b exp=%0b", addr_lsb, exp_addr_lsb);
                if (mem_size_o !== exp_mem_size)$display("       mem_size_o: got=%0b exp=%0b", mem_size_o, exp_mem_size);
                fail_count++;
            end
        end
    endtask

    task automatic expect_store;
        input logic [STRB_WIDTH-1:0] exp_wstrb;
        input logic [DATA_WIDTH-1:0] exp_wdata;
        input string                 desc;
        begin
            if ((dc_wstrb === exp_wstrb) &&
                (dc_wdata === exp_wdata)) begin
                $display("PASS | %-42s wstrb=%04b wdata=%h", desc, dc_wstrb, dc_wdata);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (dc_wstrb !== exp_wstrb) $display("       dc_wstrb: got=%04b exp=%04b", dc_wstrb, exp_wstrb);
                if (dc_wdata !== exp_wdata) $display("       dc_wdata: got=%h exp=%h", dc_wdata, exp_wdata);
                fail_count++;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        //1. pass-through request and metadata
        drive_req(1'b1, 1'b0, 3'b010, 32'h0000_1003, 32'hDEAD_BEEF);
        expect_req(32'h0000_1003, 1'b1, 1'b0, 2'b11, 3'b010, "load request passthrough");

        //2. byte store: low byte replicated, address selects lane
        drive_req(1'b1, 1'b1, 3'b000, 32'h0000_2002, 32'hABCD_1234);
        expect_req(32'h0000_2002, 1'b1, 1'b1, 2'b10, 3'b000, "store byte request passthrough");
        expect_store(4'b0100, 32'h3434_3434, "SB addr[1:0]=10");

        //3. half store: low half replicated, addr[1] selects half lane
        drive_req(1'b1, 1'b1, 3'b001, 32'h0000_3002, 32'hABCD_1234);
        expect_store(4'b1100, 32'h1234_1234, "SH addr[1]=1");

        //4. word store: full strobe, data passthrough
        drive_req(1'b1, 1'b1, 3'b010, 32'h0000_4000, 32'hDEAD_BEEF);
        expect_store(4'b1111, 32'hDEAD_BEEF, "SW full word");

        //5. no request still passes control as-is
        drive_req(1'b0, 1'b0, 3'b000, 32'h0000_5001, 32'h0000_00AA);
        expect_req(32'h0000_5001, 1'b0, 1'b0, 2'b01, 3'b000, "idle request passthrough");

        $display("--------------------------------------------");
        $display("LSU1_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------");

        if (fail_count == 0)
            $display("LSU1_TB PASS");
        else
            $display("LSU1_TB FAIL");

        $finish;
    end
endmodule
