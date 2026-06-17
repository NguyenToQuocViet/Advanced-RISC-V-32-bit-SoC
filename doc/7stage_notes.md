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
