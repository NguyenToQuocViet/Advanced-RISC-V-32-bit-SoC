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
// Module       : riscv_pkg
// Description  : Shared parameters, types, constants for cpu core
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-03-15
// Version      : 1.0
// -----------------------------------------------------------------------------

package cpu_pkg;
    //base parameters
    localparam DATA_WIDTH   = 32; 
    localparam ADDR_WIDTH   = 32;

    //nop instr (addi x0, x0, 0) for flush
    localparam NOP_INSTR = 32'h0000_0013; 

    //pc reset vector
    localparam PC_RESET_VEC = 32'h0000_0000;
endpackage
