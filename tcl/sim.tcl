# ==========================================
# sim.tcl
# ==========================================
set project_name [file tail [file dirname [pwd]]]
open_project ${project_name}.xpr

# Nếu truyền tên TB qua -tclargs thì override, không thì auto
if {[llength $argv] > 0} {
    set tb_top [lindex $argv 0]
    puts "========== Testbench: $tb_top =========="

    # Tim TB file trong ca 2 thu muc: tb/direct_test/ va tb/riscv_test/
    set search_dirs [list "../tb/direct_test" "../tb/riscv_test"]
    set tb_file ""
    foreach dir $search_dirs {
        set candidate [file normalize "${dir}/${tb_top}.sv"]
        if {[file exists $candidate]} {
            set tb_file $candidate
            break
        }
    }
    if {$tb_file eq ""} {
        error "Khong tim thay ${tb_top}.sv trong tb/direct_test/ hoac tb/riscv_test/"
    }

    if {[llength [get_files -quiet $tb_file]] == 0} {
        puts "Adding $tb_file to sim_1 fileset..."
        add_files -fileset sim_1 $tb_file
        set_property file_type SystemVerilog [get_files $tb_file]
    }

    set_property source_mgmt_mode None [current_project]
    set_property top_auto_set 0 [get_filesets sim_1]
    set_property top $tb_top [get_filesets sim_1]
    update_compile_order -fileset sim_1
} else {
    set_property top_auto_set 1 [get_filesets sim_1]
    update_compile_order -fileset sim_1
}

# Cấu hình chạy mô phỏng đến khi kết thúc lệnh $finish
set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]

puts "========== Launching Simulation =========="
launch_simulation

puts "SUCCESS: Simulation completed"

# Giữ GUI mở nếu chạy chế độ GUI (make sim)
if {[string match "*gui*" $rdi::mode]} {
    puts "Waveform window opened. Close manually when done."
} else {
    close_sim
    close_project
}
