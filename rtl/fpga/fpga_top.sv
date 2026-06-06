module fpga_top (
    input  logic clk,
    input  logic rst_n,
    output logic uart_tx_o
);

    //--- AXI wires: riscv_soc master → decoder ---
    logic                  m_arvalid, m_arready;
    logic [31:0]           m_araddr;
    logic [7:0]            m_arlen;
    logic [2:0]            m_arsize;
    logic [1:0]            m_arburst;
    logic                  m_rvalid, m_rready;
    logic [31:0]           m_rdata;
    logic [1:0]            m_rresp;
    logic                  m_rlast;
    logic                  m_awvalid, m_awready;
    logic [31:0]           m_awaddr;
    logic [7:0]            m_awlen;
    logic [2:0]            m_awsize;
    logic [1:0]            m_awburst;
    logic                  m_wvalid, m_wready;
    logic [31:0]           m_wdata;
    logic [3:0]            m_wstrb;
    logic                  m_wlast;
    logic                  m_bvalid, m_bready;
    logic [1:0]            m_bresp;

    //--- AXI wires: decoder → slave 0 (BRAM) ---
    logic                  s0_arvalid, s0_arready;
    logic [31:0]           s0_araddr;
    logic [7:0]            s0_arlen;
    logic [2:0]            s0_arsize;
    logic [1:0]            s0_arburst;
    logic                  s0_rvalid, s0_rready;
    logic [31:0]           s0_rdata;
    logic [1:0]            s0_rresp;
    logic                  s0_rlast;
    logic                  s0_awvalid, s0_awready;
    logic [31:0]           s0_awaddr;
    logic [7:0]            s0_awlen;
    logic [2:0]            s0_awsize;
    logic [1:0]            s0_awburst;
    logic                  s0_wvalid, s0_wready;
    logic [31:0]           s0_wdata;
    logic [3:0]            s0_wstrb;
    logic                  s0_wlast;
    logic                  s0_bvalid, s0_bready;
    logic [1:0]            s0_bresp;

    //--- AXI wires: decoder → slave 1 (UART) ---
    logic                  s1_arvalid, s1_arready;
    logic [31:0]           s1_araddr;
    logic [7:0]            s1_arlen;
    logic [2:0]            s1_arsize;
    logic [1:0]            s1_arburst;
    logic                  s1_rvalid, s1_rready;
    logic [31:0]           s1_rdata;
    logic [1:0]            s1_rresp;
    logic                  s1_rlast;
    logic                  s1_awvalid, s1_awready;
    logic [31:0]           s1_awaddr;
    logic [7:0]            s1_awlen;
    logic [2:0]            s1_awsize;
    logic [1:0]            s1_awburst;
    logic                  s1_wvalid, s1_wready;
    logic [31:0]           s1_wdata;
    logic [3:0]            s1_wstrb;
    logic                  s1_wlast;
    logic                  s1_bvalid, s1_bready;
    logic [1:0]            s1_bresp;

    //--- riscv_soc ---
    logic fence_done;

    riscv_soc u_soc (
        .clk            (clk),
        .rst_n          (rst_n),
        .fence          (1'b0),
        .fence_done     (fence_done),
        .m_axi_arvalid  (m_arvalid),
        .m_axi_arready  (m_arready),
        .m_axi_araddr   (m_araddr),
        .m_axi_arlen    (m_arlen),
        .m_axi_arsize   (m_arsize),
        .m_axi_arburst  (m_arburst),
        .m_axi_rvalid   (m_rvalid),
        .m_axi_rready   (m_rready),
        .m_axi_rdata    (m_rdata),
        .m_axi_rresp    (m_rresp),
        .m_axi_rlast    (m_rlast),
        .m_axi_awvalid  (m_awvalid),
        .m_axi_awready  (m_awready),
        .m_axi_awaddr   (m_awaddr),
        .m_axi_awlen    (m_awlen),
        .m_axi_awsize   (m_awsize),
        .m_axi_awburst  (m_awburst),
        .m_axi_wvalid   (m_wvalid),
        .m_axi_wready   (m_wready),
        .m_axi_wdata    (m_wdata),
        .m_axi_wstrb    (m_wstrb),
        .m_axi_wlast    (m_wlast),
        .m_axi_bvalid   (m_bvalid),
        .m_axi_bready   (m_bready),
        .m_axi_bresp    (m_bresp)
    );

    //--- AXI Decoder ---
    axi_decoder u_decoder (
        .clk        (clk),
        .rst_n      (rst_n),
        //master
        .m_arvalid  (m_arvalid),
        .m_arready  (m_arready),
        .m_araddr   (m_araddr),
        .m_arlen    (m_arlen),
        .m_arsize   (m_arsize),
        .m_arburst  (m_arburst),
        .m_rvalid   (m_rvalid),
        .m_rready   (m_rready),
        .m_rdata    (m_rdata),
        .m_rresp    (m_rresp),
        .m_rlast    (m_rlast),
        .m_awvalid  (m_awvalid),
        .m_awready  (m_awready),
        .m_awaddr   (m_awaddr),
        .m_awlen    (m_awlen),
        .m_awsize   (m_awsize),
        .m_awburst  (m_awburst),
        .m_wvalid   (m_wvalid),
        .m_wready   (m_wready),
        .m_wdata    (m_wdata),
        .m_wstrb    (m_wstrb),
        .m_wlast    (m_wlast),
        .m_bvalid   (m_bvalid),
        .m_bready   (m_bready),
        .m_bresp    (m_bresp),
        //slave 0 - BRAM
        .s0_arvalid (s0_arvalid),
        .s0_arready (s0_arready),
        .s0_araddr  (s0_araddr),
        .s0_arlen   (s0_arlen),
        .s0_arsize  (s0_arsize),
        .s0_arburst (s0_arburst),
        .s0_rvalid  (s0_rvalid),
        .s0_rready  (s0_rready),
        .s0_rdata   (s0_rdata),
        .s0_rresp   (s0_rresp),
        .s0_rlast   (s0_rlast),
        .s0_awvalid (s0_awvalid),
        .s0_awready (s0_awready),
        .s0_awaddr  (s0_awaddr),
        .s0_awlen   (s0_awlen),
        .s0_awsize  (s0_awsize),
        .s0_awburst (s0_awburst),
        .s0_wvalid  (s0_wvalid),
        .s0_wready  (s0_wready),
        .s0_wdata   (s0_wdata),
        .s0_wstrb   (s0_wstrb),
        .s0_wlast   (s0_wlast),
        .s0_bvalid  (s0_bvalid),
        .s0_bready  (s0_bready),
        .s0_bresp   (s0_bresp),
        //slave 1 - UART
        .s1_arvalid (s1_arvalid),
        .s1_arready (s1_arready),
        .s1_araddr  (s1_araddr),
        .s1_arlen   (s1_arlen),
        .s1_arsize  (s1_arsize),
        .s1_arburst (s1_arburst),
        .s1_rvalid  (s1_rvalid),
        .s1_rready  (s1_rready),
        .s1_rdata   (s1_rdata),
        .s1_rresp   (s1_rresp),
        .s1_rlast   (s1_rlast),
        .s1_awvalid (s1_awvalid),
        .s1_awready (s1_awready),
        .s1_awaddr  (s1_awaddr),
        .s1_awlen   (s1_awlen),
        .s1_awsize  (s1_awsize),
        .s1_awburst (s1_awburst),
        .s1_wvalid  (s1_wvalid),
        .s1_wready  (s1_wready),
        .s1_wdata   (s1_wdata),
        .s1_wstrb   (s1_wstrb),
        .s1_wlast   (s1_wlast),
        .s1_bvalid  (s1_bvalid),
        .s1_bready  (s1_bready),
        .s1_bresp   (s1_bresp)
    );

    //--- AXI BRAM ---
    axi_bram #(
        .MEM_DEPTH  (16384),
        .INIT_FILE0 ("/home/quocviet/Project/Advanced-RISC-V-32-bit-SoC/sw/hello0.mem"),
        .INIT_FILE1 ("/home/quocviet/Project/Advanced-RISC-V-32-bit-SoC/sw/hello1.mem"),
        .INIT_FILE2 ("/home/quocviet/Project/Advanced-RISC-V-32-bit-SoC/sw/hello2.mem"),
        .INIT_FILE3 ("/home/quocviet/Project/Advanced-RISC-V-32-bit-SoC/sw/hello3.mem")
    ) u_bram (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_arvalid  (s0_arvalid),
        .s_axi_arready  (s0_arready),
        .s_axi_araddr   (s0_araddr),
        .s_axi_arlen    (s0_arlen),
        .s_axi_arsize   (s0_arsize),
        .s_axi_arburst  (s0_arburst),
        .s_axi_rvalid   (s0_rvalid),
        .s_axi_rready   (s0_rready),
        .s_axi_rdata    (s0_rdata),
        .s_axi_rresp    (s0_rresp),
        .s_axi_rlast    (s0_rlast),
        .s_axi_awvalid  (s0_awvalid),
        .s_axi_awready  (s0_awready),
        .s_axi_awaddr   (s0_awaddr),
        .s_axi_awlen    (s0_awlen),
        .s_axi_awsize   (s0_awsize),
        .s_axi_awburst  (s0_awburst),
        .s_axi_wvalid   (s0_wvalid),
        .s_axi_wready   (s0_wready),
        .s_axi_wdata    (s0_wdata),
        .s_axi_wstrb    (s0_wstrb),
        .s_axi_wlast    (s0_wlast),
        .s_axi_bvalid   (s0_bvalid),
        .s_axi_bready   (s0_bready),
        .s_axi_bresp    (s0_bresp)
    );

    //--- UART AXI ---
    uart_axi #(.CLK_FREQ(96_000_000)) u_uart (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awvalid  (s1_awvalid),
        .s_axi_awready  (s1_awready),
        .s_axi_awaddr   (s1_awaddr),
        .s_axi_awlen    (s1_awlen),
        .s_axi_awsize   (s1_awsize),
        .s_axi_awburst  (s1_awburst),
        .s_axi_wvalid   (s1_wvalid),
        .s_axi_wready   (s1_wready),
        .s_axi_wdata    (s1_wdata),
        .s_axi_wstrb    (s1_wstrb),
        .s_axi_wlast    (s1_wlast),
        .s_axi_bvalid   (s1_bvalid),
        .s_axi_bready   (s1_bready),
        .s_axi_bresp    (s1_bresp),
        .s_axi_arvalid  (s1_arvalid),
        .s_axi_arready  (s1_arready),
        .s_axi_araddr   (s1_araddr),
        .s_axi_arlen    (s1_arlen),
        .s_axi_arsize   (s1_arsize),
        .s_axi_arburst  (s1_arburst),
        .s_axi_rvalid   (s1_rvalid),
        .s_axi_rready   (s1_rready),
        .s_axi_rdata    (s1_rdata),
        .s_axi_rresp    (s1_rresp),
        .s_axi_rlast    (s1_rlast),
        .uart_tx_o      (uart_tx_o)
    );

endmodule
