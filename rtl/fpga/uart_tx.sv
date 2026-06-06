module uart_tx #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int BAUD     = 115200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [7:0] data,
    output logic       tx_o,
    output logic       busy
);
    localparam int BAUD_DIV = CLK_FREQ / BAUD - 1;
    localparam int DIV_W    = $clog2(BAUD_DIV + 1);

    logic [9:0]       shift_reg;
    logic [3:0]       bit_cnt;
    logic [DIV_W-1:0] baud_cnt;

    assign tx_o = shift_reg[0];
    assign busy = (bit_cnt != 4'd0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 10'h3FF;
            bit_cnt   <= 4'd0;
            baud_cnt  <= '0;
        end else if (!busy && start) begin
            shift_reg <= {1'b1, data, 1'b0};
            bit_cnt   <= 4'd10;
            baud_cnt  <= '0;
        end else if (busy) begin
            if (baud_cnt == DIV_W'(BAUD_DIV)) begin
                baud_cnt  <= '0;
                shift_reg <= {1'b1, shift_reg[9:1]};
                bit_cnt   <= bit_cnt - 4'd1;
            end else begin
                baud_cnt <= baud_cnt + 1'b1;
            end
        end
    end
endmodule
