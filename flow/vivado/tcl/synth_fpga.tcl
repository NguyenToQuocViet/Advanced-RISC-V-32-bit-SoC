# ==========================================
# synth_fpga.tcl — Full synthesis fpga_top for KV260
# ==========================================
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../../..]]
file mkdir [file join $repo_root build]
cd [file join $repo_root build]
create_project -in_memory -part xck26-sfvc784-2LV-c

# Packages
read_verilog -sv {
    ../rtl/cpu/cache/cache_pkg.sv
    ../rtl/cpu/cache/axi_pkg.sv
    ../rtl/cpu/core/cpu_pkg.sv
}

# 5-stage core
read_verilog -sv {
    ../rtl/cpu/core/riscv_core.sv
    ../rtl/cpu/core/fcu.sv
    ../rtl/cpu/core/dbp.sv
    ../rtl/cpu/core/if_id_pipeline.sv
    ../rtl/cpu/core/cu.sv
    ../rtl/cpu/core/rf.sv
    ../rtl/cpu/core/immgen.sv
    ../rtl/cpu/core/id_ex_pipeline.sv
    ../rtl/cpu/core/alu.sv
    ../rtl/cpu/core/alu_operand_mux.sv
    ../rtl/cpu/core/fu.sv
    ../rtl/cpu/core/fwd_mux.sv
    ../rtl/cpu/core/hdu.sv
    ../rtl/cpu/core/hazard_ctrl.sv
    ../rtl/cpu/core/bru.sv
    ../rtl/cpu/core/mispredict_reg.sv
    ../rtl/cpu/core/ex_mem_pipeline.sv
    ../rtl/cpu/core/lsu.sv
    ../rtl/cpu/core/mem_wb_pipeline.sv
    ../rtl/cpu/core/wb.sv
}

# Cache subsystem
read_verilog -sv {
    ../rtl/cpu/cache/cache_subsystem.sv
    ../rtl/cpu/cache/icache.sv
    ../rtl/cpu/cache/dcache.sv
    ../rtl/cpu/cache/write_buffer.sv
    ../rtl/cpu/cache/bus_arbiter.sv
}

# SoC
read_verilog -sv ../rtl/cpu/riscv_soc.sv

# FPGA wrapper
read_verilog -sv {
    ../rtl/fpga/uart_tx.sv
    ../rtl/fpga/uart_axi.sv
    ../rtl/fpga/axi_bram.sv
    ../rtl/fpga/axi_decoder.sv
    ../rtl/fpga/fpga_top.sv
}

# Constraints
read_xdc ../constrs/kv260.xdc

# Synthesis
synth_design -top fpga_top -flatten_hierarchy rebuilt

# Reports
report_utilization -file fpga_synth_util.rpt
report_timing_summary -file fpga_synth_timing.rpt

puts "=== Synthesis complete ==="
