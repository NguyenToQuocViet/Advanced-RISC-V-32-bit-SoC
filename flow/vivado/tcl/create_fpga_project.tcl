# ==========================================
# create_fpga_project.tcl — Create persistent Vivado project for fpga_top (KV260)
# Usage:
#   vivado -mode batch -source ../tcl/create_fpga_project.tcl
#   (creates project in work/fpga_demo/)
# Then open GUI:
#   vivado work/fpga_demo/fpga_demo.xpr
# ==========================================

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../../..]]
file mkdir [file join $repo_root build]
cd [file join $repo_root build]

set proj_name "fpga_demo"
set proj_dir  "fpga_demo"
set part      "xck26-sfvc784-2LV-c"

# Create project on disk
create_project $proj_name $proj_dir -part $part -force

# Packages
add_files -norecurse {
    ../rtl/cpu/cache/cache_pkg.sv
    ../rtl/cpu/cache/axi_pkg.sv
    ../rtl/cpu/core/cpu_pkg.sv
}

# 5-stage core
add_files -norecurse {
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
add_files -norecurse {
    ../rtl/cpu/cache/cache_subsystem.sv
    ../rtl/cpu/cache/icache.sv
    ../rtl/cpu/cache/dcache.sv
    ../rtl/cpu/cache/write_buffer.sv
    ../rtl/cpu/cache/bus_arbiter.sv
}

# SoC
add_files -norecurse ../rtl/cpu/riscv_soc.sv

# FPGA wrapper
add_files -norecurse {
    ../rtl/fpga/uart_tx.sv
    ../rtl/fpga/uart_axi.sv
    ../rtl/fpga/axi_bram.sv
    ../rtl/fpga/axi_decoder.sv
    ../rtl/fpga/fpga_top.sv
    ../rtl/fpga/fpga_top_wrapper.v
}

# Constraints
add_files -fileset constrs_1 -norecurse ../constrs/kv260.xdc

# Set top module
set_property top fpga_top [current_fileset]

# Set all SV files as SystemVerilog
set_property file_type SystemVerilog [get_files *.sv]

puts "=== Project created: $proj_dir/$proj_name.xpr ==="
puts "=== Open with: vivado $proj_dir/$proj_name.xpr ==="
