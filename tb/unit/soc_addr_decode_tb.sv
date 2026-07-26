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
// Module       : soc_addr_decode_tb
// Description  : Directed testbench for SoC address and access decoder
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-26
// Version      : 1.0
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module soc_addr_decode_tb;
    import soc_addr_map_pkg::*;
    import axi_pkg::*;

    typedef struct packed {
        logic [SOC_ADDR_WIDTH-1:0] addr;
        logic                      is_write;
        logic                      is_fetch;
        logic [7:0]                burst_len;
        logic [2:0]                burst_size;
        logic [1:0]                burst_type;
    } input_desc_t;

    typedef struct packed {
        logic        hit;
        soc_target_t target;
        logic        readable;
        logic        writable;
        logic        executable;
        logic        cacheable;
        logic        device;
        logic        allow_burst;
        logic        access_ok;
        logic        decode_error;
    } output_desc_t;

    localparam output_desc_t MEM_PASS = '{
        hit: 1'b1, target: TARGET_MEM,
        readable: 1'b1, writable: 1'b1, executable: 1'b1,
        cacheable: 1'b1, device: 1'b0, allow_burst: 1'b1,
        access_ok: 1'b1, decode_error: 1'b0
    };
    localparam output_desc_t MEM_REJECT = '{
        hit: 1'b1, target: TARGET_MEM,
        readable: 1'b1, writable: 1'b1, executable: 1'b1,
        cacheable: 1'b1, device: 1'b0, allow_burst: 1'b1,
        access_ok: 1'b0, decode_error: 1'b1
    };
    localparam output_desc_t TINY_PASS = '{
        hit: 1'b1, target: TARGET_TINY,
        readable: 1'b1, writable: 1'b1, executable: 1'b0,
        cacheable: 1'b0, device: 1'b1, allow_burst: 1'b0,
        access_ok: 1'b1, decode_error: 1'b0
    };
    localparam output_desc_t TINY_REJECT = '{
        hit: 1'b1, target: TARGET_TINY,
        readable: 1'b1, writable: 1'b1, executable: 1'b0,
        cacheable: 1'b0, device: 1'b1, allow_burst: 1'b0,
        access_ok: 1'b0, decode_error: 1'b1
    };
    localparam output_desc_t ASCON_PASS = '{
        hit: 1'b1, target: TARGET_ASCON,
        readable: 1'b1, writable: 1'b1, executable: 1'b0,
        cacheable: 1'b0, device: 1'b1, allow_burst: 1'b0,
        access_ok: 1'b1, decode_error: 1'b0
    };
    localparam output_desc_t ASCON_REJECT = '{
        hit: 1'b1, target: TARGET_ASCON,
        readable: 1'b1, writable: 1'b1, executable: 1'b0,
        cacheable: 1'b0, device: 1'b1, allow_burst: 1'b0,
        access_ok: 1'b0, decode_error: 1'b1
    };
    localparam output_desc_t APB_PASS = '{
        hit: 1'b1, target: TARGET_APB,
        readable: 1'b1, writable: 1'b1, executable: 1'b0,
        cacheable: 1'b0, device: 1'b1, allow_burst: 1'b0,
        access_ok: 1'b1, decode_error: 1'b0
    };
    localparam output_desc_t APB_REJECT = '{
        hit: 1'b1, target: TARGET_APB,
        readable: 1'b1, writable: 1'b1, executable: 1'b0,
        cacheable: 1'b0, device: 1'b1, allow_burst: 1'b0,
        access_ok: 1'b0, decode_error: 1'b1
    };
    localparam output_desc_t NO_HIT = '{
        hit: 1'b0, target: TARGET_MEM,
        readable: 1'b0, writable: 1'b0, executable: 1'b0,
        cacheable: 1'b0, device: 1'b0, allow_burst: 1'b0,
        access_ok: 1'b0, decode_error: 1'b1
    };

    //test transaction
    input_desc_t  input_desc;
    output_desc_t output_desc;
    output_desc_t expected_desc;
    int           pass_count;
    int           fail_count;

    //dut
    soc_addr_decode dut (
        .addr         (input_desc.addr),
        .is_write     (input_desc.is_write),
        .is_fetch     (input_desc.is_fetch),
        .burst_len    (input_desc.burst_len),
        .burst_size   (input_desc.burst_size),
        .burst_type   (input_desc.burst_type),
        .hit          (output_desc.hit),
        .target       (output_desc.target),
        .readable     (output_desc.readable),
        .writable     (output_desc.writable),
        .executable   (output_desc.executable),
        .cacheable    (output_desc.cacheable),
        .device       (output_desc.device),
        .allow_burst  (output_desc.allow_burst),
        .access_ok    (output_desc.access_ok),
        .decode_error (output_desc.decode_error)
    );

    task automatic check_output(
        input string        test_name,
        input output_desc_t actual,
        input output_desc_t expected
    );
        if (actual === expected) begin
            pass_count++;
            $display(
                "PASS | %s | addr=%08h wr=%0b fetch=%0b len=%0d size=%0d burst=%02b | output=%03h",
                test_name,
                input_desc.addr,
                input_desc.is_write,
                input_desc.is_fetch,
                input_desc.burst_len,
                input_desc.burst_size,
                input_desc.burst_type,
                actual
            );
        end else begin
            fail_count++;
            $display(
                "FAIL | %s | addr=%08h wr=%0b fetch=%0b len=%0d size=%0d burst=%02b | got=%03h expected=%03h",
                test_name,
                input_desc.addr,
                input_desc.is_write,
                input_desc.is_fetch,
                input_desc.burst_len,
                input_desc.burst_size,
                input_desc.burst_type,
                actual,
                expected
            );
        end
    endtask

    task automatic run_case(
        input string        test_name,
        input input_desc_t  stimulus,
        input output_desc_t expected
    );
        input_desc    = stimulus;
        expected_desc = expected;
        #1;
        check_output(test_name, output_desc, expected_desc);
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        //region boundaries
        run_case("RAM lower fetch", '{addr: 32'h0000_0000, is_write: 1'b0, is_fetch: 1'b1, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_PASS);
        run_case("RAM upper write", '{addr: 32'h000F_FFFC, is_write: 1'b1, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_PASS);
        run_case("Tiny lower read", '{addr: 32'h1000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, TINY_PASS);
        run_case("Tiny upper write", '{addr: 32'h1000_00FC, is_write: 1'b1, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, TINY_PASS);
        run_case("ASCON lower read", '{addr: 32'h2000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, ASCON_PASS);
        run_case("ASCON upper write", '{addr: 32'h2000_00FC, is_write: 1'b1, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, ASCON_PASS);
        run_case("APB lower read", '{addr: 32'h3000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, APB_PASS);
        run_case("APB upper write", '{addr: 32'h3000_FFFC, is_write: 1'b1, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, APB_PASS);

        //permission rejection
        run_case("Tiny fetch rejected", '{addr: 32'h1000_0000, is_write: 1'b0, is_fetch: 1'b1, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, TINY_REJECT);
        run_case("ASCON fetch rejected", '{addr: 32'h2000_0000, is_write: 1'b0, is_fetch: 1'b1, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, ASCON_REJECT);
        run_case("APB fetch rejected", '{addr: 32'h3000_0000, is_write: 1'b0, is_fetch: 1'b1, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, APB_REJECT);
        run_case("fetch write conflict", '{addr: 32'h0000_0000, is_write: 1'b1, is_fetch: 1'b1, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_REJECT);

        //unmapped addresses
        run_case("after RAM", '{addr: 32'h0010_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, NO_HIT);
        run_case("after Tiny", '{addr: 32'h1000_0100, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, NO_HIT);
        run_case("after ASCON", '{addr: 32'h2000_0100, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, NO_HIT);
        run_case("unmapped quadrant", '{addr: 32'h4000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, NO_HIT);

        //size and alignment
        run_case("RAM odd byte", '{addr: 32'h0000_0003, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_1B, burst_type: AXI_BURST_INCR}, MEM_PASS);
        run_case("RAM aligned halfword", '{addr: 32'h0000_0002, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_2B, burst_type: AXI_BURST_INCR}, MEM_PASS);
        run_case("RAM misaligned halfword", '{addr: 32'h0000_0001, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_2B, burst_type: AXI_BURST_INCR}, MEM_REJECT);
        run_case("RAM misaligned word", '{addr: 32'h0000_0002, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_REJECT);
        run_case("RAM oversized beat", '{addr: 32'h0000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_8B, burst_type: AXI_BURST_INCR}, MEM_REJECT);
        run_case("Tiny byte access", '{addr: 32'h1000_00FF, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_1B, burst_type: AXI_BURST_INCR}, TINY_PASS);
        run_case("ASCON halfword access", '{addr: 32'h2000_00FE, is_write: 1'b1, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_2B, burst_type: AXI_BURST_INCR}, ASCON_PASS);

        //burst legality and policy
        run_case("RAM INCR four beats", '{addr: 32'h0000_0100, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd3, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_PASS);
        run_case("RAM WRAP four beats", '{addr: 32'h0000_010C, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd3, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_WRAP}, MEM_PASS);
        run_case("RAM FIXED four beats", '{addr: 32'h0000_0200, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd3, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_FIXED}, MEM_PASS);
        run_case("Tiny burst rejected", '{addr: 32'h1000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd1, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, TINY_REJECT);
        run_case("ASCON fixed burst rejected", '{addr: 32'h2000_0000, is_write: 1'b1, is_fetch: 1'b0, burst_len: 8'd1, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_FIXED}, ASCON_REJECT);
        run_case("APB wrap burst rejected", '{addr: 32'h3000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd3, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_WRAP}, APB_REJECT);
        run_case("reserved burst type", '{addr: 32'h0000_0000, is_write: 1'b0, is_fetch: 1'b0, burst_len: AXI_LEN_SINGLE, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_RSVD}, MEM_REJECT);
        run_case("illegal WRAP length", '{addr: 32'h0000_0100, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd2, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_WRAP}, MEM_REJECT);

        //burst boundaries
        run_case("burst crosses RAM region", '{addr: 32'h000F_FFFC, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd1, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_REJECT);
        run_case("burst crosses 4KiB", '{addr: 32'h0000_0FFC, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd1, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_REJECT);
        run_case("burst ends at 4KiB", '{addr: 32'h0000_0FF0, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd3, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_INCR}, MEM_PASS);
        run_case("WRAP contained at 4KiB", '{addr: 32'h0000_0FFC, is_write: 1'b0, is_fetch: 1'b0, burst_len: 8'd3, burst_size: AXI_SIZE_4B, burst_type: AXI_BURST_WRAP}, MEM_PASS);

        $display("SUMMARY | PASS=%0d FAIL=%0d", pass_count, fail_count);
        if (fail_count != 0)
            $fatal(1, "soc_addr_decode_tb failed");
        $finish;
    end

endmodule
