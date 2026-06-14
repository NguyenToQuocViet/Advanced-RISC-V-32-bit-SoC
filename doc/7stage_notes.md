# 7-Stage Pipeline Notes

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
