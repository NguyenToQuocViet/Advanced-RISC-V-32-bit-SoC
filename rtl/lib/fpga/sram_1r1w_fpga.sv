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
// Module       : sram_1r1w_fpga
// Description  : Behavioral dual-port (1R1W) SRAM with OpenRAM-compatible interface.
//                Independent read + write ports, both synchronous.
//                Used for BTB (read in IF, write in EX, same cycle).
//                Swap with OpenRAM-generated macro for ASIC.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-27
// Version      : 1.0
// -----------------------------------------------------------------------------

module sram_1r1w_fpga #(
    parameter int ADDR_W = 10,
    parameter int DATA_W = 52,
    parameter int DEPTH  = 1024
)(
    input  logic                clk,

    //read port
    input  logic                rd_csb,     //read chip select bar (active-low)
    input  logic [ADDR_W-1:0]   rd_addr,
    output logic [DATA_W-1:0]   rd_dout,

    //write port
    input  logic                wr_csb,     //write chip select bar (active-low)
    input  logic                wr_web,     //write enable bar (active-low)
    input  logic [ADDR_W-1:0]   wr_addr,
    input  logic [DATA_W-1:0]   wr_din
);
    //storage
    logic [DATA_W-1:0] mem [DEPTH];

    //read port — sync read
    always_ff @(posedge clk) begin
        if (!rd_csb)
            rd_dout <= mem[rd_addr];
    end

    //write port — sync write
    always_ff @(posedge clk) begin
        if (!wr_csb && !wr_web)
            mem[wr_addr] <= wr_din;
    end
endmodule
