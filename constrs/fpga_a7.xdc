## Clock - 100MHz onboard oscillator
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## Reset - red RESET button, active-low, connected directly to rst_n
set_property PACKAGE_PIN C2 [get_ports rst_n_pad]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n_pad]

## UART TX - via onboard FTDI USB-UART bridge
set_property PACKAGE_PIN D10 [get_ports uart_tx_o]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_o]