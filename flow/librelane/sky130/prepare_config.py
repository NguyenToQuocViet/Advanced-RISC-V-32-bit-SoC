#!/usr/bin/env python3
# -----------------------------------------------------------------------------
# Copyright (c) 2026 NGUYEN TO QUOC VIET
# Ho Chi Minh City University of Technology (HCMUT-VNU)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# -----------------------------------------------------------------------------
"""Generate the LibreLane Sky130 config from filelists/sky130.f."""

from __future__ import annotations

import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
FILELIST = REPO_ROOT / "filelists" / "sky130.f"
OUTPUT = REPO_ROOT / "build" / "librelane" / "sky130" / "config.json"
SRAM_ROOT = "pdk_dir::libs.ref/sky130_sram_macros"


def parse_filelist() -> tuple[list[str], list[str]]:
    sources: list[str] = []
    defines: list[str] = []

    for raw_line in FILELIST.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("+define+"):
            defines.append(line.removeprefix("+define+"))
            continue
        source = REPO_ROOT / line
        if not source.is_file():
            raise FileNotFoundError(f"Missing source from {FILELIST}: {line}")
        sources.append(str(source.resolve()))

    return sources, defines


def macro_views(name: str, liberty: str) -> dict[str, object]:
    return {
        "gds": [f"{SRAM_ROOT}/gds/{name}.gds"],
        "lef": [f"{SRAM_ROOT}/lef/{name}.lef"],
        "lib": {"nom_tt_025C_1v80": [f"{SRAM_ROOT}/lib/{liberty}.lib"]},
        "spice": [f"{SRAM_ROOT}/spice/{name}.spice"],
    }


def main() -> None:
    sources, defines = parse_filelist()
    config = {
        "meta": {"version": 2},
        "DESIGN_NAME": "riscv_soc_7stg",
        "VERILOG_FILES": sources,
        "VERILOG_DEFINES": [*defines, "SYNTHESIS"],
        "USE_SLANG": True,
        "CLOCK_PORT": "clk",
        "CLOCK_PERIOD": 20.0,
        "STA_CORNERS": ["nom_tt_025C_1v80"],
        "PNR_CORNERS": ["nom_tt_025C_1v80"],
        "SYNTH_STRATEGY": "DELAY 4",
        "FP_CORE_UTIL": 40,
        "PL_TARGET_DENSITY_PCT": 45,
        "PL_TIMING_DRIVEN": True,
        "RUN_POST_GRT_RESIZER_TIMING": True,
        "PDN_CONNECT_MACROS_TO_GRID": True,
        "MACROS": {
            "sky130_sram_1kbyte_1rw1r_32x256_8": macro_views(
                "sky130_sram_1kbyte_1rw1r_32x256_8",
                "sky130_sram_1kbyte_1rw1r_32x256_8_TT_1p8V_25C",
            ),
            "sky130_sram_1kbyte_1rw1r_8x1024_8": macro_views(
                "sky130_sram_1kbyte_1rw1r_8x1024_8",
                "sky130_sram_1kbyte_1rw1r_8x1024_8_TT_1p8V_25C",
            ),
        },
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    print(OUTPUT)


if __name__ == "__main__":
    main()
