# Implementation script
set project_name [file tail [file dirname [pwd]]]

open_project ${project_name}.xpr

# Create reports directory
file mkdir reports

puts "Configuring aggressive exploration directives for impl_1..."

# 1. Tối ưu hóa Logic cực đại
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

# 2. Thuật toán xếp chỗ (Placement) quét không gian rộng
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

# 3. Kích hoạt vũ khí bí mật: Phys Opt Design (Tối ưu vật lý TRƯỚC đi dây)
# Cho phép Vivado nhân bản thanh ghi (Register Replication) để giảm fan-out
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# 4. Thuật toán đi dây (Routing) vét cạn
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]

# 5. Kích hoạt Post-Route Phys Opt Design (Tối ưu vật lý SAU đi dây)
# Gỡ dây lỗi và đi lại nếu phát hiện rớt Timing (Negative Slack)
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
# ==============================================================================

# Run implementation
puts "========== Running Implementation =========="
reset_run impl_1

# Tối đa hóa luồng xử lý CPU của máy tính bạn. 
# Nếu PC của bạn có nhiều nhân hơn, hãy đổi -jobs 4 thành -jobs 8 hoặc 16.
launch_runs impl_1 -jobs 8
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
puts "Reports: reports/"

close_project
