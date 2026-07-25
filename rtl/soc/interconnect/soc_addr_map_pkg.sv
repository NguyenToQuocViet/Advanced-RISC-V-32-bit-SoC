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
// Module       : soc_addr_map_pkg
// Description  : SoC address map and PMA region descriptors
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-25
// Version      : 1.0
// -----------------------------------------------------------------------------

package soc_addr_map_pkg;
    localparam SOC_ADDR_WIDTH   = 32;
    localparam SOC_NUM_SLAVES   = 4;
    localparam SOC_NUM_REGIONS  = 4;
    localparam SOC_TARGET_WIDTH = 2;

    typedef enum logic [SOC_TARGET_WIDTH-1:0] {
        TARGET_MEM     = 2'd0,
        TARGET_TINY    = 2'd1,
        TARGET_ASCON   = 2'd2,
        TARGET_APB     = 2'd3
    } soc_target_t;

    typedef struct packed {
        logic [SOC_ADDR_WIDTH-1:0] base;
        logic [SOC_ADDR_WIDTH-1:0] mask;
        soc_target_t target;
        logic readable;
        logic writable;
        logic executable;
        logic cacheable;
        logic device;
        logic allow_burst;
    } soc_region_desc_t;

    localparam soc_region_desc_t SOC_REGION_TABLE [SOC_NUM_REGIONS] = '{
        '{base: 32'h0000_0000,
        mask: 32'hFFF0_0000,
        target: TARGET_MEM,
        readable: 1'b1,
        writable: 1'b1,
        executable: 1'b1,
        cacheable: 1'b1,
        device: 1'b0,
        allow_burst: 1'b1
        },

        '{base: 32'h1000_0000,
        mask: 32'hFFFF_FF00,
        target: TARGET_TINY,
        readable: 1'b1,
        writable: 1'b1,
        executable: 1'b0,
        cacheable: 1'b0,
        device: 1'b1,
        allow_burst: 1'b0
        },

        '{base: 32'h2000_0000,
        mask: 32'hFFFF_FF00,
        target: TARGET_ASCON,
        readable: 1'b1,
        writable: 1'b1,
        executable: 1'b0,
        cacheable: 1'b0,
        device: 1'b1,
        allow_burst: 1'b0
        },

        '{base: 32'h3000_0000,
        mask: 32'hFFFF_0000,
        target: TARGET_APB,
        readable: 1'b1,
        writable: 1'b1,
        executable: 1'b0,
        cacheable: 1'b0,
        device: 1'b1,
        allow_burst: 1'b0
        }
    };
endpackage
