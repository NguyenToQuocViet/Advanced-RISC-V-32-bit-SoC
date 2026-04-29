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
// Module       : Load Store Unit 2 (MEM2 Stage)
// Description  : Captures D-Cache response, extracts byte/half/word by
//                address alignment, sign/zero extends. All combinational.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-29
// Version      : 1.0
// -----------------------------------------------------------------------------

module lsu2
    import cpu_pkg::*;
(
    //dcache interface
    input logic [DATA_WIDTH-1:0]    dc_rdata,
    input logic                     dc_valid,
    input logic                     dc_ready,

    //pipeline interface
    input logic [1:0]               addr_lsb,
    input logic [2:0]               mem_size,

    output logic [DATA_WIDTH-1:0]   mem_rdata,
    output logic                    mem_valid,
    output logic                    mem_ready
);
    //pass-through
    assign mem_valid = dc_valid;
    assign mem_ready = dc_ready;

    //byte extraction
    logic [7:0] byte_data;
    logic [15:0] half_data;
    
    //byte
    always_comb begin
        case (addr_lsb)
            2'b00: byte_data = dc_rdata[7:0];
            2'b01: byte_data = dc_rdata[15:8];
            2'b10: byte_data = dc_rdata[23:16];
            2'b11: byte_data = dc_rdata[31:24];
        endcase
    end

    //half word
    always_comb begin
        if (addr_lsb[1])
            half_data = dc_rdata[31:16];
        else
            half_data = dc_rdata[15:0];
    end

    //merge data for mem_rdata
    always_comb begin
        case (mem_size[2:0])
            3'b000: mem_rdata = {{24{byte_data[7]}}, byte_data};    //byte
            3'b001: mem_rdata = {{16{half_data[15]}} ,half_data};   //half word
            3'b010: mem_rdata = dc_rdata;                           //word
            3'b100: mem_rdata = {24'b0, byte_data};                 //unsinged byte
            3'b101: mem_rdata = {16'b0, half_data};                 //unsigned half word

            default: mem_rdata = dc_rdata;
        endcase
    end
endmodule
