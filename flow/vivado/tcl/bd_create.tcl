# bd_create.tcl - v2

set proj_dir [get_property DIRECTORY [current_project]]

# --- 1. Create Block Design ---
create_bd_design "design_1"
current_bd_design "design_1"

# --- 2. Add Zynq UltraScale+ MPSoC ---
set zynq [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0]

# Disable AXI GP0 master port
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {96} \
] $zynq

# --- 3. Add fpga_top_wrapper ---
set wrap [create_bd_cell -type module \
    -reference fpga_top_wrapper fpga_top_wrapper_0]

# --- 4. Wire clock and reset ---
connect_bd_net \
    [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
    [get_bd_pins fpga_top_wrapper_0/clk]

connect_bd_net \
    [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
    [get_bd_pins fpga_top_wrapper_0/rst_n]

# --- 5. Expose uart_tx_o ---
make_bd_pins_external [get_bd_pins fpga_top_wrapper_0/uart_tx_o]
set_property name uart_tx_o [get_bd_ports uart_tx_o_0]

# --- 6. Validate and save ---
validate_bd_design
save_bd_design

# --- 7. Generate wrapper and set as top ---
make_wrapper -files [get_files design_1.bd] -top

set wrapper_path \
    "$proj_dir/fpga_demo.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v"
add_files -norecurse $wrapper_path
set_property top design_1_wrapper [current_fileset]

puts "INFO: BD creation complete. Top = design_1_wrapper"
