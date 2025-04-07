`timescale 1ns / 1ps
// =============================================================================
//  Program : amo_arbiter.v
//  Author  : Lin-en Yen
//  Date    : Feb/25/2024
// -----------------------------------------------------------------------------
//  Description:
//      The arbiter for a multi-core system.
// -----------------------------------------------------------------------------
//  Revision information:
//
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
`include "aquila_config.vh"

module amo_arbiter #(
    parameter XLEN   = 32,  // Width of address bus
    parameter CLSIZE = `CLP, // Size of a cache line in bits.
     parameter CORE_NUMS = `CORE_NUMS,parameter CORE_NUMS_BITS =2
)
(
    // System signals
    input                       clk_i, rst_i,

    // Aquila core 0 interface
    input                       P_strobe_i[0 : CORE_NUMS-1],
    input [XLEN-1 : 0]          P_addr_i[0 : CORE_NUMS-1],
    input                       P_rw_i[0 : CORE_NUMS-1],
    input [XLEN-1 : 0]          P_data_i[0 : CORE_NUMS-1],
    output reg                  P_data_ready_o[0 : CORE_NUMS-1],
    output reg [XLEN-1 : 0]     P_data_o[0 : CORE_NUMS-1],
    input                       P_is_amo_i[0 : CORE_NUMS-1],
    input [ 4 : 0]              P_amo_type_i[0 : CORE_NUMS-1],

    // Chosen atomic intruction
    output [CORE_NUMS_BITS-1 : 0]             AMO_id_o,
    output                      AMO_strobe_o,
    output [XLEN-1 : 0]         AMO_addr_o,
    output                      AMO_rw_o,
    output [XLEN-1 : 0]         AMO_data_o,
    input                       AMO_data_ready_i,
    input [XLEN-1 : 0]          AMO_data_i,
    output                      AMO_is_amo_o,
    output [ 4 : 0]             AMO_amo_type_o
    //output [CLSIZE-1 : 0]       AMO_data_o,
    //input [CLSIZE-1 : 0]        AMO_data_i,
);

    // Strobe source, have two strobe sources (P0-MEM, P1-MEM) 
    localparam P0_STROBE = 0,
               P1_STROBE = 1,
               P2_STROBE = 2,
               P3_STROBE = 3,
                P4_STROBE = 4,
                P5_STROBE = 5,
                P6_STROBE = 6,
                P7_STROBE = 7;

    localparam M_IDLE   = 0, // wait for strobe
               M_CHOOSE = 1, // choose 
               M_WAIT   = 2; // wait for device ready for request

    // input selection signals
    wire                     concurrent_strobe;
    reg  [CORE_NUMS_BITS-1 : 0]             sel_current;
 
    reg                      AMO_strobe_r;
    reg  [XLEN-1 : 0]        AMO_addr_r;
    reg                      AMO_rw_r;
    reg  [XLEN-1 : 0]      AMO_data_r;
    reg                      AMO_is_amo_r;
    reg  [ 4 : 0]            AMO_amo_type_r;

    // Keep the strobe
    reg                      P_strobe_r[0 : CORE_NUMS-1];
    reg  [XLEN-1 : 0]        P_addr_r[0 : CORE_NUMS-1];
    reg                      P_rw_r[0 : CORE_NUMS-1];
    reg  [XLEN-1 : 0]        P_data_r[0 : CORE_NUMS-1];
    reg                      P_is_amo_r[0 : CORE_NUMS-1];
    reg  [ 4 : 0]            P_amo_type_r[0 : CORE_NUMS-1];
    
    // FSM signals
    reg  [1 : 0]             c_state;
    reg  [1 : 0]             n_state;
    wire                     have_strobe;
    integer i;
    //=======================================================
    //  Keep the strobe (in case we miss strobe)
    //=======================================================
    always @(posedge clk_i) begin
        if(rst_i) begin
            for(i = 0;i < `CORE_NUMS;i = i + 1) begin
                P_strobe_r[i] <= 0;
            end
        end
        else begin
            for(i = 0;i < `CORE_NUMS;i = i + 1) begin
                if (P_strobe_i[i] && P_is_amo_i[i])
                    P_strobe_r[i] <= 1;
                else if (P_data_ready_o[i])
                    P_strobe_r[i] <= 0; // Clear the strobe
            end
        end
    end

    always @(posedge clk_i) begin
        if(rst_i) begin
            for(i = 0;i < `CORE_NUMS;i = i + 1) begin
                P_is_amo_r[i] <= 0;
            end
        end
        else begin
            for(i = 0;i < `CORE_NUMS;i = i + 1) begin
                if (P_strobe_i[i])
                    P_is_amo_r[i] <= P_is_amo_i[i];
                else if (P_data_ready_o[i])
                    P_is_amo_r[i] <= 0; // Clear the strobe
            end
        end
    end

   always @(posedge clk_i) begin
        if(rst_i) begin
            for(i = 0;i < `CORE_NUMS;i = i + 1) begin
                P_addr_r[i]      <= 0;
                P_rw_r[i]        <= 0;
                P_data_r[i]      <= 0;
                P_amo_type_r[i]  <= 0;
            end
        end
        else begin
            for(i = 0;i < `CORE_NUMS;i = i + 1) begin
                if(P_strobe_i[i]) begin
                    P_addr_r[i]      <= P_addr_i[i];
                    P_rw_r[i]        <= P_rw_i[i];
                    P_data_r[i]      <= P_data_i[i];
                    P_amo_type_r[i]  <= P_amo_type_i[i];
                end
            end
        end
    end

    // // P0-AMO slave interface
    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_strobe_r[0] <= 0;
    //     else if (P_strobe_i[0] && P_is_amo_i[0])
    //         P_strobe_r[0] <= 1;
    //     else if (P_data_ready_o[0])
    //         P_strobe_r[0] <= 0; // Clear the strobe
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i) begin
    //         P_addr_r[0]      <= 0;
    //         P_rw_r[0]        <= 0;
    //         P_data_r[0]      <= 0;
    //         P_amo_type_r[0]  <= 0;
    //     end else if (P_strobe_i[0]) begin
    //         P_addr_r[0]      <= P_addr_i[0];
    //         P_rw_r[0]        <= P_rw_i[0];
    //         P_data_r[0]      <= P_data_i[0];
    //         P_amo_type_r[0]  <= P_amo_type_i[0];
    //     end
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_is_amo_r[0] <= 0;
    //     else if (P_strobe_i[0])
    //         P_is_amo_r[0] <= P_is_amo_i[0];
    //     else if (P_data_ready_o[0])
    //         P_is_amo_r[0] <= 0;
    // end

    

    // // P1-AMO slave interface
    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_strobe_r[1] <= 0;
    //     else if (P_strobe_i[1] && P_is_amo_i[1])
    //         P_strobe_r[1] <= 1;
    //     else if (P_data_ready_o[1])
    //         P_strobe_r[1] <= 0; // Clear the strobe
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_is_amo_r[1] <= 0;
    //     else if (P_strobe_i[1])
    //         P_is_amo_r[1] <= P_is_amo_i[1];
    //     else if (P_data_ready_o[1])
    //         P_is_amo_r[1] <= 0;
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i) begin
    //         P_addr_r[1] <= 0;
    //         P_rw_r[1]   <= 0;
    //         P_data_r[1] <= 0;
    //         P_amo_type_r[1] <= 0;
    //     end else if (P_strobe_i[1]) begin
    //         P_addr_r[1]     <= P_addr_i[1];
    //         P_rw_r[1]       <= P_rw_i[1];
    //         P_data_r[1]     <= P_data_i[1];
    //         P_amo_type_r[1] <= P_amo_type_i[1];
    //     end
    // end

    // // P2-AMO slave interface
    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_strobe_r[2] <= 0;
    //     else if (P_strobe_i[2] && P_is_amo_i[2])
    //         P_strobe_r[2] <= 1;
    //     else if (P_data_ready_o[2])
    //         P_strobe_r[2] <= 0; // Clear the strobe
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_is_amo_r[2] <= 0;
    //     else if (P_strobe_i[2])
    //         P_is_amo_r[2] <= P_is_amo_i[2];
    //     else if (P_data_ready_o[2])
    //         P_is_amo_r[2] <= 0;
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i) begin
    //         P_addr_r[2] <= 0;
    //         P_rw_r[2]   <= 0;
    //         P_data_r[2] <= 0;
    //         P_amo_type_r[2] <= 0;
    //     end else if (P_strobe_i[2]) begin
    //         P_addr_r[2]     <= P_addr_i[2];
    //         P_rw_r[2]       <= P_rw_i[2];
    //         P_data_r[2]     <= P_data_i[2];
    //         P_amo_type_r[2] <= P_amo_type_i[2];
    //     end
    // end

    // // P3-AMO slave interface
    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_strobe_r[3] <= 0;
    //     else if (P_strobe_i[3] && P_is_amo_i[3])
    //         P_strobe_r[3] <= 1;
    //     else if (P_data_ready_o[3])
    //         P_strobe_r[3] <= 0; // Clear the strobe
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_is_amo_r[3] <= 0;
    //     else if (P_strobe_i[3])
    //         P_is_amo_r[3] <= P_is_amo_i[3];
    //     else if (P_data_ready_o[3])
    //         P_is_amo_r[3] <= 0;
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i) begin
    //         P_addr_r[3] <= 0;
    //         P_rw_r[3]   <= 0;
    //         P_data_r[3] <= 0;
    //         P_amo_type_r[3] <= 0;
    //     end else if (P_strobe_i[3]) begin
    //         P_addr_r[3]     <= P_addr_i[3];
    //         P_rw_r[3]       <= P_rw_i[3];
    //         P_data_r[3]     <= P_data_i[3];
    //         P_amo_type_r[3] <= P_amo_type_i[3];
    //     end
    // end

    //=======================================================
    //  Strobe signals selection (Round Robin) 
    //=======================================================
    
    // assign concurrent_strobe = P_strobe_r[0] & P_strobe_r[1];
    // always @(posedge clk_i) begin
    //     if (rst_i) 
    //         sel_previous <= 0;
    //     else if (c_state == M_CHOOSE)
    //         sel_previous <= sel_current;
    // end
`ifdef CORE_NUMS_2
    always @(posedge clk_i) begin
        if (rst_i) 
            sel_current <= 0;
        else if(c_state == M_IDLE)begin
            if(P_strobe_r[0])
                sel_current <= P0_STROBE;
            else if(P_strobe_r[1])
                sel_current <= P1_STROBE;
        end
    end
`elsif CORE_NUMS_4
    always @(posedge clk_i) begin
        if (rst_i) 
            sel_current <= 0;
        else if(c_state == M_IDLE)begin
            if(P_strobe_r[0])
                sel_current <= P0_STROBE;
            else if(P_strobe_r[1])
                sel_current <= P1_STROBE;
            else if(P_strobe_r[2])
                sel_current <= P2_STROBE;
            else if(P_strobe_r[3])
                sel_current <= P3_STROBE;
        end
    end
`else // CORE_NUMS_8
    always @(posedge clk_i) begin
        if (rst_i) 
            sel_current <= 0;
        else if(c_state == M_IDLE)begin
            if(P_strobe_r[0])
                sel_current <= P0_STROBE;
            else if(P_strobe_r[1])
                sel_current <= P1_STROBE;
            else if(P_strobe_r[2])
                sel_current <= P2_STROBE;
            else if(P_strobe_r[3])
                sel_current <= P3_STROBE;
            else if(P_strobe_r[4])
                sel_current <= P4_STROBE;
            else if(P_strobe_r[5])
                sel_current <= P5_STROBE;
            else if(P_strobe_r[6])
                sel_current <= P6_STROBE;
            else if(P_strobe_r[7])
                sel_current <= P7_STROBE;
        end
    end
`endif
    /* Record selected singnals*/
    always @(posedge clk_i) begin
        if (rst_i) 
            AMO_strobe_r <= 0;
        else if(c_state == M_CHOOSE) 
            AMO_strobe_r <= 1;
        else    
            AMO_strobe_r <= 0;
    end
    
    always @(posedge clk_i) begin
        if (rst_i) begin
            AMO_addr_r     <= 0;
            AMO_rw_r       <= 0;
            AMO_data_r     <= 0;
            AMO_is_amo_r   <= 0;
            AMO_amo_type_r <= 0;
        end else begin
            AMO_addr_r <= P_addr_r[sel_current];
            AMO_rw_r   <= P_rw_r[sel_current];
            AMO_data_r <= P_data_r[sel_current];
            AMO_is_amo_r <= P_is_amo_r[sel_current];
            AMO_amo_type_r <= P_amo_type_r[sel_current];
        end
    end

    //=======================================================
    //  Output logic
    //=======================================================
    always @(*) begin
        for(i = 0;i < `CORE_NUMS;i = i + 1) begin
            P_data_ready_o[i] = (sel_current == i && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
            P_data_o[i]       = AMO_data_i;
        end
    end
    // assign P_data_ready_o[0] = (sel_current == P0_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    // assign P_data_o[0]       = AMO_data_i;

    // assign P_data_ready_o[1] = (sel_current == P1_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    // assign P_data_o[1]       = AMO_data_i;

    // assign P_data_ready_o[2] = (sel_current == P2_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    // assign P_data_o[2]       = AMO_data_i;

    // assign P_data_ready_o[3] = (sel_current == P3_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    // assign P_data_o[3]       = AMO_data_i;

    assign AMO_id_o            = sel_current;

    assign AMO_strobe_o        = AMO_strobe_r;
    assign AMO_addr_o          = AMO_addr_r;
    assign AMO_rw_o            = AMO_rw_r;
    assign AMO_data_o          = AMO_data_r;
    assign AMO_is_amo_o        = AMO_is_amo_r;
    assign AMO_amo_type_o      = AMO_amo_type_r;

    //=======================================================
    //  Main FSM
    //=======================================================
    always @(posedge clk_i) begin
        if (rst_i)
            c_state <= M_IDLE;
        else
            c_state <= n_state;
    end

    always @(*) begin
        case (c_state)
            M_IDLE: 
                if (have_strobe) 
                    n_state = M_CHOOSE;
                else 
                    n_state = M_IDLE;
            M_CHOOSE:
                n_state = M_WAIT;
            M_WAIT:
                if(AMO_data_ready_i)
                    n_state = M_IDLE;
                else
                    n_state = M_WAIT;
        endcase
    end
`ifdef CORE_NUMS_2
    assign have_strobe = P_strobe_r[0] | P_strobe_r[1];
`elsif CORE_NUMS_4
    assign have_strobe = P_strobe_r[0] | P_strobe_r[1] | P_strobe_r[2]| P_strobe_r[3];
`else // CORE_NUMS_8
    assign have_strobe = P_strobe_r[0] | P_strobe_r[1] | P_strobe_r[2]| P_strobe_r[3] |
                         P_strobe_r[4] | P_strobe_r[5] | P_strobe_r[6]| P_strobe_r[7];
`endif
endmodule