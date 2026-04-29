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
// Module       : Load Store Unit 1 (MEM1 Stage)
// Description  : Translates pipeline mem request to D-Cache interface.
//                Launches address + generates wstrb/wdata for stores.
//                All combinational, no registers.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-29
// Version      : 1.0
// -----------------------------------------------------------------------------

module lsu1
    import cpu_pkg::*;
(
    //pipeline reg interface
    input logic                     mem_req,
    input logic                     mem_we,
    input logic [2:0]               mem_size,

    input logic [DATA_WIDTH-1:0]    addr,
    input logic [DATA_WIDTH-1:0]    wdata,

    //dcache interface
    output logic [ADDR_WIDTH-1:0]   dc_addr,
    output logic                    dc_req,
    output logic                    dc_we,
    output logic [DATA_WIDTH-1:0]   dc_wdata,
    output logic [STRB_WIDTH-1:0]   dc_wstrb,

    //passthrough to lsu2 (pipeline reg)
    output logic [1:0]              addr_lsb,
    output logic [2:0]              mem_size_o
);
    //pass-through
    assign dc_addr      = addr;
    assign dc_req       = mem_req;
    assign dc_we        = mem_we;

    assign addr_lsb     = addr[1:0];
    assign mem_size_o   = mem_size;
    
    //mask strobe for write
    always_comb begin
        case (mem_size)
            //byte
            2'b00: begin
                case (addr[1:0])
                    2'b00:  dc_wstrb = 4'b0001;
                    2'b01:  dc_wstrb = 4'b0010;
                    2'b10:  dc_wstrb = 4'b0100;
                    2'b11:  dc_wstrb = 4'b1000;
                endcase
            end

            //half-word
            2'b01: begin
                if (addr[1])
                    dc_wstrb = 4'b1100;
                else
                    dc_wstrb = 4'b0011;
            end

            //word
            2'b10: begin
                dc_wstrb = 4'b1111;    
            end

            default: dc_wstrb= 4'b1111;
        endcase
    end

    //byte replicate for wdata
    always_comb begin
        case (mem_size)
            //byte
            2'b00: dc_wdata    = {4{wdata[7:0]}};

            //half-word
            2'b01: dc_wdata    = {2{wdata[15:0]}};

            //word
            2'b10: dc_wdata = wdata;

            default: dc_wdata    = wdata;
        endcase
    end
endmodule
