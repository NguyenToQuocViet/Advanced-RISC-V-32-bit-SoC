# 7-Stage Pipeline Notes

## FCU2 fixed bug: BTB redirect killed producer branch

- Old RTL: `if2_redirect = pred_taken && !ex_mispredict`, then `if2_id_flush` also includes `if2_redirect`.
- Failure: a predicted-taken branch in IF2 redirects FCU1 to `pred_target`, but the branch itself is flushed before entering ID/EX.
- Consequence: EX never executes that branch, so the core cannot verify actual taken/target and cannot recover from a wrong prediction.
- RTL fix: keep redirect as PC-control only; do not flush IF2/ID solely because of `if2_redirect`.
- Guard used: invalid/no-cache-response cases still flush; side effects are qualified by `if2_valid`, `cache_valid`, CWF duplicate, or later EX mispredict.


## D-Cache 7-stage boundary decision

- I-cache and D-cache use the same external contract: request enters cache, cache owns SRAM lookup metadata internally.
- `lookup_valid_q` is cache-transaction validity, not architectural pipeline-slot validity.
- LSU keeps the 5-stage-like D-cache interface: `addr`, `mem_req`, `mem_we`, `wdata`, `wstrb`.
- MEM1/MEM2 pipeline carries architectural load metadata only: `addr_lsb`, `mem_size`, WB controls.
- Store hit consumes the 1RW SRAM port to update the cached word; the next request is launched from `STORE_DONE`, not from the same response cycle.
- This keeps I-cache/D-cache timing contracts symmetric and avoids public cache-internal tag/index metadata.

## I-Cache refill-buffer bypass enhancement

- Current design is blocking: after a miss, `rf_buffer` only serves the original critical-word request; `icache_ready` remains low during refill and `REFILL_DONE`.
- Future enhancement: treat `rf_buffer` as a temporary cache line. Accept subsequent requests matching `{rf_tag, rf_idx}` and return `rf_buffer[word_sel]` whenever the corresponding `rf_valid[word_sel]` is set.
- This can also serve same-line requests while `REFILL_DONE` uses the 1RW SRAM port to commit the completed line.
- Requests to another line may remain stalled initially; hit-under-miss is a separate, more complex extension.
- Required changes: decouple request acceptance from the blocking FSM, track metadata for new requests during refill, redefine `ready/valid`, and verify redirect/abandon plus duplicate-CWF behavior.
- Trade-off: fewer refill-related stalls versus greater control, handshake, and verification complexity. Defer until the baseline 7-stage core is integrated and passes regression.


## I-Cache IF1/IF2 clarity refactor

- Keep `icache_7stg` as one module because SRAM arrays and refill FSM are shared state; do not split it merely to mirror pipeline stages.
- Make the hidden stage boundary explicit through naming and source structure: `if1_pc`, `if1_req`, `if1_ready`, `if1_fire`, `if2_instr`, and `if2_valid`.
- Group logic under `IF1 request launch`, `IF1-to-IF2 metadata registers`, and `IF2 lookup resolution` sections.
- Document the timing contract directly in RTL: request accepted in cycle N, SRAM tag/data resolved in cycle N+1.
- Rename generic `lookup_valid_q` if appropriate so its role as IF2 request validity is immediately visible.
- Refactor only after baseline integration and regression; this is a readability change, not functional priority.


## D-Cache ASAP7 data-array checkpoint (2026-07-16)

### Decision

- Scope hiện tại chỉ migrate D-Cache data array; tag array vẫn dùng `sram_1rw` để tách riêng quyết định mapping tag.
- Mỗi way dùng một `srambank_64x4x64_6t122`: tổng cộng hai macro 256x64-bit cho D-Cache 4 KiB, 2-way.
- SRAM address là `{set[6:0], word_sel[1]}`; `word_sel[0]` chọn word 32-bit thấp hoặc cao trong cặp 64-bit.
- `sram_256x64_1rw` giữ một contract 1RW, synchronous-read, full-word-write; backend generic dùng cho FPGA, `ASAP7_SRAM` instantiate macro thật.

### Timing and control

- Load hit vẫn dùng một SRAM read cycle.
- Store hit đọc cặp 64-bit, merge byte theo `wstrb`, rồi full-write lại cặp; không còn data `wmask` vật lý.
- Refill vẫn nhận bốn beat 32-bit, nhưng commit thành hai write 64-bit qua `REFILL_COMMIT_LO` và `REFILL_COMMIT_HI`.
- Valid/LRU chỉ cập nhật sau commit cặp cao; uncacheable refill không commit; external D-Cache ready/valid contract không đổi.

### Collateral and verification

- Đã thêm wrapper cùng `.v`, `.lib`, `.lef` và BSD `LICENSE` của macro; chưa copy GDS vì bundle chỉ có GDS bank tổng hợp.
- D-Cache directed: generic `48 PASS | 0 FAIL`; ASAP7 macro `48 PASS | 0 FAIL`.
- MEM-path integration: `16 PASS | 0 FAIL`; TB được sửa để giữ MEM1 request đến khi `dcache_ready` đúng theo HDU contract.
- SoC RV32UI: generic và ASAP7 macro đều `38 PASS | 0 FAIL | 0 TIMEOUT`.
- Vivado 2025.2 infer đúng hai data RAM 256x64, mỗi way một `RAMB36E2`; đây là synthesis evidence, chưa phải timing closure.

### Remaining

- Tag SRAM migration được hoàn tất trong checkpoint kế tiếp; I-Cache macro mapping là storage boundary tiếp theo.
- Cách đóng gói third-party collateral/GDS khi push GitHub vẫn chưa chốt.

## D-Cache ASAP7 tag-array checkpoint (2026-07-17)

### Decision

- Một `srambank_64x4x48_6t122` chứa tag của cả hai way: `{6'b0, tag_way1[20:0], tag_way0[20:0]}`.
- Macro có 256 entry; D-Cache dùng 128 entry qua address `{1'b0, set[6:0]}`.
- Một synchronous read trả đồng thời hai tag cho hai comparator; hit latency và external ready/valid contract không đổi.
- Valid bits và LRU tiếp tục dùng flop vì cần reset và cập nhật độc lập.

### Full-word tag update

- ASAP7 tag macro không có write mask; `tag_wmask` và generic masked tag SRAM đã bị loại bỏ.
- Tại `REFILL_COMMIT_HI`, controller giữ raw tag của non-victim way, replace victim field bằng `rf_tag` và full-write 48-bit; valid bits tiếp tục quyết định tag field nào có nghĩa.
- Tag write vẫn xảy ra đồng thời với data high-pair commit; không thêm FSM state hoặc refill cycle.

### Verification

- Verilator lint sạch cho generic và `ASAP7_SRAM` backends.
- D-Cache directed generic và ASAP7: `76 PASS | 0 FAIL`; gồm replace từng way và kiểm tra tag way còn lại được giữ nguyên.
- MEM-path generic và ASAP7: `16 PASS | 0 FAIL`.
- SoC RV32UI generic và ASAP7: `38 PASS | 0 FAIL | 0 TIMEOUT`.
- Vivado 2025.2 generic backend nhận tag storage là RAM nhưng tối ưu thành `128x42` LUTRAM vì address MSB và sáu padding bit không được dùng; ASIC backend vẫn instantiate explicit macro `256x48`.


## I-Cache ASAP7 SRAM checkpoint (2026-07-18)

### Decision

- Tag array dùng một `srambank_64x4x20_6t122`, có logical organization `256x20`; toàn bộ `set[7:0]` đều có nghĩa.
- Data array dùng hai `sram_256x64_1rw` song song: một macro giữ `low64`, macro còn lại giữ `high64` của cùng cache line.
- Hai data macros dùng chung enable, write-enable và set address; read data được ghép lại thành `{high64, low64}`.
- `cache_valid` tiếp tục dùng flop array; external ready/valid contract và refill FSM không đổi.

### Refill commit

- I-Cache chỉ full-write cache line sau khi nhận đủ bốn words, nên không cần write mask hoặc read-modify-write.
- Tại `REFILL_DONE`, tag macro và cả hai data macros được ghi song song trong một cycle.

### Verification

- Verilator lint sạch cho I-Cache và cache subsystem ở generic và `ASAP7_SRAM` backends.
- Fetch-path generic và ASAP7: `23 PASS | 0 FAIL`; gồm committed low/high SRAM hits sau khi refill buffer chuyển sang line khác.
- SoC RV32UI generic và ASAP7: `38 PASS | 0 FAIL | 0 TIMEOUT`.
- Vivado 2025.2 generic backend infer `1x RAMB18E2` cho tag và `2x RAMB36E2` cho data, không dùng LUTRAM.

## BTB ASAP7 1RW checkpoint (2026-07-19)

### Decision

- BTB logical `1024x52` được đóng gói vào wrapper `1024x64 1RW`; backend ASAP7 instantiate `srambank_256x4x64_6t122`, 12 bit cao được pad zero.
- Four-entry flop queue giữ `{index[9:0], tag[19:0], target[31:0]}`; taken update cùng index được coalesce, overflow drop oldest và không stall pipeline.
- `if1_fire` luôn ưu tiên SRAM read; cycle không có read sẽ drain queue head, hoặc direct-write EX update nếu queue rỗng.
- Pending entry cùng index shadow SRAM: tag match thì forward target, tag mismatch thì forced miss. Forwarding metadata được latch IF1-to-IF2 nên drain không làm đổi response đang giữ.
- `btb_valid` chỉ set khi SRAM write commit; flush kill IF2 query nhưng không discard queued update. BHT và public DBP interface không đổi.

### Verification

- DBP directed generic và ASAP7: `40 PASS | 0 FAIL`; gồm collision, coalesce, tag shadow, overflow, drain+enqueue và flush.
- Fetch-path generic và ASAP7: `23 PASS | 0 FAIL`.
- SoC RV32UI generic và ASAP7: `38 PASS | 0 FAIL | 0 TIMEOUT`.
- Vivado 2025.2 infer BTB payload thành `1x RAMB36E1 + 1x RAMB18E1`; 12 padding bit không dùng bị tối ưu.
- u-BTB được giữ ngoài scope, là bước tối ưu prediction/PPA tiếp theo.
