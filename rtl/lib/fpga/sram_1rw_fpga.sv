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
// Module       : sram_1rw_fpga
// Description  : Behavioral single-port SRAM with OpenRAM-compatible interface.
//                Sync read (dout 1 cycle after addr), sync write (csb=0, web=0).
//                Swap with OpenRAM-generated macro for ASIC.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-27
// Version      : 1.0
// -----------------------------------------------------------------------------

module sram_1rw_fpga #(
    parameter int ADDR_W  = 8,
    parameter int DATA_W  = 32,
    parameter int DEPTH   = 256,
    parameter int WMASK_W = DATA_W / 8   //byte-lane write mask
)(
    input  logic                clk,
    input  logic                csb,        //chip select bar (active-low)
    input  logic                web,        //write enable bar (active-low)
    input  logic [WMASK_W-1:0]  wmask,      //write mask (1=write, 0=keep)
    input  logic [ADDR_W-1:0]   addr,
    input  logic [DATA_W-1:0]   din,
    output logic [DATA_W-1:0]   dout
);
    localparam int BYTE_W = DATA_W / WMASK_W;

    //storage
    logic [DATA_W-1:0] mem [DEPTH];

    //sync read + sync write
    always_ff @(posedge clk) begin
        if (!csb) begin
            if (!web) begin
                //write with byte-lane mask
                for (int i = 0; i < WMASK_W; i++) begin
                    if (wmask[i])
                        mem[addr][i*BYTE_W +: BYTE_W] <= din[i*BYTE_W +: BYTE_W];
                end
            end
            //read (also on write cycle — read-before-write)
            dout <= mem[addr];
        end
    end
endmodule
