# Synthesis script
set project_name [file tail [file dirname [pwd]]]

open_project ${project_name}.xpr

# Create reports directory
file mkdir reports

# ==============================================================================
# CẤU HÌNH TỔNG HỢP (SYNTHESIS CONFIGURATION)
# ==============================================================================
puts "Configuring Out-Of-Context (OOC) mode for synth_1..."

# Bơm cờ -mode out_of_context vào quá trình synth_design.
# Kỹ thuật này ngắt toàn bộ các port chưa được gán chân (như bus AXI) khỏi I/O đệm, 
# giữ chúng lơ lửng bên trong chip để đo Fmax lõi một cách thuần túy.
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Run synthesis
puts "========== Running Synthesis =========="
reset_run synth_1

# Tối đa hóa luồng xử lý CPU (tăng từ 4 lên 8 jobs)
launch_runs synth_1 -jobs 8
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
puts "Reports: reports/"

close_project
