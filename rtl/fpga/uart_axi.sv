module uart_axi
    import cache_pkg::*;
#(parameter int CLK_FREQ = 100_000_000)
(
    input  logic                  clk,
    input  logic                  rst_n,

    //AXI4 slave - write address
    input  logic                  s_axi_awvalid,
    output logic                  s_axi_awready,
    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic [7:0]            s_axi_awlen,
    input  logic [2:0]            s_axi_awsize,
    input  logic [1:0]            s_axi_awburst,

    //AXI4 slave - write data
    input  logic                  s_axi_wvalid,
    output logic                  s_axi_wready,
    input  logic [DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [STRB_WIDTH-1:0] s_axi_wstrb,
    input  logic                  s_axi_wlast,

    //AXI4 slave - write response
    output logic                  s_axi_bvalid,
    input  logic                  s_axi_bready,
    output logic [1:0]            s_axi_bresp,

    //AXI4 slave - read address
    input  logic                  s_axi_arvalid,
    output logic                  s_axi_arready,
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic [7:0]            s_axi_arlen,
    input  logic [2:0]            s_axi_arsize,
    input  logic [1:0]            s_axi_arburst,

    //AXI4 slave - read data
    output logic                  s_axi_rvalid,
    input  logic                  s_axi_rready,
    output logic [DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]            s_axi_rresp,
    output logic                  s_axi_rlast,

    //UART TX
    output logic                  uart_tx_o
);
    logic       tx_start, tx_busy;
    logic [7:0] tx_data;

    uart_tx #(.CLK_FREQ(CLK_FREQ)) u_uart_tx (
        .clk   (clk),
        .rst_n (rst_n),
        .start (tx_start),
        .data  (tx_data),
        .tx_o  (uart_tx_o),
        .busy  (tx_busy)
    );

    //Write path: AW → W → B
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    wr_state_t wr_state;

    assign s_axi_awready = (wr_state == WR_IDLE) && !tx_busy;
    assign s_axi_wready  = (wr_state == WR_DATA);
    assign s_axi_bvalid  = (wr_state == WR_RESP);
    assign s_axi_bresp   = 2'b00;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state <= WR_IDLE;
            tx_start <= 1'b0;
            tx_data  <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_awready)
                        wr_state <= WR_DATA;
                end

                WR_DATA: begin
                    if (s_axi_wvalid) begin
                        tx_data  <= s_axi_wdata[7:0];
                        tx_start <= 1'b1;
                        wr_state <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (s_axi_bready)
                        wr_state <= WR_IDLE;
                end
            endcase
        end
    end

    //Read path: return tx_busy status
    typedef enum logic {
        RD_IDLE,
        RD_DATA
    } rd_state_t;

    rd_state_t rd_state;

    assign s_axi_arready = (rd_state == RD_IDLE);
    assign s_axi_rvalid  = (rd_state == RD_DATA);
    assign s_axi_rdata   = {31'b0, tx_busy};
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rlast   = s_axi_rvalid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_state <= RD_IDLE;
        else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_axi_arvalid)
                        rd_state <= RD_DATA;
                end
                RD_DATA: begin
                    if (s_axi_rready)
                        rd_state <= RD_IDLE;
                end
            endcase
        end
    end
endmodule
