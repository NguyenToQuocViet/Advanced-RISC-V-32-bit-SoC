# Simulation script
set project_name [file tail [file dirname [pwd]]]

open_project ${project_name}.xpr

# Set simulation runtime (run all)
set_property -name {xsim.simulate.runtime} -value {-all} -objects [get_filesets sim_1]

# Launch simulation
puts "========== Launching Simulation =========="
launch_simulation

# Run simulation
run all

puts "SUCCESS: Simulation completed"

# Keep GUI open if in GUI mode
if {[string match "*gui*" $rdi::mode]} {
    puts "Waveform window opened. Close manually when done."
} else {
    close_sim
    close_project
}
