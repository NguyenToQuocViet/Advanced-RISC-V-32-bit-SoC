# Vivado synthesis entrypoint for repository filelists.

if {[llength $argv] != 1} {
    error "Usage: synth_filelist.tcl <legacy5|fpga7>"
}

set target [lindex $argv 0]
if {$target ni {legacy5 fpga7}} {
    error "Vivado target must be legacy5 or fpga7"
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../../..]]
set build_dir [file join $repo_root build vivado $target]
set report_dir [file join $build_dir reports]
set part xck26-sfvc784-2LV-c
set top [expr {$target eq "legacy5" ? "riscv_soc" : "riscv_soc_7stg"}]

source [file join $script_dir filelist_utils.tcl]
parse_repo_filelist $repo_root $target sources defines

file mkdir $report_dir
create_project -in_memory -part $part
set_property verilog_define $defines [current_fileset]
read_verilog -sv $sources
read_xdc [file join $repo_root constrs timing.xdc]
synth_design -top $top -flatten_hierarchy rebuilt
report_utilization -file [file join $report_dir utilization.rpt]
report_timing_summary -file [file join $report_dir timing_summary.rpt]
write_checkpoint -force [file join $build_dir post_synth.dcp]
puts "SUCCESS: ${target} synthesis completed"
