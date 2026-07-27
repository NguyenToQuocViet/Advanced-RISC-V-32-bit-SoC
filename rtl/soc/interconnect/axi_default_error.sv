// -----------------------------------------------------------------------------
// Copyright (c) 2026 NGUYEN TO QUOC VIET
// Ho Chi Minh City University of Technology (HCMUT-VNU)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// -----------------------------------------------------------------------------
// Project      : Advanced RISC-V 32-bit Processor
// Module       : axi_default_error
// Description  : Internal AXI decode-error response engine
//
// Author       : NGUYEN TO QUOC VIET
// Date         : 2026-07-26
// Version      : 1.0
// -----------------------------------------------------------------------------

module axi_default_error #(
    parameter ID_WIDTH   = 2,
    parameter DATA_WIDTH = 32
) (
    //system
    input  logic                    clk,
    input  logic                    rst_n,

    //read request
    input  logic                    rd_req_valid,
    output logic                    rd_req_ready,
    input  logic [ID_WIDTH-1:0]     rd_req_id,
    input  logic [7:0]              rd_req_len,

    //read response
    output logic                    rd_resp_valid,
    input  logic                    rd_resp_ready,
    output logic [ID_WIDTH-1:0]     rd_resp_id,
    output logic [DATA_WIDTH-1:0]   rd_resp_data,
    output logic [1:0]              rd_resp_resp,
    output logic                    rd_resp_last,

    //write request
    input  logic                    wr_req_valid,
    output logic                    wr_req_ready,
    input  logic [ID_WIDTH-1:0]     wr_req_id,
    input  logic [7:0]              wr_req_len,

    //write data
    input  logic                    wr_data_valid,
    output logic                    wr_data_ready,
    input  logic                    wr_data_last,

    //write response
    output logic                    wr_resp_valid,
    input  logic                    wr_resp_ready,
    output logic [ID_WIDTH-1:0]     wr_resp_id,
    output logic [1:0]              wr_resp_resp
);
    localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

    //READ PATH
    typedef enum logic {
        RD_IDLE,
        RD_RESP
    } rd_state_t;

    rd_state_t rd_state, rd_state_next;

    logic                rd_req_fire;
    logic                rd_resp_fire;
    logic [ID_WIDTH-1:0] rd_id_q;
    logic [8:0]          rd_beats_left_q;

    assign rd_req_fire  = rd_req_valid  && rd_req_ready;
    assign rd_resp_fire = rd_resp_valid && rd_resp_ready;

    //update fsm
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_state    <= RD_IDLE;
        end else begin
            rd_state    <= rd_state_next;
        end
    end

    //next-state fsm
    always_comb begin
        //default
        rd_state_next = rd_state;

        case (rd_state) 
            RD_IDLE: begin
                if (rd_req_fire)
                    rd_state_next = RD_RESP;
            end

            RD_RESP: begin
                if (rd_resp_fire && rd_resp_last)
                    rd_state_next = RD_IDLE;
            end

            default: rd_state_next = RD_IDLE;
        endcase
    end

    //transaction metadata
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_id_q         <= '0;
            rd_beats_left_q <= '0;
        end else begin
            if (rd_req_fire) begin
                rd_id_q         <= rd_req_id;
                rd_beats_left_q <= {1'b0, rd_req_len} + 9'd1;
            end else if (rd_resp_fire) begin
                if (rd_resp_last)
                    rd_beats_left_q <= '0;
                else
                    rd_beats_left_q <= rd_beats_left_q - 9'd1;
            end
        end
    end

    //output logic fsm
    always_comb begin
        //default
        rd_req_ready  = 1'b0;
        rd_resp_valid = 1'b0;
        rd_resp_id    = rd_id_q;
        rd_resp_data  = '0;
        rd_resp_resp  = AXI_RESP_DECERR;
        rd_resp_last  = 1'b0;

        case (rd_state)
            RD_IDLE: begin
                rd_req_ready = 1'b1;
            end

            RD_RESP: begin
                rd_resp_valid = 1'b1;
                rd_resp_last  = (rd_beats_left_q == 9'd1);
            end

            default: begin
                rd_req_ready  = 1'b0;
                rd_resp_valid = 1'b0;
            end
        endcase
    end

    //WRITE PATH
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    wr_state_t wr_state, wr_state_next;

    logic                wr_req_fire;
    logic                wr_data_fire;
    logic                wr_resp_fire;
    logic [ID_WIDTH-1:0] wr_id_q;
    logic [8:0]          wr_beats_left_q;

    assign wr_req_fire  = wr_req_valid  && wr_req_ready;
    assign wr_data_fire = wr_data_valid && wr_data_ready;
    assign wr_resp_fire = wr_resp_valid && wr_resp_ready;

    //update fsm
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_state <= WR_IDLE;
        end else begin
            wr_state <= wr_state_next;
        end
    end

    //next-state fsm
    always_comb begin
        //default
        wr_state_next = wr_state;

        case (wr_state)
            WR_IDLE: begin
                if (wr_req_fire)
                    wr_state_next = WR_DATA;
            end

            WR_DATA: begin
                if (wr_data_fire && (wr_beats_left_q == 9'd1))
                    wr_state_next = WR_RESP;
            end

            WR_RESP: begin
                if (wr_resp_fire)
                    wr_state_next = WR_IDLE;
            end

            default: wr_state_next = WR_IDLE;
        endcase
    end

    //transaction metadata
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_id_q         <= '0;
            wr_beats_left_q <= '0;
        end else begin
            if (wr_req_fire) begin
                wr_id_q         <= wr_req_id;
                wr_beats_left_q <= {1'b0, wr_req_len} + 9'd1;
            end else if (wr_data_fire) begin
                if (wr_beats_left_q == 9'd1)
                    wr_beats_left_q <= '0;
                else
                    wr_beats_left_q <= wr_beats_left_q - 9'd1;
            end
        end
    end

    //output logic fsm
    always_comb begin
        //default
        wr_req_ready  = 1'b0;
        wr_data_ready = 1'b0;
        wr_resp_valid = 1'b0;
        wr_resp_id    = wr_id_q;
        wr_resp_resp  = AXI_RESP_DECERR;

        case (wr_state)
            WR_IDLE: begin
                wr_req_ready = 1'b1;
            end

            WR_DATA: begin
                wr_data_ready = 1'b1;
            end

            WR_RESP: begin
                wr_resp_valid = 1'b1;
            end

            default: begin
                wr_req_ready  = 1'b0;
                wr_data_ready = 1'b0;
                wr_resp_valid = 1'b0;
            end
        endcase
    end

endmodule
