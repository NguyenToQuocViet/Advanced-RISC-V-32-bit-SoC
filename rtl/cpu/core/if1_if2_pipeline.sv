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
// Module       : IF1/IF2 Pipeline Register
// Description  : Holds PC while I-Cache SRAM read completes.
//                IF1: PC gen + SRAM addr launch.
//                IF2: SRAM data arrives -> tag compare -> hit/miss.
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-04-27
// Version      : 1.0
// -----------------------------------------------------------------------------

module if1_if2_pipeline
    import cpu_pkg::*;
(
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic                    stall,
    input  logic                    flush,

    //IF1 inputs
    input  logic [ADDR_WIDTH-1:0]   if1_pc_i,
    input  logic                    if1_valid_i,

    //IF2 outputs
    output logic [ADDR_WIDTH-1:0]   if2_pc_o,
    output logic                    if2_valid_o
);
    logic [ADDR_WIDTH-1:0]  pc;
    logic                   valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc        <= '0;
            valid     <= 1'b0;
        end else begin
            if (flush) begin
                pc        <= '0;
                valid     <= 1'b0;
            end else if (!stall) begin
                pc        <= if1_pc_i;
                valid     <= if1_valid_i;
            end
        end
    end

    assign if2_pc_o         = pc;
    assign if2_valid_o      = valid;
endmodule
