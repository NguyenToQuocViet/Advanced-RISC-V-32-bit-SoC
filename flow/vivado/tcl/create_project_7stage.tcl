# ==========================================
# create_project_7stage.tcl
# ==========================================
set project_name "soc_7stage"
set project_dir  "vivado_soc_7stage"

# Tao project 7-stage stable (ghi de neu da ton tai)
create_project ${project_name} ${project_dir} -force -part xck26-sfvc784-2LV-c

# ------------------------------------------------------------------
# RTL sources - 7-stage only
# ------------------------------------------------------------------

# Packages truoc
add_files -norecurse rtl/cpu/core/cpu_pkg.sv
add_files -norecurse rtl/cpu/cache/cache_pkg.sv
add_files -norecurse rtl/cpu/cache/axi_pkg.sv

# SRAM wrappers
add_files -norecurse rtl/lib/sram_1rw.sv
add_files -norecurse rtl/lib/sram_1r1w.sv

# Core 7-stage
add_files -norecurse rtl/cpu/core/riscv_core_7stg.sv
add_files -norecurse rtl/cpu/core/hazard_ctrl_7stg.sv
add_files -norecurse rtl/cpu/core/mispredict_reg.sv
add_files -norecurse rtl/cpu/core/hdu_7stg.sv
add_files -norecurse rtl/cpu/core/fcu1.sv
add_files -norecurse rtl/cpu/core/if1_if2_pipeline.sv
add_files -norecurse rtl/cpu/core/dbp_7stg.sv
add_files -norecurse rtl/cpu/core/fcu2.sv
add_files -norecurse rtl/cpu/core/if2_id_pipeline.sv
add_files -norecurse rtl/cpu/core/cu.sv
add_files -norecurse rtl/cpu/core/rf.sv
add_files -norecurse rtl/cpu/core/immgen.sv
add_files -norecurse rtl/cpu/core/id_ex_pipeline.sv
add_files -norecurse rtl/cpu/core/fu_7stg.sv
add_files -norecurse rtl/cpu/core/fwd_mux_7stg.sv
add_files -norecurse rtl/cpu/core/alu_operand_mux.sv
add_files -norecurse rtl/cpu/core/alu.sv
add_files -norecurse rtl/cpu/core/bru.sv
add_files -norecurse rtl/cpu/core/ex_mem1_pipeline.sv
add_files -norecurse rtl/cpu/core/lsu1.sv
add_files -norecurse rtl/cpu/core/mem1_mem2_pipeline.sv
add_files -norecurse rtl/cpu/core/lsu2.sv
add_files -norecurse rtl/cpu/core/mem2_wb_pipeline.sv
add_files -norecurse rtl/cpu/core/wb.sv

# Cache subsystem 7-stage
add_files -norecurse rtl/cpu/cache/icache_7stg.sv
add_files -norecurse rtl/cpu/cache/dcache_7stg.sv
add_files -norecurse rtl/cpu/cache/write_buffer.sv
add_files -norecurse rtl/cpu/cache/bus_arbiter.sv
add_files -norecurse rtl/cpu/cache/cache_subsystem_7stg.sv

# Top-level SoC 7-stage
add_files -norecurse rtl/cpu/riscv_soc_7stg.sv

# Constraints
add_files -fileset constrs_1 -norecurse constrs/timing.xdc

# Ep kieu SystemVerilog cho RTL
set_property file_type SystemVerilog [get_files -filter {NAME =~ *.sv}]

# ------------------------------------------------------------------
# Testbench files
# ------------------------------------------------------------------
add_files -fileset sim_1 -norecurse tb/direct_test/axi_slave_model.sv
add_files -fileset sim_1 -norecurse tb/riscv_test/rv32ui_soc_7stg_tb.sv
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] -filter {NAME =~ *.sv}]

# Top module
set_property top riscv_soc_7stg [current_fileset]
set_property top rv32ui_soc_7stg_tb [get_filesets sim_1]

# Thu tu compile
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "SUCCESS: 7-stage project created with explicit source list."
puts "Open with: vivado ${project_dir}/${project_name}.xpr"
close_project
