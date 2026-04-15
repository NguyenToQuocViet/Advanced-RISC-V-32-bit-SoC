# ==========================================
# create_project.tcl
# ==========================================
set project_name [file tail [file dirname [pwd]]]

# Tạo project (Ghi đè nếu đã tồn tại)
create_project ${project_name} . -force -part xck26-sfvc784-2LV-c

# 1. Nạp toàn bộ cây thư mục RTL và ép kiểu SystemVerilog
add_files ../rtl
add_files -fileset constrs_1 -norecurse ../constrs/timing.xdc
set_property file_type SystemVerilog [get_files -filter {NAME =~ *.sv}]

# 2. Nạp testbench: direct_test/ va riscv_test/ (axi_slave_model chi add 1 lan tu direct_test)
if {[file exists ../tb/direct_test]} {
    add_files -fileset sim_1 ../tb/direct_test
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] -filter {NAME =~ *.sv}]
}
if {[file exists ../tb/riscv_test/rv32ui_tb.sv]} {
    add_files -fileset sim_1 ../tb/riscv_test/rv32ui_tb.sv
    set_property file_type SystemVerilog [get_files ../tb/riscv_test/rv32ui_tb.sv]
}

# 3. Yêu cầu Vivado tự động tính toán thứ tự biên dịch (Tự nhận diện _pkg.sv)
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "SUCCESS: Project created and source files added recursively."
close_project
