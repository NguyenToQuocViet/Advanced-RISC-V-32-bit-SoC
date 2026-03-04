# Implementation script
set project_name [file tail [file dirname [pwd]]]

open_project ${project_name}.xpr

# Create reports directory
file mkdir reports

# Run implementation
puts "========== Running Implementation =========="
reset_run impl_1
launch_runs impl_1 -jobs 4
wait_on_run impl_1

# Check result
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    exit 1
}

# Generate reports
open_run impl_1
report_utilization -file reports/utilization_impl.txt
report_timing_summary -file reports/timing_impl.txt
report_power -file reports/power.txt

puts "SUCCESS: Implementation completed"
puts "Reports: work/reports/"

close_project
