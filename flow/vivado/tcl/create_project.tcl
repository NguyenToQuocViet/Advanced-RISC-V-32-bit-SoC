# Persistent Vivado project from a repository filelist.

set target [expr {[llength $argv] ? [lindex $argv 0] : "fpga7"}]
if {$target ni {legacy5 fpga7}} {
    error "Vivado target must be legacy5 or fpga7"
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../../..]]
set project_dir [file join $repo_root build vivado $target project]
set top [expr {$target eq "legacy5" ? "riscv_soc" : "riscv_soc_7stg"}]

source [file join $script_dir filelist_utils.tcl]
parse_repo_filelist $repo_root $target sources defines

create_project $target $project_dir -force -part xck26-sfvc784-2LV-c
add_files -norecurse $sources
set_property verilog_define $defines [current_fileset]
set_property file_type SystemVerilog [get_files -filter {NAME =~ *.sv}]
add_files -fileset constrs_1 -norecurse [file join $repo_root constrs timing.xdc]
set_property top $top [current_fileset]
update_compile_order -fileset sources_1
puts "SUCCESS: ${target} project created at ${project_dir}"
close_project
