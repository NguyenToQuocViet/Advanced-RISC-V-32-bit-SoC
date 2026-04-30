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
// Module       : MEM1/MEM2 Pipeline Register
// Description  : MEM1-to-MEM2 pipeline register. Carries ALU result for
//                forwarding (MEM2 source), LSU control for MEM2, and
//                writeback signals. Never flushed by hazard logic.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-29
// Version      : 1.0
// -----------------------------------------------------------------------------

module mem1_mem2_pipeline
    import cpu_pkg::*;
(
    //system interface
    input logic clk, rst_n,

    //hazard control
    input logic     stall,
    input logic     flush,

    //mem1 interface (from ex_mem1_pipeline output)
    input logic [DATA_WIDTH-1:0]    alu_result_i,   //alu result for forwarding
    input logic [DATA_WIDTH-1:0]    rdata2_i,       //store data
    input logic [ADDR_WIDTH-1:0]    pc_i,           //for pc+4 at WB (JAL/JALR)

    input logic                     mem_req_i,
    input logic                     mem_we_i,
    input logic [2:0]               mem_size_i,
    input logic [1:0]               addr_lsb_i,     //from lsu1 (addr[1:0])

    input logic                     reg_we_i,
    input logic [1:0]               wb_sel_i,
    input logic [4:0]               rd_i,

    //mem2 interface (to lsu2, fu, wb)
    output logic [DATA_WIDTH-1:0]   alu_result_o,
    output logic [DATA_WIDTH-1:0]   rdata2_o,
    output logic [ADDR_WIDTH-1:0]   pc_o,

    output logic                    mem_req_o,
    output logic                    mem_we_o,
    output logic [2:0]              mem_size_o,
    output logic [1:0]              addr_lsb_o,

    output logic                    reg_we_o,
    output logic [1:0]              wb_sel_o,
    output logic [4:0]              rd_o
);
    //pipeline registers
    logic [DATA_WIDTH-1:0]  alu_result;
    logic [DATA_WIDTH-1:0]  rdata2;
    logic [ADDR_WIDTH-1:0]  pc;

    logic                   mem_req;
    logic                   mem_we;
    logic [2:0]             mem_size;
    logic [1:0]             addr_lsb;

    logic                   reg_we;
    logic [1:0]             wb_sel;
    logic [4:0]             rd;

    //update pipeline register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result  <= '0;
            rdata2      <= '0;
            pc          <= '0;
            mem_req     <= 1'b0;
            mem_we      <= 1'b0;
            mem_size    <= '0;
            addr_lsb    <= '0;
            reg_we      <= 1'b0;
            wb_sel      <= '0;
            rd          <= '0;
        end else begin
            if (flush) begin
                alu_result  <= '0;
                rdata2      <= '0;
                pc          <= '0;
                mem_req     <= 1'b0;
                mem_we      <= 1'b0;
                mem_size    <= '0;
                addr_lsb    <= '0;
                reg_we      <= 1'b0;
                wb_sel      <= '0;
                rd          <= '0;
            end else if (stall) begin
                alu_result  <= alu_result;
                rdata2      <= rdata2;
                pc          <= pc;
                mem_req     <= mem_req;
                mem_we      <= mem_we;
                mem_size    <= mem_size;
                addr_lsb    <= addr_lsb;
                reg_we      <= reg_we;
                wb_sel      <= wb_sel;
                rd          <= rd;
            end else begin
                alu_result  <= alu_result_i;
                rdata2      <= rdata2_i;
                pc          <= pc_i;
                mem_req     <= mem_req_i;
                mem_we      <= mem_we_i;
                mem_size    <= mem_size_i;
                addr_lsb    <= addr_lsb_i;
                reg_we      <= reg_we_i;
                wb_sel      <= wb_sel_i;
                rd          <= rd_i;
            end
        end
    end
 
    assign alu_result_o = alu_result;
    assign rdata2_o     = rdata2;
    assign pc_o         = pc;
    assign mem_req_o    = mem_req;
    assign mem_we_o     = mem_we;
    assign mem_size_o   = mem_size;
    assign addr_lsb_o   = addr_lsb;
    assign reg_we_o     = reg_we;
    assign wb_sel_o     = wb_sel;
    assign rd_o         = rd;
endmodule
