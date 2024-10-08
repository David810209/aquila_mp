// =============================================================================
//  Program : device_arbiter.v
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

module device_arbiter #(parameter XLEN = 32)
(
    // System signals
    input                       clk_i, rst_i,

    // Aquila core 0 device interface
    input                       P0_DEVICE_strobe_i,
    input [XLEN-1 : 0]          P0_DEVICE_addr_i,
    input                       P0_DEVICE_rw_i,
    input [XLEN/8-1 : 0]        P0_DEVICE_byte_enable_i,
    input [XLEN-1 : 0]          P0_DEVICE_data_i,
    output                      P0_DEVICE_data_ready_o,
    output [XLEN-1 : 0]         P0_DEVICE_data_o,

    // Aquila core 1 device interface
    input                       P1_DEVICE_strobe_i,
    input [XLEN-1 : 0]          P1_DEVICE_addr_i,
    input                       P1_DEVICE_rw_i,
    input [XLEN/8-1 : 0]        P1_DEVICE_byte_enable_i,
    input [XLEN-1 : 0]          P1_DEVICE_data_i,
    output                      P1_DEVICE_data_ready_o,
    output [XLEN-1 : 0]         P1_DEVICE_data_o,

    // Aquila device slave interface
    output                      DEVICE_strobe_o,
    output [XLEN-1 : 0]         DEVICE_addr_o,
    output                      DEVICE_rw_o,
    output [XLEN/8-1 : 0]       DEVICE_byte_enable_o,
    output [XLEN-1 : 0]         DEVICE_data_o,
    input                       DEVICE_data_ready_i,
    input [XLEN-1 : 0]          DEVICE_data_i
);

    // Strobe source, have two strobe sources (P0-MEM, P1-MEM) 
    localparam P0_STROBE = 0,
               P1_STROBE = 1;

    localparam M_IDLE   = 0, // wait for strobe
               M_CHOOSE = 1, // choose 
               M_WAIT   = 2; // wait for device ready for request

    // input selection signals
    wire                     concurrent_strobe;
    reg                      sel_current;
    reg                      sel_previous;
 
    reg                      DEVICE_strobe_r;
    reg  [XLEN-1 : 0]        DEVICE_addr_r;
    reg                      DEVICE_rw_r;
    reg  [XLEN/8-1 : 0]      DEVICE_byte_enable_r;
    reg  [XLEN-1 : 0]        DEVICE_data_r;

    // Keep the strobe
    reg                      P0_DEVICE_strobe_r;
    reg  [XLEN-1 : 0]        P0_DEVICE_addr_r;
    reg                      P0_DEVICE_rw_r;
    reg  [XLEN/8-1 : 0]      P0_DEVICE_byte_enable_r;
    reg  [XLEN-1 : 0]        P0_DEVICE_data_r;


    reg                      P1_DEVICE_strobe_r;
    reg  [XLEN-1 : 0]        P1_DEVICE_addr_r;
    reg                      P1_DEVICE_rw_r;
    reg  [XLEN/8-1 : 0]      P1_DEVICE_byte_enable_r;
    reg  [XLEN-1 : 0]        P1_DEVICE_data_r;

    
    // FSM signals
    reg  [1 : 0]             c_state;
    reg  [1 : 0]             n_state;
    wire                     have_strobe;
    
    //=======================================================
    //  Keep the strobe (in case we miss strobe)
    //=======================================================
    // P0-DEVICE slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P0_DEVICE_strobe_r <= 0;
        else if (P0_DEVICE_strobe_i)
            P0_DEVICE_strobe_r <= 1;
        else if (P0_DEVICE_data_ready_o)
            P0_DEVICE_strobe_r <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P0_DEVICE_addr_r <= 0;
        else if (P0_DEVICE_strobe_i)
            P0_DEVICE_addr_r <= P0_DEVICE_addr_i;
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P0_DEVICE_rw_r <= 0;
        else if (P0_DEVICE_strobe_i)
            P0_DEVICE_rw_r <= P0_DEVICE_rw_i;
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P0_DEVICE_byte_enable_r <= 0;
        else if (P0_DEVICE_strobe_i)
            P0_DEVICE_byte_enable_r <= P0_DEVICE_byte_enable_i;
    end
    
    always @(posedge clk_i) begin
        if (rst_i)
            P0_DEVICE_data_r <= 0;
        else if (P0_DEVICE_strobe_i)
            P0_DEVICE_data_r <= P0_DEVICE_data_i;
    end

    // P1-DEVICE slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P1_DEVICE_strobe_r <= 0;
        else if (P1_DEVICE_strobe_i)
            P1_DEVICE_strobe_r <= 1;
        else if (P1_DEVICE_data_ready_o)
            P1_DEVICE_strobe_r <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P1_DEVICE_addr_r <= 0;
        else if (P1_DEVICE_strobe_i)
            P1_DEVICE_addr_r <= P1_DEVICE_addr_i;
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P1_DEVICE_rw_r <= 0;
        else if (P1_DEVICE_strobe_i)
            P1_DEVICE_rw_r <= P1_DEVICE_rw_i;
    end

    always @(posedge clk_i) begin
        if (rst_i)
            P1_DEVICE_byte_enable_r <= 0;
        else if (P1_DEVICE_strobe_i)
            P1_DEVICE_byte_enable_r <= P1_DEVICE_byte_enable_i;
    end
    
    always @(posedge clk_i) begin
        if (rst_i)
            P1_DEVICE_data_r <= 0;
        else if (P1_DEVICE_strobe_i)
            P1_DEVICE_data_r <= P1_DEVICE_data_i;
    end

    //=======================================================
    //  Strobe signals selection (Round Robin) 
    //=======================================================

    assign concurrent_strobe = P0_DEVICE_strobe_r & P1_DEVICE_strobe_r;
    always @(posedge clk_i) begin
        if (rst_i) 
            sel_previous <= 0;
        else if (c_state == M_CHOOSE)
            sel_previous <= sel_current;
    end
    
    always @(posedge clk_i) begin
        if (rst_i) 
            sel_current <= 0;
        else if(c_state == M_IDLE)begin
            if (concurrent_strobe) begin
                if(sel_previous == P0_STROBE)
                    sel_current <= P1_STROBE;
                else if(sel_previous == P1_STROBE)
                    sel_current <= P0_STROBE;
            end
            else begin
                if(P0_DEVICE_strobe_r)
                    sel_current <= P0_STROBE;
                else if(P1_DEVICE_strobe_r)
                    sel_current <= P1_STROBE;
            end
        end
    end

    /* Record selected singnals*/
    always @(posedge clk_i) begin
        if (rst_i) 
            DEVICE_strobe_r <= 0;
        else if(c_state == M_CHOOSE) 
            DEVICE_strobe_r <= 1;
        else    
            DEVICE_strobe_r <= 0;
    end
    
    always @(posedge clk_i) begin
        if (rst_i) 
            DEVICE_addr_r <= 0;
        else begin
            if (sel_current == P0_STROBE)
                DEVICE_addr_r <= P0_DEVICE_addr_r;
            else if (sel_current == P1_STROBE) 
                DEVICE_addr_r <= P1_DEVICE_addr_r;
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) 
            DEVICE_rw_r <= 0;
        else begin
            if (sel_current == P0_STROBE)
                DEVICE_rw_r <= P0_DEVICE_rw_r;
            else if (sel_current == P1_STROBE) 
                DEVICE_rw_r <= P1_DEVICE_rw_r;
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) 
            DEVICE_byte_enable_r <= 0;
        else begin
            if (sel_current == P0_STROBE)
                DEVICE_byte_enable_r <= P0_DEVICE_byte_enable_r;
            else if (sel_current == P1_STROBE) 
                DEVICE_byte_enable_r <= P1_DEVICE_byte_enable_r;
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) 
            DEVICE_data_r <= 0;
        else begin
            if (sel_current == P0_STROBE)
                DEVICE_data_r <= P0_DEVICE_data_r;
            else if (sel_current == P1_STROBE) 
                DEVICE_data_r <= P1_DEVICE_data_r;
        end
    end

    //=======================================================
    //  Output logic
    //=======================================================
    assign P0_DEVICE_data_ready_o = (sel_current == P0_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    assign P0_DEVICE_data_o       = DEVICE_data_i;

    assign P1_DEVICE_data_ready_o = (sel_current == P1_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    assign P1_DEVICE_data_o       = DEVICE_data_i;
    
    assign DEVICE_strobe_o        = DEVICE_strobe_r;
    assign DEVICE_addr_o          = DEVICE_addr_r;
    assign DEVICE_rw_o            = DEVICE_rw_r;
    assign DEVICE_byte_enable_o   = DEVICE_byte_enable_r;
    assign DEVICE_data_o          = DEVICE_data_r;


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
                if(DEVICE_data_ready_i)
                    n_state = M_IDLE;
                else
                    n_state = M_WAIT;
        endcase
    end

    assign have_strobe = P0_DEVICE_strobe_r | P1_DEVICE_strobe_r;
    
endmodule