# Repository Instructions

## Repository scope

This repository contains a legacy five-stage RV32 SoC and a seven-stage RV32 SoC with FPGA,
ASAP7, and Sky130 storage backends.

- rtl/cpu/core/: processor RTL and pipeline blocks.
- rtl/cpu/cache/: caches, write buffer, CPU-side bus arbitration, and AXI packages.
- rtl/soc/interconnect/: SoC address-map and interconnect RTL.
- rtl/lib/: platform-neutral SRAM contracts and platform backends.
- rtl/fpga/: FPGA-only top-level and peripheral RTL.
- tb/unit/, tb/integration/, tb/models/, tb/riscv_test/: verification sources.
- filelists/: authoritative compile source lists for repository build profiles.
- flow/: Vivado and LibreLane flow entrypoints.
- constrs/: implementation constraints.
- docs/spec/: design contracts; docs/notes/: historical engineering notes.

## Sources of truth

- Use current RTL plus executable Makefile, filelists, and flow scripts as implemented truth.
- Treat docs/spec/ as intended design contracts. Update the relevant specification whenever a
  change affects an interface, protocol, timing contract, address map, or architectural invariant.
- Treat docs/notes/ as historical evidence, not current truth.
- rtl/soc/interconnect/soc_addr_map_pkg.sv is the implemented SoC address-map source of truth.
  Keep docs/spec/axi_interconnect.md synchronized with accepted address-map changes.
- Report conflicts between specification, RTL, tests, and tool configuration. Do not silently
  choose one source.
- Do not put progress, test results, TODO lists, roadmaps, or detailed architecture in this file.

## Build profiles and source selection

| Target | Filelist | Top module |
|---|---|---|
| legacy5 | filelists/legacy5.f | riscv_soc |
| fpga7 | filelists/fpga7.f | riscv_soc_7stg |
| asap7 | filelists/asap7.f | riscv_soc_7stg |
| sky130 | filelists/sky130.f | riscv_soc_7stg |

- Preserve filelist dependency order; packages and storage backends must precede their consumers.
- Add a source only to the profiles that require it.
- Keep the public icache_7stg, dcache_7stg, and dbp_7stg selectors platform-neutral.
  Implement target-specific behavior in their backend modules and filelists.
- Do not compile mutually exclusive platform backends into the same profile.
- Preserve the _7stg suffix where five-stage and seven-stage modules coexist.

## Canonical commands

Run repository commands from the repository root.

    make lint TARGET=<legacy5|fpga7|asap7|sky130>
    make test TARGET=<target> TEST=<Makefile-test-key>
    make regression TARGET=<legacy5|fpga7|asap7|sky130>
    make regression-all
    make synth TARGET=<legacy5|fpga7>
    make librelane-config
    make librelane-synth

- Supported test keys and regression membership are defined by TEST_* and REGRESSION_* in the
  root Makefile; do not invent unregistered test names.
- make synth is the canonical Vivado synthesis entrypoint and consumes the selected repository
  filelist plus constrs/timing.xdc.
- make librelane-config generates build/librelane/sky130/config.json from filelists/sky130.f.
- make librelane-synth is a Dockerized Sky130 front-end and macro-instance check ending at
  OpenROAD.CheckMacroInstances; it is not full PnR, timing closure, or signoff.
- Treat direct scripts under flow/ as implementation details or specialized flows unless a task
  explicitly targets a documented script.
- Software images are built through sw/Makefile, for example make -C sw, make -C sw hello, or
  make -C sw fibonacci.

## Validation contract

- For project-owned Markdown or instruction-only changes, run git diff --check and verify every
  referenced path and command.
- For RTL changes, run make lint and the relevant targeted tests for every affected profile.
- Before completing a profile-specific RTL change, run make regression TARGET=<profile>.
- Shared seven-stage RTL changes affect fpga7, asap7, and sky130; regress all three.
- Legacy five-stage-only changes require the legacy5 regression.
- Changes to shared packages, platform selectors, root Makefile behavior, or cross-profile
  filelists require make regression-all.
- Vivado or Sky130 flow changes require their corresponding canonical flow command. Report only
  the stage actually reached; do not infer timing closure, PnR completion, or signoff.
- A maintained testbench must be registered in the root Makefile with a pass marker. Its DUT
  dependencies must come from the selected filelist or an explicit TEST_EXTRA_* entry.
- Never claim a command passed unless it was run in the current worktree and its success condition
  was observed.

## Source and artifact boundaries

- New project-owned RTL, testbench, and script files must use the existing Apache-2.0 project
  header template.
- Preserve all existing third-party copyright and license notices. In particular, do not relicense
  collateral under rtl/lib/asap7/ or imported sources under tb/riscv_test/.
- Do not bulk-format or mechanically rewrite third-party collateral.
- build/, simulator object directories, Vivado run directories, reports, checkpoints, and
  generated LibreLane configuration are generated artifacts. Do not hand-edit or commit them.
- Modify the generator, source filelist, constraint, or flow script that owns an artifact instead.
- Preserve unrelated uncommitted work and keep validation artifacts under build/.
