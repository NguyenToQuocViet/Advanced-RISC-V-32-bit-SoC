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
// Module       : sram_256x64_1rw
// Description  : 256x64 synchronous single-port SRAM wrapper.
//                Selects ASAP7 macro or generic FPGA inference backend.
//                Supports full-word writes only.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-16
// Version      : 1.0
// -----------------------------------------------------------------------------

module sram_256x64_1rw (
    input  logic        clk,
    input  logic        en,
    input  logic        we,
    input  logic [7:0]  addr,
    input  logic [63:0] wdata,
    output logic [63:0] rdata
);

`ifdef ASAP7_SRAM
    srambank_64x4x64_6t122 u_sram (
        .clk     (clk),
        .ADDRESS (addr),
        .wd      (wdata),
        .banksel (en),
        .read    (en && !we),
        .write   (en && we),
        .dataout (rdata)
    );
`else

    logic [63:0] mem [0:255];

    //sync 1RW, full-word write
    always_ff @(posedge clk) begin
        if (en) begin
            if (we)
                mem[addr] <= wdata;
            else
                rdata <= mem[addr];
        end
    end
`endif
endmodule
