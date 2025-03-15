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
    parameter CORE_NUMS_BITS = 3
)
(
    // System signals
    input                       clk_i, rst_i,

    // Aquila core 0 interface
    input                       P_strobe_i[0 : 3],
    input [XLEN-1 : 0]          P_addr_i[0 : 3],
    input                       P_rw_i[0 : 3],
    input [XLEN-1 : 0]          P_data_i[0 : 3],
    output                      P_data_ready_o[0 : 3],
    output [XLEN-1 : 0]         P_data_o[0 : 3],
    input                       P_is_amo_i[0 : 3],
    input [ 4 : 0]              P_amo_type_i[0 : 3],

    // Chosen atomic intruction
    output [ 1 : 0]             AMO_id_o,
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
               P3_STROBE = 3;

    localparam M_IDLE   = 0, // wait for strobe
               M_CHOOSE = 1, // choose 
               M_WAIT   = 2; // wait for device ready for request

    // input selection signals
    wire                     concurrent_strobe;
    reg  [1 : 0]             sel_current;
    reg  [1 : 0]             sel_previous;
 
    reg                      AMO_strobe_r;
    reg  [XLEN-1 : 0]        AMO_addr_r;
    reg                      AMO_rw_r;
    reg  [XLEN-1 : 0]      AMO_data_r;
    reg                      AMO_is_amo_r;
    reg  [ 4 : 0]            AMO_amo_type_r;

    // Keep the strobe
    reg                      P_strobe_r[0 : 3];
    reg  [XLEN-1 : 0]        P_addr_r[0 : 3];
    reg                      P_rw_r[0 : 3];
    reg  [XLEN-1 : 0]      P_data_r[0 : 3];
    reg                      P_is_amo_r[0 : 3];
    reg  [ 4 : 0]            P_amo_type_r[0 : 3];
    
    // FSM signals
    reg  [1 : 0]             c_state;
    reg  [1 : 0]             n_state;
    wire                     have_strobe;
    
    //=======================================================
    //  Keep the strobe (in case we miss strobe)
    //=======================================================
    
    // P0-AMO slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_strobe_r[0] <= 0;
        else if (P_strobe_i[0] && P_is_amo_i[0])
            P_strobe_r[0] <= 1;
        else if (P_data_ready_o[0])
            P_strobe_r[0] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_addr_r[0]      <= 0;
            P_rw_r[0]        <= 0;
            P_data_r[0]      <= 0;
            P_amo_type_r[0]  <= 0;
        end else if (P_strobe_i[0]) begin
            P_addr_r[0]      <= P_addr_i[0];
            P_rw_r[0]        <= P_rw_i[0];
            P_data_r[0]      <= P_data_i[0];
            P_amo_type_r[0]  <= P_amo_type_i[0];
        end
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P_is_amo_r[0] <= 0;
        else if (P_strobe_i[0])
            P_is_amo_r[0] <= P_is_amo_i[0];
        else if (P_data_ready_o[0])
            P_is_amo_r[0] <= 0;
    end

    

    // P1-AMO slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_strobe_r[1] <= 0;
        else if (P_strobe_i[1] && P_is_amo_i[1])
            P_strobe_r[1] <= 1;
        else if (P_data_ready_o[1])
            P_strobe_r[1] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P_is_amo_r[1] <= 0;
        else if (P_strobe_i[1])
            P_is_amo_r[1] <= P_is_amo_i[1];
        else if (P_data_ready_o[1])
            P_is_amo_r[1] <= 0;
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_addr_r[1] <= 0;
            P_rw_r[1]   <= 0;
            P_data_r[1] <= 0;
            P_amo_type_r[1] <= 0;
        end else if (P_strobe_i[1]) begin
            P_addr_r[1]     <= P_addr_i[1];
            P_rw_r[1]       <= P_rw_i[1];
            P_data_r[1]     <= P_data_i[1];
            P_amo_type_r[1] <= P_amo_type_i[1];
        end
    end

    // P2-AMO slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_strobe_r[2] <= 0;
        else if (P_strobe_i[2] && P_is_amo_i[2])
            P_strobe_r[2] <= 1;
        else if (P_data_ready_o[2])
            P_strobe_r[2] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P_is_amo_r[2] <= 0;
        else if (P_strobe_i[2])
            P_is_amo_r[2] <= P_is_amo_i[2];
        else if (P_data_ready_o[2])
            P_is_amo_r[2] <= 0;
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_addr_r[2] <= 0;
            P_rw_r[2]   <= 0;
            P_data_r[2] <= 0;
            P_amo_type_r[2] <= 0;
        end else if (P_strobe_i[2]) begin
            P_addr_r[2]     <= P_addr_i[2];
            P_rw_r[2]       <= P_rw_i[2];
            P_data_r[2]     <= P_data_i[2];
            P_amo_type_r[2] <= P_amo_type_i[2];
        end
    end

    // P3-AMO slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_strobe_r[3] <= 0;
        else if (P_strobe_i[3] && P_is_amo_i[3])
            P_strobe_r[3] <= 1;
        else if (P_data_ready_o[3])
            P_strobe_r[3] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P_is_amo_r[3] <= 0;
        else if (P_strobe_i[3])
            P_is_amo_r[3] <= P_is_amo_i[3];
        else if (P_data_ready_o[3])
            P_is_amo_r[3] <= 0;
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_addr_r[3] <= 0;
            P_rw_r[3]   <= 0;
            P_data_r[3] <= 0;
            P_amo_type_r[3] <= 0;
        end else if (P_strobe_i[3]) begin
            P_addr_r[3]     <= P_addr_i[3];
            P_rw_r[3]       <= P_rw_i[3];
            P_data_r[3]     <= P_data_i[3];
            P_amo_type_r[3] <= P_amo_type_i[3];
        end
    end


    
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
            if (sel_current == P0_STROBE) begin
                AMO_addr_r     <= P_addr_r[0];
                AMO_rw_r       <= P_rw_r[0];
                AMO_data_r     <= P_data_r[0];
                AMO_is_amo_r   <= P_is_amo_r[0];
                AMO_amo_type_r <= P_amo_type_r[0];
            end else if (sel_current == P1_STROBE) begin
                AMO_addr_r     <= P_addr_r[1];
                AMO_rw_r       <= P_rw_r[1];
                AMO_data_r     <= P_data_r[1];
                AMO_is_amo_r   <= P_is_amo_r[1];
                AMO_amo_type_r <= P_amo_type_r[1];
            end else if (sel_current == P2_STROBE) begin
                AMO_addr_r     <= P_addr_r[2];
                AMO_rw_r       <= P_rw_r[2];
                AMO_data_r     <= P_data_r[2];
                AMO_is_amo_r   <= P_is_amo_r[2];
                AMO_amo_type_r <= P_amo_type_r[2];
            end else if (sel_current == P3_STROBE) begin
                AMO_addr_r     <= P_addr_r[3];
                AMO_rw_r       <= P_rw_r[3];
                AMO_data_r     <= P_data_r[3];
                AMO_is_amo_r   <= P_is_amo_r[3];
                AMO_amo_type_r <= P_amo_type_r[3];  
            end
        end
    end

    //=======================================================
    //  Output logic
    //=======================================================
    assign P_data_ready_o[0] = (sel_current == P0_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    assign P_data_o[0]       = AMO_data_i;

    assign P_data_ready_o[1] = (sel_current == P1_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    assign P_data_o[1]       = AMO_data_i;

    assign P_data_ready_o[2] = (sel_current == P2_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    assign P_data_o[2]       = AMO_data_i;

    assign P_data_ready_o[3] = (sel_current == P3_STROBE && c_state == M_WAIT) ? AMO_data_ready_i : 'b0;
    assign P_data_o[3]       = AMO_data_i;

    assign AMO_id_o            = (sel_current == P0_STROBE) ? 2'b00 :
                                 (sel_current == P1_STROBE) ? 2'b01 :
                                 (sel_current == P2_STROBE) ? 2'b10 :
                                 2'b11; 

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

    assign have_strobe = P_strobe_r[0] | P_strobe_r[1] | P_strobe_r[2]| P_strobe_r[3];
    
endmodule