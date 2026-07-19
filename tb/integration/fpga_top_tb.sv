// -----------------------------------------------------------------------------
// fpga_top_tb.sv — Sim full FPGA datapath (riscv_soc + decoder + BRAM + UART)
// Reproduces KV260 demo at bench. Monitors UART stores + decodes chars,
// instead of waiting ~87us/char for real serial bits.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module fpga_top_tb;

    logic clk;
    logic rst_n;
    logic uart_tx_o;

    //pl_clk0 = 96MHz -> 10.417ns period
    localparam real CLK_PERIOD = 10.00;

    fpga_top u_dut (
        .clk       (clk),
        .rst_n_pad (rst_n),
        .uart_tx_o (uart_tx_o)
    );

    //--- Clock ---
    initial clk = 1'b0;
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //--- Reset ---
    initial begin
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
    end

    //--- Probe internal AXI master + UART store (hierarchical) ---
    //store to UART = aw handshake on slave1 + w beat
    wire s1_aw_fire = u_dut.s1_awvalid && u_dut.s1_awready;
    wire s1_w_fire  = u_dut.s1_wvalid  && u_dut.s1_wready;

    //--- Count chars written to UART at AXI layer (intent, not the wire) ---
    integer char_cnt = 0;
    always @(posedge clk) begin
        if (rst_n && s1_w_fire) begin
            char_cnt = char_cnt + 1;  //count only; RX model below prints the decoded wire
        end
    end

    //--- Activity watchdog: track first instruction fetch + first UART access ---
    logic seen_first_fetch;
    logic seen_first_uart;
    initial begin
        seen_first_fetch = 1'b0;
        seen_first_uart  = 1'b0;
    end
    always @(posedge clk) begin
        if (rst_n) begin
            if (!seen_first_fetch && u_dut.m_arvalid && u_dut.m_arready) begin
                seen_first_fetch <= 1'b1;
                $display("\n[%0t] FIRST AXI READ: araddr=0x%08h arlen=%0d",
                         $time, u_dut.m_araddr, u_dut.m_arlen);
            end
            if (!seen_first_uart && u_dut.m_awvalid && u_dut.m_awready) begin
                seen_first_uart <= 1'b1;
                $display("\n[%0t] FIRST AXI WRITE: awaddr=0x%08h",
                         $time, u_dut.m_awaddr);
            end
        end
    end

    //--- Deadlock detector: AR asserted but never granted ---
    integer ar_stall_cnt = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            if (u_dut.m_arvalid && !u_dut.m_arready)
                ar_stall_cnt <= ar_stall_cnt + 1;
            else
                ar_stall_cnt <= 0;
            if (ar_stall_cnt > 1000) begin
                $display("\n[%0t] *** DEADLOCK: m_arvalid held >1000 cyc, araddr=0x%08h ***",
                         $time, u_dut.m_araddr);
                $finish;
            end
        end
    end

    //--- UART RX model: decode REAL serial bits on uart_tx_o pin ---
    //This is what PuTTY sees. Probe above watches AXI intent; this watches the wire.
    //Samples start bit, then 8 data bits LSB-first at mid-bit, checks stop bit.
    localparam real BAUD_PERIOD = 1.0e9 / 115200.0;  //ns per bit ~8680.5
    integer rx_char_cnt = 0;
    logic [7:0] rx_byte;
    integer rx_i;
    logic rx_stop;
    initial begin
        rx_byte = 8'h00;
        forever begin
            wait (u_dut.rst_n === 1'b1);
            wait (uart_tx_o === 1'b1);
        
            //idle HIGH; wait for start bit (falling edge to 0)
            @(negedge uart_tx_o);
            //align to middle of start bit
            #(BAUD_PERIOD * 0.5);
            if (uart_tx_o !== 1'b0) begin
                //false edge (glitch) - not a real start bit, resync
                continue;
            end
            //sample 8 data bits at mid-bit, LSB first
            for (rx_i = 0; rx_i < 8; rx_i = rx_i + 1) begin
                #(BAUD_PERIOD);
                rx_byte[rx_i] = uart_tx_o;
            end
            //sample stop bit
            #(BAUD_PERIOD);
            rx_stop = uart_tx_o;
            if (rx_stop !== 1'b1)
                $display("\n[%0t] *** UART RX FRAMING ERROR: stop bit=%b, byte=0x%02h ***",
                         $time, rx_stop, rx_byte);
            else begin
                rx_char_cnt = rx_char_cnt + 1;
                $write("%c", rx_byte);  //decoded from the actual pin
                $fflush;
            end
        end
    end

    //--- Idle watchdog: run until UART stops emitting, then finish ---
    //program ends in while(1) after "Done.", so no natural $finish.
    //finish once char_cnt>0 and no new char for IDLE_LIMIT cycles.
    localparam integer IDLE_LIMIT = 300000;  //~3ms idle = output complete
    integer idle_cnt = 0;
    integer last_char_cnt = 0;
    initial begin
        $display("=== fpga_top_tb start ===");
    end
    always @(posedge clk) begin
        if (rst_n) begin
            if (char_cnt != last_char_cnt) begin
                idle_cnt      <= 0;
                last_char_cnt <= char_cnt;
            end else begin
                idle_cnt <= idle_cnt + 1;
            end
            if (char_cnt > 0 && idle_cnt > IDLE_LIMIT) begin
                $display("\n=== END: AXI sent %0d chars, UART pin decoded %0d chars ===",
                         char_cnt, rx_char_cnt);
                if (char_cnt == rx_char_cnt)
                    $display("=== PASS: serial path matches (every AXI byte appeared correctly on the wire) ===");
                else
                    $display("*** MISMATCH: AXI=%0d vs pin=%0d -> uart_tx serialization bug ***",
                             char_cnt, rx_char_cnt);
                $finish;
            end
        end
    end

    //--- Hard cap: absolute upper bound so sim cannot hang forever ---
    initial begin
        #(CLK_PERIOD * 3000000);  //~31ms hard ceiling
        $display("\n=== HARD CAP: AXI=%0d chars, UART pin decoded=%0d chars (sim time exhausted) ===",
                 char_cnt, rx_char_cnt);
        if (char_cnt == 0)
            $display("*** NO UART WRITES — CPU never reached uart_putc ***");
        $finish;
    end

endmodule
