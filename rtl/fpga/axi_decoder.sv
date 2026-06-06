module axi_decoder
    import cache_pkg::*;
(
    input  logic clk,
    input  logic rst_n,

    //--- Master port (from riscv_soc) ---
    //AR
    input  logic                  m_arvalid,
    output logic                  m_arready,
    input  logic [ADDR_WIDTH-1:0] m_araddr,
    input  logic [7:0]            m_arlen,
    input  logic [2:0]            m_arsize,
    input  logic [1:0]            m_arburst,
    //R
    output logic                  m_rvalid,
    input  logic                  m_rready,
    output logic [DATA_WIDTH-1:0] m_rdata,
    output logic [1:0]            m_rresp,
    output logic                  m_rlast,
    //AW
    input  logic                  m_awvalid,
    output logic                  m_awready,
    input  logic [ADDR_WIDTH-1:0] m_awaddr,
    input  logic [7:0]            m_awlen,
    input  logic [2:0]            m_awsize,
    input  logic [1:0]            m_awburst,
    //W
    input  logic                  m_wvalid,
    output logic                  m_wready,
    input  logic [DATA_WIDTH-1:0] m_wdata,
    input  logic [STRB_WIDTH-1:0] m_wstrb,
    input  logic                  m_wlast,
    //B
    output logic                  m_bvalid,
    input  logic                  m_bready,
    output logic [1:0]            m_bresp,

    //--- Slave 0: BRAM (addr[31:28] == 4'h0) ---
    //AR
    output logic                  s0_arvalid,
    input  logic                  s0_arready,
    output logic [ADDR_WIDTH-1:0] s0_araddr,
    output logic [7:0]            s0_arlen,
    output logic [2:0]            s0_arsize,
    output logic [1:0]            s0_arburst,
    //R
    input  logic                  s0_rvalid,
    output logic                  s0_rready,
    input  logic [DATA_WIDTH-1:0] s0_rdata,
    input  logic [1:0]            s0_rresp,
    input  logic                  s0_rlast,
    //AW
    output logic                  s0_awvalid,
    input  logic                  s0_awready,
    output logic [ADDR_WIDTH-1:0] s0_awaddr,
    output logic [7:0]            s0_awlen,
    output logic [2:0]            s0_awsize,
    output logic [1:0]            s0_awburst,
    //W
    output logic                  s0_wvalid,
    input  logic                  s0_wready,
    output logic [DATA_WIDTH-1:0] s0_wdata,
    output logic [STRB_WIDTH-1:0] s0_wstrb,
    output logic                  s0_wlast,
    //B
    input  logic                  s0_bvalid,
    output logic                  s0_bready,
    input  logic [1:0]            s0_bresp,

    //--- Slave 1: UART (addr[31:28] == 4'h1) ---
    //AR
    output logic                  s1_arvalid,
    input  logic                  s1_arready,
    output logic [ADDR_WIDTH-1:0] s1_araddr,
    output logic [7:0]            s1_arlen,
    output logic [2:0]            s1_arsize,
    output logic [1:0]            s1_arburst,
    //R
    input  logic                  s1_rvalid,
    output logic                  s1_rready,
    input  logic [DATA_WIDTH-1:0] s1_rdata,
    input  logic [1:0]            s1_rresp,
    input  logic                  s1_rlast,
    //AW
    output logic                  s1_awvalid,
    input  logic                  s1_awready,
    output logic [ADDR_WIDTH-1:0] s1_awaddr,
    output logic [7:0]            s1_awlen,
    output logic [2:0]            s1_awsize,
    output logic [1:0]            s1_awburst,
    //W
    output logic                  s1_wvalid,
    input  logic                  s1_wready,
    output logic [DATA_WIDTH-1:0] s1_wdata,
    output logic [STRB_WIDTH-1:0] s1_wstrb,
    output logic                  s1_wlast,
    //B
    input  logic                  s1_bvalid,
    output logic                  s1_bready,
    input  logic [1:0]            s1_bresp
);

    //--- Address decode ---
    function automatic logic decode_sel(input logic [ADDR_WIDTH-1:0] addr);
        return (addr[31:28] == 4'h1) ? 1'b1 : 1'b0;
    endfunction

    //--- Read channel: latch sel on AR handshake ---
    logic ar_sel_r;
    logic ar_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_sel_r  <= 1'b0;
            ar_active <= 1'b0;
        end else begin
            if (!ar_active && m_arvalid && m_arready) begin
                ar_sel_r  <= decode_sel(m_araddr);
                ar_active <= 1'b1;
            end else if (ar_active && m_rvalid && m_rready && m_rlast) begin
                ar_active <= 1'b0;
            end
        end
    end

    //AR decode (combinational during handshake, latched after)
    logic ar_sel;
    assign ar_sel = ar_active ? ar_sel_r : decode_sel(m_araddr);

    //AR forward
    assign s0_arvalid = m_arvalid && !ar_sel;
    assign s1_arvalid = m_arvalid &&  ar_sel;
    assign s0_araddr  = m_araddr;
    assign s1_araddr  = m_araddr;
    assign s0_arlen   = m_arlen;
    assign s1_arlen   = m_arlen;
    assign s0_arsize  = m_arsize;
    assign s1_arsize  = m_arsize;
    assign s0_arburst = m_arburst;
    assign s1_arburst = m_arburst;
    assign m_arready  = ar_sel ? s1_arready : s0_arready;

    //R mux
    assign m_rvalid  = ar_sel_r ? s1_rvalid : s0_rvalid;
    assign m_rdata   = ar_sel_r ? s1_rdata  : s0_rdata;
    assign m_rresp   = ar_sel_r ? s1_rresp  : s0_rresp;
    assign m_rlast   = ar_sel_r ? s1_rlast  : s0_rlast;
    assign s0_rready = !ar_sel_r && m_rready;
    assign s1_rready =  ar_sel_r && m_rready;

    //--- Write channel: latch sel on AW handshake ---
    logic aw_sel_r;
    logic aw_active;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_sel_r  <= 1'b0;
            aw_active <= 1'b0;
        end else begin
            if (!aw_active && m_awvalid && m_awready) begin
                aw_sel_r  <= decode_sel(m_awaddr);
                aw_active <= 1'b1;
            end else if (aw_active && m_bvalid && m_bready) begin
                aw_active <= 1'b0;
            end
        end
    end

    logic aw_sel;
    assign aw_sel = aw_active ? aw_sel_r : decode_sel(m_awaddr);

    //AW forward
    assign s0_awvalid = m_awvalid && !aw_sel;
    assign s1_awvalid = m_awvalid &&  aw_sel;
    assign s0_awaddr  = m_awaddr;
    assign s1_awaddr  = m_awaddr;
    assign s0_awlen   = m_awlen;
    assign s1_awlen   = m_awlen;
    assign s0_awsize  = m_awsize;
    assign s1_awsize  = m_awsize;
    assign s0_awburst = m_awburst;
    assign s1_awburst = m_awburst;
    assign m_awready  = aw_sel ? s1_awready : s0_awready;

    //W forward (follows aw_sel_r)
    assign s0_wvalid = !aw_sel_r && m_wvalid;
    assign s1_wvalid =  aw_sel_r && m_wvalid;
    assign s0_wdata  = m_wdata;
    assign s1_wdata  = m_wdata;
    assign s0_wstrb  = m_wstrb;
    assign s1_wstrb  = m_wstrb;
    assign s0_wlast  = m_wlast;
    assign s1_wlast  = m_wlast;
    assign m_wready  = aw_sel_r ? s1_wready : s0_wready;

    //B mux (follows aw_sel_r)
    assign m_bvalid  = aw_sel_r ? s1_bvalid : s0_bvalid;
    assign m_bresp   = aw_sel_r ? s1_bresp  : s0_bresp;
    assign s0_bready = !aw_sel_r && m_bready;
    assign s1_bready =  aw_sel_r && m_bready;

endmodule
