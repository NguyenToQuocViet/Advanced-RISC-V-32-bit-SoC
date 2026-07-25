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
// Module       : sram_1rw
// Description  : Platform selector for masked synchronous 1RW SRAM.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-23
// Version      : 2.0
// -----------------------------------------------------------------------------

module sram_1rw #(
    parameter int ADDR_W  = 8,
    parameter int DATA_W  = 32,
    parameter int DEPTH   = 256,
    parameter int WMASK_W = DATA_W / 8
)(
    input  logic               clk,
    input  logic               csb,
    input  logic               web,
    input  logic [WMASK_W-1:0] wmask,
    input  logic [ADDR_W-1:0]  addr,
    input  logic [DATA_W-1:0]  din,
    output logic [DATA_W-1:0]  dout
);
`ifdef TARGET_SKY130
    sram_1rw_sky130 #(
        .ADDR_W  (ADDR_W),
        .DATA_W  (DATA_W),
        .DEPTH   (DEPTH),
        .WMASK_W (WMASK_W)
    ) u_impl (
        .clk   (clk),
        .csb   (csb),
        .web   (web),
        .wmask (wmask),
        .addr  (addr),
        .din   (din),
        .dout  (dout)
    );
`else
    sram_1rw_fpga #(
        .ADDR_W  (ADDR_W),
        .DATA_W  (DATA_W),
        .DEPTH   (DEPTH),
        .WMASK_W (WMASK_W)
    ) u_impl (
        .clk   (clk),
        .csb   (csb),
        .web   (web),
        .wmask (wmask),
        .addr  (addr),
        .din   (din),
        .dout  (dout)
    );
`endif

endmodule
