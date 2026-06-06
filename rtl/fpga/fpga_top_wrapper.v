// Verilog wrapper for fpga_top (SystemVerilog module)
// Required because Vivado BD does not accept SV files as module reference top.
// This file is plain Verilog - BD can reference it without restriction.

module fpga_top_wrapper (
    input  wire clk,
    input  wire rst_n,
    output wire uart_tx_o
);
    fpga_top u_fpga_top (
        .clk       (clk),
        .rst_n     (rst_n),
        .uart_tx_o (uart_tx_o)
    );
endmodule
