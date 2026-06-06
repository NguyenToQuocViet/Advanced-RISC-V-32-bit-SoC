module axi_bram
    import cache_pkg::*;
#(
    parameter int MEM_DEPTH = 16384,
    parameter     INIT_FILE0 = "hello0.mem",
    parameter     INIT_FILE1 = "hello1.mem",
    parameter     INIT_FILE2 = "hello2.mem",
    parameter     INIT_FILE3 = "hello3.mem"
)(
    input  logic                  clk,
    input  logic                  rst_n,

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
    output logic [1:0]            s_axi_bresp
);
    localparam int IDX_W = $clog2(MEM_DEPTH);

    //4 byte-lane BRAM banks
    (* ram_style = "block" *) logic [7:0] mem0 [0:MEM_DEPTH-1];
    (* ram_style = "block" *) logic [7:0] mem1 [0:MEM_DEPTH-1];
    (* ram_style = "block" *) logic [7:0] mem2 [0:MEM_DEPTH-1];
    (* ram_style = "block" *) logic [7:0] mem3 [0:MEM_DEPTH-1];

    initial begin
        $readmemh(INIT_FILE0, mem0);
        $readmemh(INIT_FILE1, mem1);
        $readmemh(INIT_FILE2, mem2);
        $readmemh(INIT_FILE3, mem3);
    end

    //--- Read Path ---
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_READ,
        RD_DATA
    } rd_state_t;

    rd_state_t rd_state;

    logic [ADDR_WIDTH-1:0] rd_addr_base;
    logic [ADDR_WIDTH-1:0] rd_addr_start;
    logic [7:0]            rd_beat_total;
    logic [7:0]            rd_beat_cnt;
    logic [DATA_WIDTH-1:0] rd_data_reg;

    //WRAP address: 16-byte boundary
    logic [ADDR_WIDTH-1:0] rd_cur_addr;
    assign rd_cur_addr = rd_addr_base | ((rd_addr_start + {24'b0, rd_beat_cnt, 2'b00}) & 32'hF);

    logic [IDX_W-1:0] rd_word_idx;
    assign rd_word_idx = rd_cur_addr[2 +: IDX_W];

    assign s_axi_arready = (rd_state == RD_IDLE);
    assign s_axi_rvalid  = (rd_state == RD_DATA);
    assign s_axi_rdata   = rd_data_reg;
    assign s_axi_rresp   = 2'b00;
    assign s_axi_rlast   = (rd_state == RD_DATA) && (rd_beat_cnt == rd_beat_total);

    //FSM control (with reset)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_state      <= RD_IDLE;
            rd_addr_base  <= '0;
            rd_addr_start <= '0;
            rd_beat_total <= '0;
            rd_beat_cnt   <= '0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_axi_arvalid) begin
                        rd_addr_start <= s_axi_araddr;
                        rd_addr_base  <= s_axi_araddr & ~32'hF;
                        rd_beat_total <= s_axi_arlen;
                        rd_beat_cnt   <= '0;
                        rd_state      <= RD_READ;
                    end
                end

                RD_READ: begin
                    rd_state <= RD_DATA;
                end

                RD_DATA: begin
                    if (s_axi_rready) begin
                        if (rd_beat_cnt == rd_beat_total)
                            rd_state <= RD_IDLE;
                        else begin
                            rd_beat_cnt <= rd_beat_cnt + 8'd1;
                            rd_state    <= RD_READ;
                        end
                    end
                end
            endcase
        end
    end

    //BRAM sync read (no reset)
    logic [IDX_W-1:0] rd_launch_idx;
    assign rd_launch_idx = (rd_state == RD_IDLE) ? s_axi_araddr[2 +: IDX_W] : rd_word_idx;

    logic rd_en;
    assign rd_en = (rd_state == RD_IDLE && s_axi_arvalid) || (rd_state == RD_READ);

    always_ff @(posedge clk) begin
        if (rd_en) begin
            rd_data_reg <= {mem3[rd_launch_idx], mem2[rd_launch_idx],
                            mem1[rd_launch_idx], mem0[rd_launch_idx]};
        end
    end

    //--- Write Path ---
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    wr_state_t wr_state;

    logic [ADDR_WIDTH-1:0] wr_addr;
    logic [IDX_W-1:0] wr_word_idx;
    assign wr_word_idx = wr_addr[2 +: IDX_W];

    assign s_axi_awready = (wr_state == WR_IDLE);
    assign s_axi_wready  = (wr_state == WR_DATA);
    assign s_axi_bvalid  = (wr_state == WR_RESP);
    assign s_axi_bresp   = 2'b00;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_state <= WR_IDLE;
            wr_addr  <= '0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid) begin
                        wr_addr  <= s_axi_awaddr;
                        wr_state <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    if (s_axi_wvalid)
                        wr_state <= WR_RESP;
                end

                WR_RESP: begin
                    if (s_axi_bready)
                        wr_state <= WR_IDLE;
                end
            endcase
        end
    end

    //BRAM byte-lane write (no reset, unconditional per bank)
    logic wr_en;
    assign wr_en = (wr_state == WR_DATA) && s_axi_wvalid;

    always_ff @(posedge clk) begin
        if (wr_en && s_axi_wstrb[0]) mem0[wr_word_idx] <= s_axi_wdata[7:0];
    end
    always_ff @(posedge clk) begin
        if (wr_en && s_axi_wstrb[1]) mem1[wr_word_idx] <= s_axi_wdata[15:8];
    end
    always_ff @(posedge clk) begin
        if (wr_en && s_axi_wstrb[2]) mem2[wr_word_idx] <= s_axi_wdata[23:16];
    end
    always_ff @(posedge clk) begin
        if (wr_en && s_axi_wstrb[3]) mem3[wr_word_idx] <= s_axi_wdata[31:24];
    end
endmodule
