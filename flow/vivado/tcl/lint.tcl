# RTL Linting script using Vivado
set project_name [file tail [file dirname [pwd]]]
open_project ${project_name}.xpr

# Create reports directory if not exists
file mkdir reports

puts "========== Running RTL Linting (Check Synthesizability) =========="

# Chạy Elaboration với chế độ phân tích logic sâu
synth_design -rtl -name rtl_lint

# 1. Kiểm tra Latch - "Kẻ thù" của thiết kế RTL
set latches [get_cells -hierarchical -filter { IS_LATCH == "TRUE" }]
if {[llength $latches] > 0} {
    puts "CRITICAL WARNING: Latches detected in design: $latches"
} else {
    puts "SUCCESS: No latches detected."
}

# 2. Kiểm tra các quy tắc thiết kế (Methodology)
report_methodology -file reports/lint_methodology.txt
puts "Methodology report generated: work/reports/lint_methodology.txt"

# 3. Kiểm tra các tín hiệu không được sử dụng hoặc lơ lửng
report_drc -checks {HDRC-1} -file reports/lint_drc.txt

close_design
close_project
