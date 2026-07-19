# ==========================================
# synth_soc_7stg_kv260.tcl
# Synthesize riscv_soc_7stg on KV260 fabric.
# No board pin constraints; timing uses clock-only constraint.
# ==========================================

set part_name "xck26-sfvc784-2LV-c"
set top_name  "riscv_soc_7stg"
set rpt_root  "reports/soc_7stg_kv260"

# Optional:
#   vivado -mode batch -source ../tcl/synth_soc_7stg_kv260.tcl -tclargs 5.500
set period_ns 10.000
if {[llength $argv] >= 1} {
    set period_ns [lindex $argv 0]
    set period_tag [string map {. p} [format %.3f $period_ns]]
    set rpt_dir "${rpt_root}_${period_tag}ns"
} else {
    set rpt_dir $rpt_root
}

file mkdir $rpt_dir

create_project -in_memory -part $part_name

# Packages
read_verilog -sv {
    ../rtl/cpu/core/cpu_pkg.sv
    ../rtl/cpu/cache/cache_pkg.sv
    ../rtl/cpu/cache/axi_pkg.sv
}

# SRAM wrappers
read_verilog -sv {
    ../rtl/lib/sram_1rw.sv
    ../rtl/lib/sram_1r1w.sv
}

# 7-stage core
read_verilog -sv {
    ../rtl/cpu/core/riscv_core_7stg.sv
    ../rtl/cpu/core/hazard_ctrl_7stg.sv
    ../rtl/cpu/core/mispredict_reg.sv
    ../rtl/cpu/core/hdu_7stg.sv
    ../rtl/cpu/core/fcu1.sv
    ../rtl/cpu/core/if1_if2_pipeline.sv
    ../rtl/cpu/core/dbp_7stg.sv
    ../rtl/cpu/core/fcu2.sv
    ../rtl/cpu/core/if2_id_pipeline.sv
    ../rtl/cpu/core/cu.sv
    ../rtl/cpu/core/rf.sv
    ../rtl/cpu/core/immgen.sv
    ../rtl/cpu/core/id_ex_pipeline.sv
    ../rtl/cpu/core/fu_7stg.sv
    ../rtl/cpu/core/fwd_mux_7stg.sv
    ../rtl/cpu/core/alu_operand_mux.sv
    ../rtl/cpu/core/alu.sv
    ../rtl/cpu/core/bru.sv
    ../rtl/cpu/core/ex_mem1_pipeline.sv
    ../rtl/cpu/core/lsu1.sv
    ../rtl/cpu/core/mem1_mem2_pipeline.sv
    ../rtl/cpu/core/lsu2.sv
    ../rtl/cpu/core/mem2_wb_pipeline.sv
    ../rtl/cpu/core/wb.sv
}

# 7-stage cache subsystem
read_verilog -sv {
    ../rtl/cpu/cache/icache_7stg.sv
    ../rtl/cpu/cache/dcache_7stg.sv
    ../rtl/cpu/cache/write_buffer.sv
    ../rtl/cpu/cache/bus_arbiter.sv
    ../rtl/cpu/cache/cache_subsystem_7stg.sv
}

# SoC top
read_verilog -sv ../rtl/cpu/riscv_soc_7stg.sv

# Clock-only timing constraint.
set clk_xdc "$rpt_dir/clock_only.xdc"
set fp [open $clk_xdc w]
puts $fp "create_clock -period $period_ns -name clk \[get_ports clk\]"
close $fp
read_xdc $clk_xdc

# Synthesis
synth_design -top $top_name -flatten_hierarchy rebuilt

# Reports
report_utilization -hierarchical -file $rpt_dir/util_hier.rpt
report_utilization -file $rpt_dir/util.rpt
report_timing_summary -file $rpt_dir/timing.rpt
report_ram_utilization -file $rpt_dir/ram.rpt

puts "=== Synthesis complete: $top_name on $part_name ==="
puts "=== Clock period: $period_ns ns ==="
puts "=== Reports: $rpt_dir ==="
