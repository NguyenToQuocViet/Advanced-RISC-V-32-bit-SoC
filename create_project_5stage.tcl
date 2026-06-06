# ==========================================
# create_project_5stage.tcl
# ==========================================
set project_name [file tail [file dirname [pwd]]]

# Tao project 5-stage stable (ghi de neu da ton tai)
create_project ${project_name} . -force -part xck26-sfvc784-2LV-c

# ------------------------------------------------------------------
# RTL sources - 5-stage only
# ------------------------------------------------------------------

# Packages truoc
add_files -norecurse ../rtl/cpu/cache/axi_pkg.sv
add_files -norecurse ../rtl/cpu/cache/cache_pkg.sv
add_files -norecurse ../rtl/cpu/core/cpu_pkg.sv

# Core 5-stage
add_files -norecurse ../rtl/cpu/core/alu.sv
add_files -norecurse ../rtl/cpu/core/alu_operand_mux.sv
add_files -norecurse ../rtl/cpu/core/bru.sv
add_files -norecurse ../rtl/cpu/core/cu.sv
add_files -norecurse ../rtl/cpu/core/dbp.sv
add_files -norecurse ../rtl/cpu/core/ex_mem_pipeline.sv
add_files -norecurse ../rtl/cpu/core/fcu.sv
add_files -norecurse ../rtl/cpu/core/fu.sv
add_files -norecurse ../rtl/cpu/core/hdu.sv
add_files -norecurse ../rtl/cpu/core/id_ex_pipeline.sv
add_files -norecurse ../rtl/cpu/core/if_id_pipeline.sv
add_files -norecurse ../rtl/cpu/core/immgen.sv
add_files -norecurse ../rtl/cpu/core/lsu.sv
add_files -norecurse ../rtl/cpu/core/mem_wb_pipeline.sv
add_files -norecurse ../rtl/cpu/core/rf.sv
add_files -norecurse ../rtl/cpu/core/riscv_core.sv
add_files -norecurse ../rtl/cpu/core/wb.sv

# Cache subsystem 5-stage
add_files -norecurse ../rtl/cpu/cache/bus_arbiter.sv
add_files -norecurse ../rtl/cpu/cache/cache_subsystem.sv
add_files -norecurse ../rtl/cpu/cache/dcache.sv
add_files -norecurse ../rtl/cpu/cache/icache.sv
add_files -norecurse ../rtl/cpu/cache/write_buffer.sv

# Top-level SoC
add_files -norecurse ../rtl/cpu/riscv_soc.sv

# Constraints
add_files -fileset constrs_1 -norecurse ../constrs/timing.xdc

# Ep kieu SystemVerilog cho RTL/TB
set_property file_type SystemVerilog [get_files -filter {NAME =~ *.sv}]

# ------------------------------------------------------------------
# Testbench files
# ------------------------------------------------------------------
if {[file exists ../tb/direct_test]} {
    add_files -fileset sim_1 ../tb/direct_test
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] -filter {NAME =~ *.sv}]
}
if {[file exists ../tb/riscv_test/rv32ui_tb.sv]} {
    add_files -fileset sim_1 ../tb/riscv_test/rv32ui_tb.sv
    set_property file_type SystemVerilog [get_files ../tb/riscv_test/rv32ui_tb.sv]
}

# Thu tu compile
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "SUCCESS: 5-stage project created with explicit source list."
close_project
