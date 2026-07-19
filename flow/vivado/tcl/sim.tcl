# ==========================================
# sim.tcl
# ==========================================
set project_name [file tail [file dirname [pwd]]]
open_project ${project_name}.xpr
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../../..]]

# Nếu truyền tên TB qua -tclargs thì override, không thì auto
if {[llength $argv] > 0} {
    set tb_top [lindex $argv 0]
    puts "========== Testbench: $tb_top =========="

    # Search all first-party and ISA testbench groups.
    set search_dirs [list \
        [file join $repo_root tb unit] \
        [file join $repo_root tb integration] \
        [file join $repo_root tb models] \
        [file join $repo_root tb riscv_test]]
    set tb_file ""
    foreach dir $search_dirs {
        set candidate [file normalize "${dir}/${tb_top}.sv"]
        if {[file exists $candidate]} {
            set tb_file $candidate
            break
        }
    }
    if {$tb_file eq ""} {
        error "Cannot find ${tb_top}.sv in repository testbench groups"
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
