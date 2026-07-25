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
// Description  : Sky130 SRAM blackboxes for synthesis and models for simulation.
// -----------------------------------------------------------------------------

`ifdef SYNTHESIS
(* blackbox *)
module sky130_sram_1kbyte_1rw1r_32x256_8 (
    input  logic        clk0,
    input  logic        csb0,
    input  logic        web0,
    input  logic [3:0]  wmask0,
    input  logic [7:0]  addr0,
    input  logic [31:0] din0,
    output logic [31:0] dout0,
    input  logic        clk1,
    input  logic        csb1,
    input  logic [7:0]  addr1,
    output logic [31:0] dout1
);
endmodule

(* blackbox *)
module sky130_sram_1kbyte_1rw1r_8x1024_8 (
    input  logic       clk0,
    input  logic       csb0,
    input  logic       web0,
    input  logic       wmask0,
    input  logic [9:0] addr0,
    input  logic [7:0] din0,
    output logic [7:0] dout0,
    input  logic       clk1,
    input  logic       csb1,
    input  logic [9:0] addr1,
    output logic [7:0] dout1
);
endmodule
`else
module sky130_sram_1kbyte_1rw1r_32x256_8 (
    input  logic        clk0,
    input  logic        csb0,
    input  logic        web0,
    input  logic [3:0]  wmask0,
    input  logic [7:0]  addr0,
    input  logic [31:0] din0,
    output logic [31:0] dout0,
    input  logic        clk1,
    input  logic        csb1,
    input  logic [7:0]  addr1,
    output logic [31:0] dout1
);
    logic [31:0] mem [256];

    always_ff @(posedge clk0) begin
        if (!csb0) begin
            if (!web0) begin
                for (int lane = 0; lane < 4; lane++) begin
                    if (wmask0[lane])
                        mem[addr0][lane*8 +: 8] <= din0[lane*8 +: 8];
                end
            end else begin
                dout0 <= mem[addr0];
            end
        end
    end

    always_ff @(posedge clk1) begin
        if (!csb1)
            dout1 <= mem[addr1];
    end
endmodule

module sky130_sram_1kbyte_1rw1r_8x1024_8 (
    input  logic       clk0,
    input  logic       csb0,
    input  logic       web0,
    input  logic       wmask0,
    input  logic [9:0] addr0,
    input  logic [7:0] din0,
    output logic [7:0] dout0,
    input  logic       clk1,
    input  logic       csb1,
    input  logic [9:0] addr1,
    output logic [7:0] dout1
);
    logic [7:0] mem [1024];

    always_ff @(posedge clk0) begin
        if (!csb0) begin
            if (!web0 && wmask0)
                mem[addr0] <= din0;
            else if (web0)
                dout0 <= mem[addr0];
        end
    end

    always_ff @(posedge clk1) begin
        if (!csb1)
            dout1 <= mem[addr1];
    end
endmodule
`endif
