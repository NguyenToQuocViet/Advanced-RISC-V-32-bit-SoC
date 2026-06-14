# ==============================================================================
# KV260 Pin Constraints — FPGA Demo
# Clock (pl_clk0) and Reset (pl_resetn0) come from PS via Block Design.
# Only UART TX needs physical pin constraint.
# ==============================================================================

# --- UART TX: PMOD J2 pin 1 (HDA11) ---
set_property -dict {PACKAGE_PIN H12 IOSTANDARD LVCMOS33} [get_ports uart_tx_o_0]

# --- Timing: 100MHz from PS pl_clk0 (auto-derived by Block Design) ---
# No manual clock constraint needed — Vivado derives it from PS config.

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/clk]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[0]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[10]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[11]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[12]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[13]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[14]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[15]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[16]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[17]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[18]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[19]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[1]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[20]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[21]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[22]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[23]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[24]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[25]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[26]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[27]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[28]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[29]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[2]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[30]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[31]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[3]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[4]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[5]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[6]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[7]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[8]} {design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_araddr[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 5 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_arready design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_m_arvalid design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_s1_awready design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_s1_awvalid design_1_i/fpga_top_wrapper_0/inst/u_fpga_top/dbg_uart_tx]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_0_clk]
