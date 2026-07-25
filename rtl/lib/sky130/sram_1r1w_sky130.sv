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
// Module       : sram_1r1w_sky130
// Description  : Seven-bank Sky130 BTB SRAM mapper for 52-bit entries.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-23
// Version      : 1.0
// -----------------------------------------------------------------------------

module sram_1r1w_sky130 #(
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

    generate
        if ((ADDR_W == 10) && (DATA_W == 52) && (DEPTH == 1024)) begin : gen_btb
            logic [55:0] rd_data;
            logic [55:0] wr_data;

            assign wr_data = {4'b0, wr_din};
            assign rd_dout = rd_data[51:0];

            for (genvar lane = 0; lane < 7; lane++) begin : gen_byte
                sky130_sram_1kbyte_1rw1r_8x1024_8 u_mem (
                    .clk0   (clk),
                    .csb0   (wr_csb),
                    .web0   (wr_web),
                    .wmask0 (1'b1),
                    .addr0  (wr_addr),
                    .din0   (wr_data[lane*8 +: 8]),
                    .dout0  (),
                    .clk1   (clk),
                    .csb1   (rd_csb),
                    .addr1  (rd_addr),
                    .dout1  (rd_data[lane*8 +: 8])
                );
            end
        end else begin : gen_unsupported
            sram_1r1w_sky130_unsupported_configuration u_error ();
            assign rd_dout = '0;
        end
    endgenerate

endmodule
