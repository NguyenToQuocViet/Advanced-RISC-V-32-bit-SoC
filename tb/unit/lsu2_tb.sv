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
// Module       : lsu2_tb
// Description  : Directed tests for LSU2 MEM2 response formatting.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-06-23
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module lsu2_tb;
    import cpu_pkg::*;

    //dcache input
    logic [DATA_WIDTH-1:0]    dc_rdata;
    logic                     dc_valid;
    logic                     dc_ready;

    //pipeline metadata
    logic [1:0]               addr_lsb;
    logic [2:0]               mem_size;

    //pipeline output
    logic [DATA_WIDTH-1:0]    mem_rdata;
    logic                     mem_valid;
    logic                     mem_ready;

    //DUT
    lsu2 dut (
        .dc_rdata   (dc_rdata),
        .dc_valid   (dc_valid),
        .dc_ready   (dc_ready),
        .addr_lsb   (addr_lsb),
        .mem_size   (mem_size),
        .mem_rdata  (mem_rdata),
        .mem_valid  (mem_valid),
        .mem_ready  (mem_ready)
    );

    int pass_count;
    int fail_count;

    task automatic drive_resp;
        input logic [DATA_WIDTH-1:0] t_dc_rdata;
        input logic                  t_dc_valid;
        input logic                  t_dc_ready;
        input logic [1:0]            t_addr_lsb;
        input logic [2:0]            t_mem_size;
        begin
            dc_rdata  = t_dc_rdata;
            dc_valid  = t_dc_valid;
            dc_ready  = t_dc_ready;
            addr_lsb  = t_addr_lsb;
            mem_size  = t_mem_size;
            #1;
        end
    endtask

    task automatic expect_ctrl;
        input logic  exp_valid;
        input logic  exp_ready;
        input string desc;
        begin
            if ((mem_valid === exp_valid) &&
                (mem_ready === exp_ready)) begin
                $display("PASS | %-42s valid=%0b ready=%0b", desc, mem_valid, mem_ready);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                if (mem_valid !== exp_valid) $display("       mem_valid: got=%0b exp=%0b", mem_valid, exp_valid);
                if (mem_ready !== exp_ready) $display("       mem_ready: got=%0b exp=%0b", mem_ready, exp_ready);
                fail_count++;
            end
        end
    endtask

    task automatic expect_data;
        input logic [DATA_WIDTH-1:0] exp_rdata;
        input string                 desc;
        begin
            if (mem_rdata === exp_rdata) begin
                $display("PASS | %-42s rdata=%h", desc, mem_rdata);
                pass_count++;
            end else begin
                $display("FAIL | %s", desc);
                $display("       mem_rdata: got=%h exp=%h", mem_rdata, exp_rdata);
                fail_count++;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        //dc_rdata = AABBCCDD, byte0=DD, byte1=CC, byte2=BB, byte3=AA

        //1. control pass-through
        drive_resp(32'hAABB_CCDD, 1'b1, 1'b0, 2'b00, 3'b010);
        expect_ctrl(1'b1, 1'b0, "valid ready passthrough");

        //2. LB: selected byte is sign-extended
        drive_resp(32'hAABB_CCDD, 1'b1, 1'b1, 2'b01, 3'b000);
        expect_data(32'hFFFF_FFCC, "LB byte1 sign extend");

        //3. LBU: selected byte is zero-extended
        drive_resp(32'hAABB_CCDD, 1'b1, 1'b1, 2'b10, 3'b100);
        expect_data(32'h0000_00BB, "LBU byte2 zero extend");

        //4. LH: selected half is sign-extended
        drive_resp(32'hAABB_CCDD, 1'b1, 1'b1, 2'b10, 3'b001);
        expect_data(32'hFFFF_AABB, "LH upper half sign extend");

        //5. LHU: selected half is zero-extended
        drive_resp(32'hAABB_CCDD, 1'b1, 1'b1, 2'b00, 3'b101);
        expect_data(32'h0000_CCDD, "LHU lower half zero extend");

        //6. LW: full word passthrough
        drive_resp(32'hDEAD_BEEF, 1'b1, 1'b1, 2'b11, 3'b010);
        expect_data(32'hDEAD_BEEF, "LW word passthrough");

        $display("--------------------------------------------");
        $display("LSU2_TB SUMMARY: PASS=%0d FAIL=%0d", pass_count, fail_count);
        $display("--------------------------------------------");

        if (fail_count == 0)
            $display("LSU2_TB PASS");
        else
            $display("LSU2_TB FAIL");

        $finish;
    end
endmodule
