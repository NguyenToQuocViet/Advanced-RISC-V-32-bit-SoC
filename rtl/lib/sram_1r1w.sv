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
// Module       : sram_1r1w
// Description  : Platform selector for synchronous 1R1W SRAM.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-23
// Version      : 2.0
// -----------------------------------------------------------------------------

module sram_1r1w #(
    parameter int ADDR_W = 10,
    parameter int DATA_W = 52,
    parameter int DEPTH  = 1024
)(
    input  logic              clk,
    input  logic              rd_csb,
    input  logic [ADDR_W-1:0] rd_addr,
    output logic [DATA_W-1:0] rd_dout,
    input  logic              wr_csb,
    input  logic              wr_web,
    input  logic [ADDR_W-1:0] wr_addr,
    input  logic [DATA_W-1:0] wr_din
);
`ifdef TARGET_SKY130
    sram_1r1w_sky130 #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .DEPTH  (DEPTH)
    ) u_impl (
        .clk     (clk),
        .rd_csb  (rd_csb),
        .rd_addr (rd_addr),
        .rd_dout (rd_dout),
        .wr_csb  (wr_csb),
        .wr_web  (wr_web),
        .wr_addr (wr_addr),
        .wr_din  (wr_din)
    );
`else
    sram_1r1w_fpga #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .DEPTH  (DEPTH)
    ) u_impl (
        .clk     (clk),
        .rd_csb  (rd_csb),
        .rd_addr (rd_addr),
        .rd_dout (rd_dout),
        .wr_csb  (wr_csb),
        .wr_web  (wr_web),
        .wr_addr (wr_addr),
        .wr_din  (wr_din)
    );
`endif

endmodule
