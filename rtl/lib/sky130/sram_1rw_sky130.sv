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
// Module       : sram_1rw_sky130
// Description  : Sky130 hard-macro mapper for cache tag/data arrays.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-23
// Version      : 1.0
// -----------------------------------------------------------------------------

module sram_1rw_sky130 #(
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

    generate
        if ((ADDR_W == 8) && (DATA_W == 20) &&
            (DEPTH == 256) && (WMASK_W == 1)) begin : gen_ic_tag
            logic [31:0] macro_dout;
            logic        macro_csb;

            assign macro_csb = csb || (!web && !wmask[0]);
            assign dout      = macro_dout[19:0];

            sky130_sram_1kbyte_1rw1r_32x256_8 u_mem (
                .clk0   (clk),
                .csb0   (macro_csb),
                .web0   (web),
                .wmask0 (4'hf),
                .addr0  (addr),
                .din0   ({12'b0, din}),
                .dout0  (macro_dout),
                .clk1   (clk),
                .csb1   (1'b1),
                .addr1  (8'b0),
                .dout1  ()
            );
        end else if ((ADDR_W == 7) && (DATA_W == 42) &&
                     (DEPTH == 128) && (WMASK_W == 2)) begin : gen_dc_tag
            logic [7:0]  macro_addr;
            logic [31:0] way0_dout;
            logic [31:0] way1_dout;
            logic        way0_csb;
            logic        way1_csb;

            assign macro_addr = {1'b0, addr};
            assign way0_csb   = csb || (!web && !wmask[0]);
            assign way1_csb   = csb || (!web && !wmask[1]);
            assign dout       = {way1_dout[20:0], way0_dout[20:0]};

            sky130_sram_1kbyte_1rw1r_32x256_8 u_way0 (
                .clk0   (clk),
                .csb0   (way0_csb),
                .web0   (web),
                .wmask0 (4'hf),
                .addr0  (macro_addr),
                .din0   ({11'b0, din[20:0]}),
                .dout0  (way0_dout),
                .clk1   (clk),
                .csb1   (1'b1),
                .addr1  (8'b0),
                .dout1  ()
            );

            sky130_sram_1kbyte_1rw1r_32x256_8 u_way1 (
                .clk0   (clk),
                .csb0   (way1_csb),
                .web0   (web),
                .wmask0 (4'hf),
                .addr0  (macro_addr),
                .din0   ({11'b0, din[41:21]}),
                .dout0  (way1_dout),
                .clk1   (clk),
                .csb1   (1'b1),
                .addr1  (8'b0),
                .dout1  ()
            );
        end else if ((DATA_W == 128) && (WMASK_W == 4) &&
                     (((ADDR_W == 8) && (DEPTH == 256)) ||
                      ((ADDR_W == 7) && (DEPTH == 128)))) begin : gen_cache_data
            logic [7:0]   macro_addr;
            logic [127:0] macro_dout;

            assign macro_addr = {{(8-ADDR_W){1'b0}}, addr};
            assign dout       = macro_dout;

            for (genvar lane = 0; lane < 4; lane++) begin : gen_word
                logic macro_csb;

                assign macro_csb = csb || (!web && !wmask[lane]);

                sky130_sram_1kbyte_1rw1r_32x256_8 u_mem (
                    .clk0   (clk),
                    .csb0   (macro_csb),
                    .web0   (web),
                    .wmask0 (4'hf),
                    .addr0  (macro_addr),
                    .din0   (din[lane*32 +: 32]),
                    .dout0  (macro_dout[lane*32 +: 32]),
                    .clk1   (clk),
                    .csb1   (1'b1),
                    .addr1  (8'b0),
                    .dout1  ()
                );
            end
        end else begin : gen_unsupported
            sram_1rw_sky130_unsupported_configuration u_error ();
            assign dout = '0;
        end
    endgenerate

endmodule
