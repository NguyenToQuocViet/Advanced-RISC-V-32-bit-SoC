# CLAUDE.md — Advanced RISC-V 32-bit SoC

RISC-V 32-bit CPU (RV32I+M, đang mở rộng IME/Zvvm) với cache subsystem và SoC top-level. SystemVerilog, target xc7z020.

---

## RTL Structure

- `riscv_soc.sv` — Top-level SoC: `riscv_core` + `cache_subsystem`, AXI4 master port
- `cpu/riscv_core.sv` — CPU core (v1.1, 2026-03-26) — 5-stage pipeline integration
- `cache/cache_subsystem.sv` — I-cache + D-cache + write buffer + bus arbiter

### CPU Core (`rtl/cpu/`) — Complete

| Module | Chức năng | Loại |
|--------|-----------|------|
| `cpu_pkg.sv` | Shared parameters/constants | Package |
| `fcu.sv` | Fetch Control Unit (IF stage) | Comb+Seq |
| `dbp.sv` | Dynamic Branch Predictor (2-bit BHT + BTB) | Seq |
| `if_id_pipeline.sv` | IF/ID pipeline register | Seq |
| `immgen.sv` | Immediate Generator (6 RV32I formats) | Comb |
| `cu.sv` | Control Unit (EX/MEM/WB control signals) | Comb |
| `rf.sv` | Register File (32x32-bit, write-first forwarding) | Seq |
| `id_ex_pipeline.sv` | ID/EX pipeline register | Seq |
| `alu.sv` | ALU (11 ops, combinational) | Comb |
| `fu.sv` | Forwarding Unit (RAW hazard, MEM>WB priority) | Comb |
| `hdu.sv` | Hazard Detection Unit (load-use + dcache stall) | Comb |
| `bru.sv` | Branch Resolution Unit (misprediction detect) | Comb |
| `ex_mem_pipeline.sv` | EX/MEM pipeline register | Seq |
| `lsu.sv` | Load/Store Unit (wstrb, alignment, sign-ext) | Comb |
| `mem_wb_pipeline.sv` | MEM/WB pipeline register | Seq |
| `wb.sv` | Write Back (3-to-1 mux: ALU/MEM/PC+4) | Comb |

### Cache (`rtl/cache/`)

| Module | Chức năng |
|--------|-----------|
| `cache_pkg.sv` | Shared cache parameters |
| `axi_pkg.sv` | AXI bus protocol definitions |
| `icache.sv` | 4KB direct-mapped, FSM: IDLE->REFILL_REQ->REFILL_DATA->REFILL_DONE |
| `dcache.sv` | 4KB 2-way set-associative, write-no-allocate |
| `write_buffer.sv` | 4-entry write buffer |
| `bus_arbiter.sv` | I-cache / D-cache AXI arbitration |

Testbench: `tb/riscv_soc_tb.sv`
TCL scripts: `tcl/` (elaborate, sim, synth, impl, lint)

---

## `cpu_pkg.sv` — Parameters

- Base: `DATA_WIDTH=32`, `ADDR_WIDTH=32`, `NOP_INSTR=32'h0000_0013`, `PC_RESET_VEC=32'h0`
- Branch predictor: `BP_ENTRIES=1024`, `BP_IDX_BITS=10`, `BTB_TAG_BITS=20`, `PRED_BITS=2`, `STRONGLY_NT/WEAKLY_NT/WEAKLY_T/STRONGLY_T`
- ALU ops: `ALU_ADD=0` .. `ALU_PASS_B=10` (LUI)
- WB select: `WB_ALU=2'b00`, `WB_MEM=2'b01`, `WB_PC4=2'b10`
- Opcodes: `OP_R`, `OP_I_ALU`, `OP_I_LOAD`, `OP_I_JALR`, `OP_S`, `OP_B`, `OP_U_LUI`, `OP_U_AUIPC`, `OP_J`

---

## Key Design Details

### FCU (`fcu.sv`)

- PC update: `!stall && cache_valid && cache_ready` — `cache_ready` blocks PC advance during CWF (icache `REFILL_DATA`, valid=1 but ready=0)
- Misprediction redirect: **registered** `mispredict_r` / `correct_pc_r` (timing fix v1.1)
- `if_req = !stall && !mispredict_r`
- Outputs (`if_id_pc`, `instr_o`, `if_id_pred_taken/target`) are combinational — registered by IF/ID pipeline

### Dynamic Branch Predictor (`dbp.sv`)

- BHT: 1024-entry 2-bit saturating counters, indexed by `PC[11:2]`
- BTB: 1024-entry `{valid(1b), tag(20b), target(32b)}`, same index
- Full tag: `PC[31:12]` = 20 bits — zero aliasing
- Predict taken: `btb_hit && bht[idx] >= 2`
- IF read: combinational (async). EX write: BHT always update; BTB only when `ex_actual_taken`
- Storage: LUTRAM (~880 LUT6s, ~3.3% xc7z020 SLICEM)

### Control Unit (`cu.sv`)

- 2-case structure (signal-centric):
  - Case 1 (opcode): `alu_src`, `alu_src_a`, `mem_req/we`, `reg_we`, `wb_sel`, `branch`, `jump`
  - Case 2 (`{funct7[5], funct3}`): `alu_op` — only OP_R/OP_I_ALU need deep decode
- `alu_src_a=1` cho AUIPC, `ALU_PASS_B` cho LUI, `WB_PC4` cho JAL/JALR

### Register File (`rf.sv`)

- 32x32-bit, no reset. Async read, sync write, block write to x0
- Write-first forwarding: `rdata1 = (reg_we && rd == rs1 && rd != 0) ? wdata : register[rs1]`

### Forwarding Unit (`fu.sv`)

- `forward_a/b[1:0]`: `00`=no fwd, `01`=WB, `10`=MEM (MEM wins over WB)
- Guard: `rd != 0`

### Hazard Detection Unit (`hdu.sv`) — v1.1

- Load-use: `ex_mem_req && !ex_mem_we && ex_rd matches id_rs1/rs2` → `load_use_stall + ex_flush`
- D-cache miss: `mem_req && !mem_valid` → `dcache_stall` (freeze entire pipeline)
- I-cache miss: handled in FCU (PC holds when `!cache_valid`)

### Branch Resolution Unit (`bru.sv`)

- `ex_actual_taken = (branch && branch_cond) || jump`
- JALR target: `(src_a + imm) & ~32'h1`; JAL/branch: `pc + imm`
- `ex_mispredict`: taken bit wrong OR taken but wrong target
- DBP update: `ex_update_en = branch || jump`

### Immediate Generator (`immgen.sv`)

- I/S/B/U/J formats, sign-extended. B/J scramble bits (imm[0]=0 always)

### Load/Store Unit (`lsu.sv`)

- Store wstrb: byte->one-hot, half->2-bit aligned, word->`4'b1111`
- Store wdata: replicate to all byte lanes, wstrb selects
- Load: extract by `addr[1:0]`/`addr[1]`, sign/zero extend by `mem_size[2:0]`

### Pipeline Registers

- IF/ID: flush inserts `NOP_INSTR` (not `'0`), priority over stall. Propagates `pred_target`.
- ID/EX: passes `rs1/rs2` for forwarding, `pred_taken/target` for BRU
- EX/MEM: branch signals consumed in EX — not forwarded. `rd/reg_we` exposed for FU
- MEM/WB: `rd/reg_we` exposed for FU WB->EX path

### Top-Level Integration (`riscv_core.sv`) — v1.1

- Forwarding mux (3-to-1): `10`=MEM fwd, `01`=WB fwd, `00`=register
- Stall: `load_use_stall || dcache_stall`
- Flush routing:
  - `if_id_flush = mispredict_r | (!if_icache_valid && !if_id_stall)`
  - `id_ex_flush = mispredict_r | ex_flush`
  - `ex_mem_flush = mispredict_r`
  - `mem_wb_flush = 1'b0`
- BRU->DBP: combinational feedback (DBP self-registers)
- WB->RF: `wb_wdata/reg_we/rd` wired directly

**Bugs fixed:**
1. FCU floating outputs — IF/ID connects to gated wires, not raw bypass
2. `if_id_flush` gating — `!if_id_stall` gate prevents flushing held instruction during stall
3. `wb` floating outputs — `reg_we_o/rd_o` wired to named signals

### SoC Top-Level (`riscv_soc.sv`)

- IF channel: `if_pc/if_req` (core->cache); `if_instr/icache_ready/valid` (cache->core)
- MEM channel: `mem_addr/req/we/wdata/wstrb` (core->cache); `mem_rdata/dcache_ready/valid` (cache->core)
- External: `clk`, `rst_n`, `fence/fence_done`, full AXI4 master interface

### Cache Interface Protocol

| Signal | Meaning |
|--------|---------|
| `icache_valid=1` | Instruction available now |
| `icache_ready=1` | Can accept new request next cycle |
| Both=1 | Safe to advance PC |
| `valid=1, ready=0` | CWF — capture instruction, do NOT advance PC |

---

## Timing Fix: Registered Mispredict Feedback (v1.1)

**Problem:** 89 MHz (failed 80 MHz target). Critical path 14 LUT levels:
`mem_wb/pc_reg -> wb pc+4 adder -> forwarding mux -> BRU JALR adder -> mispredict comparator -> FCU/pc_reg CE`

**Fix:** Register `bru_mispredict/correct_pc` one cycle before FCU. Cuts critical path at EX->IF boundary.

**Trade-off:** Mispredict penalty 2->3 cycles. Compensated by flushing `ex_mem_pipeline` on `mispredict_r`.

**Current:** 85 MHz. Target: >100 MHz. Bottleneck: D-Cache critical path (defer).

---

## Vivado Warning Fixes (applied)

| File | Problem | Fix |
|------|---------|-----|
| `cache/write_buffer.sv` | `entry_addr/data/strb` in async reset block | Split to clock-only block |
| `cache/icache.sv` | 2D `cache_data` + async reset | Flatten to 1D `[LINE_WIDTH-1:0]`; split blocks |
| `cache/dcache.sv` | 3D `cache_data` + async reset | Flatten to 1D, index=`{addr_idx, hit_way}`; split blocks |
| `cpu/dbp.sv` | `bht/btb_*` in async reset block + loop reset | Move to clock-only block; power-up init to 0 |

`dcache.sv` 1D indexing: `CACHE_DEPTH = DC_SETS * DC_WAYS = 256`. Tag check: `cache_tag[addr_idx * DC_WAYS + w]`. DC_WAYS=2 (power of 2) -> clean bit concat.

### `create_project.tcl` Fixes

1. Path: `constrs/timing.xdc` -> `../constrs/timing.xdc` (TCL runs from `work/`)
2. FPGA part: `xc7a35ticsg324-1L` -> `xc7z020clg400-1`

---

## Extension Roadmap: RV32I -> IME

### Hardware Targets

- **xc7z020clg400-1** (Zynq 7-Series) — Year-3 target. Resource-constrained, VLEN=128/256.
- **Kria KV260 (XCK26, UltraScale+)** — Research/paper target. 117K LUT, 1248 DSP58E2, UltraRAM. VLEN=512.

### Extension Order

```
RV32I (done) -> RV32M -> Zicsr -> Reduced RVV -> IME (Zvvm)
```

---

### Phase 1: RV32M — Multiply/Divide

All R-type, funct7 = `7'b0000001`:

| Instruction | Operation | Output |
|-------------|-----------|--------|
| MUL | signed x signed | bits [31:0] |
| MULH | signed x signed | bits [63:32] |
| MULHSU | signed x unsigned | bits [63:32] |
| MULHU | unsigned x unsigned | bits [63:32] |
| DIV/DIVU | signed/unsigned division | quotient |
| REM/REMU | signed/unsigned remainder | remainder |

**Multiplier:** Dùng `*` operator (Vivado -> DSP48E1). Compute `mul_ss/mul_uu/mul_su` combinationally, mux trên funct3. Timing risk: check WNS sau impl, thêm pipeline register nếu cần.

**Divider:** Non-Restoring Division (32-34 cycles). FSM handshake: `req/done`. HDU stall: `ex_is_div && !div_done`. Edge cases: div-by-zero (`quotient=0xFFFFFFFF, rem=dividend`), overflow (`INT_MIN / -1`).

**Design decision:** Separate `mul_div_unit.sv` (Option B) — dễ pipeline MUL independently.

| File | Change |
|------|--------|
| `cpu/cu.sv` | Detect funct7=0000001, `is_mul/is_div/is_rem` |
| `cpu/mul_div_unit.sv` | New: MUL combinational + DIV FSM |
| `cpu/hdu.sv` | Add `ex_is_div && !div_done` stall |
| `cpu/cpu_pkg.sv` | ALU op codes for MUL variants |
| `cpu/id_ex_pipeline.sv` | Pass `is_mul/is_div` |
| `cpu/riscv_core.sv` | Instantiate mul_div_unit |

---

### Phase 2: Zicsr — CSR Infrastructure

Cần trước RVV vì `vsetvli` ghi vào `vtype/vl` CSRs.

**Minimum CSRs cho Zvvm:**
- `vtype` (0xC20), `vl` (0xC21), `vlenb` (0xC22 — read-only = VLEN/8)

**Instructions:** csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci

**New file:** `cpu/csr_file.sv`

---

### Phase 3: Reduced RVV Infrastructure

```
cpu/vrf.sv          — Vector Register File (32 x VLEN bits)
cpu/vsetvl_unit.sv  — vsetvli/vsetivli/vsetvl -> update vtype/vl
cpu/vload_store.sv  — tile load/store (vmtl.v / vmts.v)
```

VLEN: xc7z020 -> 256 (VRF = 1KB ~ 8 BRAM18). KV260 -> 512 (UltraRAM).

Required RVV subset: VRF + vtype/vl CSRs + vsetvli + LMUL={1,2,4,8}. NO arithmetic/masking/reduction.

---

### Phase 4: IME (Zvvm) — Research Contribution

**Background:** Spec unratified, no open-source RTL. Novelty confirmed. Target: DAC/ICCAD paper. Backup: PPA comparison Zvvm vs TinyTransformer.

**Core concept:** Reuse 32 RVV vector registers. Tile geometry via lambda parameter + 3 new vtype fields.

**New vtype fields** (set via vsetvl, outside vsetvli immediate range):
- `vtype[XLEN-5]` = altfmt_A (signed/unsigned input A)
- `vtype[XLEN-6]` = altfmt_B (signed/unsigned input B)
- `vtype[XLEN-7]` = bs (block size for microscaling)

**Tile geometry:**
- `K_eff = lambda x W x LMUL`, `R = lambda x SEW / 16`, `M x R = VLEN / 16`

**Integer MAC** (opcode=0x57, OPIVV, vm=1):
- `vmmacc.vv` (funct6=0x38) — same width
- `vwmmacc.vv` (funct6=0x39) — 2x widening
- `vqwmmacc.vv` (funct6=0x3a) — 4x widening

**FP MAC** (OPFVV): `vfmmacc.vv` (0x14), `vfwmmacc.vv` (0x15), `vfqwmmacc.vv` (0x16). vm=0 -> microscaling (E8M0 scales in v0).

**Tile Load/Store (Zvvmtls):** `vmtl.v`, `vmttl.v` (transpose), `vmts.v`, `vmtts.v`

**Data types:** Int4-64, OFP4/8, FP16/BF16/FP32/64, MXFP4/8/MXINT4/8

**New file:** `cpu/ime_mac.sv` — Booth encoding + Wallace/Dadda tree (NOT `*` operator — need N parallel Int8xInt8 with shared adder tree).

**Key references:**
- Spec: `https://github.com/riscv/integrated-matrix-extension`
- Proposal G: `https://lists.riscv.org/g/tech-integrated-matrix-extension/attachment/214/0/20250303_IME_ISA_proposal.pdf`
- Ratification plan: `https://riscv.atlassian.net/wiki/spaces/IMEX/pages/598867969/IME+Ratification+Plan`
