# Synthesis script
set project_name [file tail [file dirname [pwd]]]

open_project ${project_name}.xpr

# Create reports directory
file mkdir reports

# Run synthesis
puts "========== Running Synthesis =========="
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Check result
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    exit 1
}

# Generate reports
open_run synth_1
report_utilization -file reports/utilization_synth.txt
report_timing_summary -file reports/timing_synth.txt

puts "SUCCESS: Synthesis completed"
puts "Reports: work/reports/"

close_project
