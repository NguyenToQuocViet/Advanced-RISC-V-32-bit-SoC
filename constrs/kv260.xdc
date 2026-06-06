# ==============================================================================
# KV260 Pin Constraints — FPGA Demo
# Clock (pl_clk0) and Reset (pl_resetn0) come from PS via Block Design.
# Only UART TX needs physical pin constraint.
# ==============================================================================

# --- UART TX: PMOD J2 pin 1 (HDA11) ---
set_property -dict { PACKAGE_PIN H12 IOSTANDARD LVCMOS33 } [get_ports uart_tx_o_0]

# --- Timing: 100MHz from PS pl_clk0 (auto-derived by Block Design) ---
# No manual clock constraint needed — Vivado derives it from PS config.
