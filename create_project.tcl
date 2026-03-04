# Auto-generated for project: CPU_RISC_V
# Project creation script
set project_name [lindex $::argv 0]
set part_name "xc7z020clg484-1"

set rtl_dir    "../rtl"
set tb_dir     "../tb"
set work_dir   "."

# Create project
create_project -force $project_name $work_dir -part $part_name

# Add RTL files (both .v and .sv)
set rtl_files [concat [glob -nocomplain ${rtl_dir}/*.v] [glob -nocomplain ${rtl_dir}/*.sv]]
if {[llength $rtl_files] > 0} {
    add_files $rtl_files
}

# Add testbench files
set tb_files [concat [glob -nocomplain ${tb_dir}/*.v] [glob -nocomplain ${tb_dir}/*.sv]]
if {[llength $tb_files] > 0} {
    add_files -fileset sim_1 $tb_files
}

# Set SystemVerilog file type for .sv files
foreach file [get_files *.sv] {
    set_property file_type SystemVerilog $file
}

# Update compile order
update_compile_order -fileset sources_1

puts "Project $project_name created successfully"
exit
