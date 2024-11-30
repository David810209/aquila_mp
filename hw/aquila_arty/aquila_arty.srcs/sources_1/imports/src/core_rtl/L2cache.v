`timescale 1ns / 1ps
// =============================================================================
//  Program : L2cache.v
//  Author  : Lin-en Yen
//  Date    : Feb/25/2024
// -----------------------------------------------------------------------------
//  Description:
//  This module implements the dual ports L2 Cache with the following
//  properties:
//      4-way set associative
//      FIFO replacement policy
//      Write-back
//      Write allocate
// -----------------------------------------------------------------------------
//  Revision information:
//      Use only the P0 to memory interface to flush.
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

module L2cache
#(parameter XLEN = 32,
  parameter CACHE_SIZE = 64,
  parameter CLSIZE = `CLP    // Cache line size.
)
(
    //===================== System signals =====================//
    input                     clk_i, rst_i,

    //==================== L1 cache signals ====================//
    // From L1 cache 
    input                     P0_L1_strobe_i,      // L1-Cache request to memory.
    input   [XLEN-1 : 0]      P0_L1_addr_i,        // Address of the request.
    input                     P0_L1_rw_i,          // 0 for read, 1 for write.
    output reg [CLSIZE-1 : 0] P0_L1_data_o,        // Data from  L2cache controller.
    input   [CLSIZE-1 : 0]    P0_L1_data_i,        // Cache data to  L2cache controller.
    output                    P0_L1_ready_o,       // Data from  L2cache is ready.
    input                     P0_L1_same_wt_i,     // For MESI (S->I)

    input                     P1_L1_strobe_i,      // L1-Cache request to memory.
    input   [XLEN-1 : 0]      P1_L1_addr_i,        // Address of the request.
    input                     P1_L1_rw_i,          // 0 for read, 1 for write.
    output reg [CLSIZE-1 : 0] P1_L1_data_o,        // Data from  L2cache controller.
    input   [CLSIZE-1 : 0]    P1_L1_data_i,        // Cache data to  L2cache controller.
    output                    P1_L1_ready_o,       // Data from  L2cache is ready.
    input                     P1_L1_same_wt_i,     // For MESI (S->I)

    // To memory
    output reg                P0_m_strobe_o,       // L2cache request to memory.
    output reg [XLEN-1 : 0]   P0_m_addr_o,         // Address of the request.
    output reg                P0_m_rw_o,           // 0 for read, 1 for write.
    input  [CLSIZE-1 : 0]     P0_m_data_i,         // Data from memory controller.
    output reg [CLSIZE-1 : 0] P0_m_data_o,         // Cache data to memory controller.
    input                     P0_m_ready_i,        // Data from memory is ready.

    output reg                P1_m_strobe_o,       // L2cache request to memory.
    output reg [XLEN-1 : 0]   P1_m_addr_o,         // Address of the request.
    output reg                P1_m_rw_o,           // 0 for read, 1 for write.
    input  [CLSIZE-1 : 0]     P1_m_data_i,         // Data from memory controller.
    output reg [CLSIZE-1 : 0] P1_m_data_o,         // Cache data to memory controller.
    input                     P1_m_ready_i        // Data from memory is ready.
);

//=======================================================
// Cache parameters
//=======================================================
localparam N_WAYS      = 4;
localparam N_LINES     = (CACHE_SIZE*1024*8) / (N_WAYS*CLSIZE);

localparam WAY_BITS    = $clog2(N_WAYS);
localparam BYTE_BITS   = 2;
localparam WORD_BITS   = $clog2(CLSIZE/XLEN);
localparam LINE_BITS   = $clog2(N_LINES);
localparam NONTAG_BITS = LINE_BITS + WORD_BITS + BYTE_BITS;
localparam TAG_BITS    = XLEN - NONTAG_BITS;

//=======================================================
// N-way associative cache signals
//=======================================================
reg  [LINE_BITS-1 : 0] init_count;                   // Counter to initialize valid bits.

// If two cores write to the same cache line with different line offset.
reg                    same_wt_r;
reg  [CLSIZE-1 : 0]    c_data_i;  

// Core 0 
reg                    P0_L1_strobe_r;
wire                   P0_way_hit[0 : N_WAYS-1];     // Cache-way hit flag.
reg  [WAY_BITS-1 : 0]  P0_hit_index;                 // Decoded way_hit[] signal.
wire                   P0_cache_hit;                 // Got a cache hit?
reg  [CLSIZE-1 : 0]    P0_c_data_i;                  // Data to write into cache.
reg  [CLSIZE-1 : 0]    P0_c_data_update;             // Updated cache data.
wire [CLSIZE-1 : 0]    P0_c_block[0 : N_WAYS-1];     // Cache blocks from N cache way.
wire [CLSIZE-1 : 0]    P0_c_data_hit;                // Data from the hit cache block.
reg                    P0_cache_write[0 : N_WAYS-1]; // WE signal for a $ tag & block.
reg                    P0_valid_write[0 : N_WAYS-1]; // WE signal for a $ valid bit.
reg                    P0_dirty_write[0 : N_WAYS-1]; // WE signal for a $ dirty bit.
wire [TAG_BITS-1 : 0]  P0_c_tag_o[0 : N_WAYS-1];     // Tag bits of current $ blocks.
wire                   P0_c_valid_o[0 : N_WAYS-1];   // Validity of current $ blocks.
wire                   P0_c_dirty_o[0 : N_WAYS-1];   // Dirtiness of current $ blocks.

// Core 1 
reg                    P1_L1_strobe_r;
wire                   P1_way_hit[0 : N_WAYS-1];     // Cache-way hit flag.
reg  [WAY_BITS-1 : 0]  P1_hit_index;                 // Decoded way_hit[] signal.
wire                   P1_cache_hit;                 // Got a cache hit?
reg  [CLSIZE-1 : 0]    P1_c_data_i;                  // Data to write into cache.
reg  [CLSIZE-1 : 0]    P1_c_data_update;             // Updated cache data.
wire [CLSIZE-1 : 0]    P1_c_block[0 : N_WAYS-1];     // Cache blocks from N cache way.
wire [CLSIZE-1 : 0]    P1_c_data_hit;                // Data from the hit cache block.
reg                    P1_cache_write[0 : N_WAYS-1]; // WE signal for a $ tag & block.
reg                    P1_valid_write[0 : N_WAYS-1]; // WE signal for a $ valid bit.
reg                    P1_dirty_write[0 : N_WAYS-1]; // WE signal for a $ dirty bit.
wire [TAG_BITS-1 : 0]  P1_c_tag_o[0 : N_WAYS-1];     // Tag bits of current $ blocks.
wire                   P1_c_valid_o[0 : N_WAYS-1];   // Validity of current $ blocks.
wire                   P1_c_dirty_o[0 : N_WAYS-1];   // Dirtiness of current $ blocks.

integer idx;

assign P0_c_data_hit = P0_c_block[P0_hit_index];
assign P1_c_data_hit = P1_c_block[P1_hit_index];

//=======================================================
// FIFO replace policy signals 
//=======================================================
reg  [WAY_BITS-1 : 0] FIFO_cnt[0 : N_LINES-1];      // Replace policy counter.

reg  [WAY_BITS-1 : 0] P0_victim_sel;                // The victim cache select.
reg  [WAY_BITS-1 : 0] P1_victim_sel;                // The victim cache select.
//=======================================================
// Cache line and tag calculations
//=======================================================
wire [WORD_BITS-1 : 0] P0_line_offset;
wire [LINE_BITS-1 : 0] P0_line_index;
wire [TAG_BITS-1  : 0] P0_tag;
wire [LINE_BITS-1 : 0] P0_addr_sram;
reg  [XLEN-1 : 0]      P0_L1_addr_r;

wire [WORD_BITS-1 : 0] P1_line_offset;
wire [LINE_BITS-1 : 0] P1_line_index;
wire [TAG_BITS-1  : 0] P1_tag;
wire [LINE_BITS-1 : 0] P1_addr_sram;
reg  [XLEN-1 : 0]      P1_L1_addr_r;

assign P0_line_offset = (P0_L1_strobe_i)? P0_L1_addr_i[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS] : P0_L1_addr_r[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS];
assign P0_line_index  = (P0_L1_strobe_i) ? P0_L1_addr_i[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS] : P0_L1_addr_r[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS];
assign P0_tag         = P0_L1_addr_r[XLEN - 1 : NONTAG_BITS];

assign P1_line_offset = (P1_L1_strobe_i)? P1_L1_addr_i[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS] : P1_L1_addr_r[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS];
assign P1_line_index  = (P1_L1_strobe_i) ? P1_L1_addr_i[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS] : P1_L1_addr_r[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS];
assign P1_tag         = P1_L1_addr_r[XLEN - 1 : NONTAG_BITS];

//=======================================================
// Processor and memory interface signals
//=======================================================
// Core 0 and Core 1 experience a read miss in the same request.
wire same_rd_w; 
reg  same_rd_r; 

wire P0_same_rd_w; //P0 read miss 
reg  P0_same_rd_r; 
wire P1_same_rd_w; //P1 read miss 
reg  P1_same_rd_r; 

reg  P0_same_rd_done_w;
reg  P0_same_rd_done_r;
reg  P1_same_rd_done_w;
reg  P1_same_rd_done_r;
reg  same_rd_done; // delay a clock

// Input signal from processor
reg [CLSIZE-1 : 0]  P0_L1_data_r;
reg                 P0_rw_r;                 // 0 is for read, 1 is for write
reg                 P0_L1_flushing_r; 

reg [CLSIZE-1 : 0]  P1_L1_data_r;
reg                 P1_rw_r;                 // 0 is for read, 1 is for write
reg                 P1_L1_flushing_r; 


// Output signal to processor
reg                 P0_L1_ready_r;
reg                 P1_L1_ready_r;

// Input data from memory
reg [CLSIZE-1 : 0]  P0_m_data;
reg [CLSIZE-1 : 0]  P1_m_data;

//=======================================================
// Cache Finite State Machine
//=======================================================
localparam Init             = 0,
           Idle             = 1,
           Analysis         = 2,
           WbtoMem          = 3,
           WbtoMemFinish    = 4,
           RdfromMem        = 5,
           RdfromMemFinish  = 6,
           RdfromMem_WAIT   = 7;

// Cache controller state register
(* mark_debug = "true" *) reg [ 3 : 0] P0_S;
 reg [ 3 : 0]  P0_S_nxt;
reg [ 3 : 0] P1_S, P1_S_nxt;
//====================================================
// Cache Controller FSM
//====================================================
// Core 0 FSM
always @(posedge clk_i)
begin
    if (rst_i)
        P0_S <= Init;
    else
        P0_S <= P0_S_nxt;
end

always @(*)
begin
    case (P0_S)
        Init: // Multi-cycle initialization of the VALID bits memory.
            if (init_count < N_LINES - 1)
                P0_S_nxt = Init;
            else
                P0_S_nxt = Idle;
        Idle:
        //來源：
        // else if (probe_same_wt_i == 'b10) probe_same_wt_hi = 1;
        //tag一樣 代表寫到一樣的cache line
            if (P0_L1_strobe_i || P0_L1_strobe_r)
                if (P0_L1_same_wt_i)
                    if (P1_L1_same_wt_i)
                        P0_S_nxt = Analysis;
                    else
                        P0_S_nxt = Idle;
                else
                    P0_S_nxt = Analysis;
            else
                P0_S_nxt = Idle;
        Analysis:
            //cache miss
            if (!P0_cache_hit) begin
                //When a read request is made to the same address,
                // and P1 is currently reading,
                // P0 will wait until P1's read operation is complete, then use P1's the data.
                if(P0_same_rd_w) 
                    P0_S_nxt = RdfromMem_WAIT;
                else 
                    P0_S_nxt = (P0_c_dirty_o[P0_victim_sel])? WbtoMem : RdfromMem;
            end
            else // cache hit
                P0_S_nxt = Idle;
        WbtoMem:
            // write back to memory finish
            if (P0_m_ready_i)
                P0_S_nxt = WbtoMemFinish;
            else
                P0_S_nxt = WbtoMem;
        WbtoMemFinish:
            P0_S_nxt = RdfromMem;
        RdfromMem:
            //read from memory finish
            if (P0_m_ready_i)
                P0_S_nxt = RdfromMemFinish;
            else
                P0_S_nxt = RdfromMem;
        RdfromMemFinish:
            P0_S_nxt = Idle;
        RdfromMem_WAIT:
            //when P1 read done, turn to finish and use P1's data
            if(P0_same_rd_done_w || P0_same_rd_done_r)
                P0_S_nxt = RdfromMemFinish;
            else
                P0_S_nxt = RdfromMem_WAIT;
        default:
            P0_S_nxt = Idle;
    endcase
end

// Core 1 FSM
always @(posedge clk_i)
begin
    if (rst_i)
        P1_S <= Init;
    else
        P1_S <= P1_S_nxt;
end

always @(*)
begin
    case (P1_S)
        Init: // Multi-cycle initialization of the VALID bits memory.
            if (init_count < N_LINES - 1)
                P1_S_nxt = Init;
            else
                P1_S_nxt = Idle;
        Idle:
        //來源：
        // else if (probe_same_wt_i == 'b10) probe_same_wt_hi = 1;
        //tag一樣 代表寫到一樣的cache line
            if (P1_L1_strobe_i || P1_L1_strobe_r)
                if (P1_L1_same_wt_i)
                    if (P0_L1_same_wt_i)
                        P1_S_nxt = Analysis;
                    else
                        P1_S_nxt = Idle;
                else
                    P1_S_nxt = Analysis;
            else
                P1_S_nxt = Idle;
        Analysis:
        //cache miss
            if (!P1_cache_hit) begin
       //When a read request is made to the same address,
        // and P0 is currently reading or at the same state,
        // P1 will wait until P0's read operation is complete, then use P0's the data.
                if(same_rd_w || P1_same_rd_w) 
                    P1_S_nxt = RdfromMem_WAIT;
                else 
                    P1_S_nxt = (P1_c_dirty_o[P1_victim_sel])? WbtoMem : RdfromMem;
            end
            else // cache hit
                P1_S_nxt = Idle;
        WbtoMem:
        // write back to memory finish
            if (P1_m_ready_i)
                P1_S_nxt = WbtoMemFinish;
            else
                P1_S_nxt = WbtoMem;
        WbtoMemFinish:
            P1_S_nxt = RdfromMem;
        RdfromMem:
        //read from memory finish
            if (P1_m_ready_i)
                P1_S_nxt = RdfromMemFinish;
            else
                P1_S_nxt = RdfromMem;
        RdfromMemFinish:
            P1_S_nxt = Idle;
        //when P0 read done, turn to finish and use P0's data
        RdfromMem_WAIT:
            if(P1_same_rd_done_w || P1_same_rd_done_r)
                P1_S_nxt = RdfromMemFinish;
            else
                P1_S_nxt = RdfromMem_WAIT;
        default:
            P1_S_nxt = Idle;
    endcase
end

//=======================================================
// Check whether core 0 has the same request as core 1
//=======================================================
// P0 P1 read at the same time
//同時在讀 會先讓P0讀
assign same_rd_w = ((P0_S == Analysis) && (P1_S == Analysis))&& 
                        ((P0_L1_rw_i == 0) && (P1_L1_rw_i == 0))&&
                        (P0_line_index == P1_line_index) &&
                        (P0_tag == P1_tag);

always @(posedge clk_i) begin
    if(rst_i)   
        same_rd_r <= 0;
    else if(P1_S == Analysis)
        same_rd_r <= same_rd_w;
    else if(P1_S <= RdfromMemFinish)
        same_rd_r <= 0;
end

// P0_same_rd_w: P1 read first 
//兩個core讀一樣的adress且P1先讀, P0就進入wait
assign P0_same_rd_w = (P0_S == Analysis) && 
                      (P1_S != Idle && P1_S != Analysis && P1_S != RdfromMemFinish) &&
                      (P0_L1_rw_i == 0 && P1_L1_rw_i == 0) &&
                      (P0_line_index == P1_line_index) && (P0_tag == P1_tag);
                

always @(posedge clk_i) begin
    if(rst_i)   
        P0_same_rd_r <= 0;
    else if(P0_S == Analysis)
        P0_same_rd_r <= P0_same_rd_w;
    else if(P0_S == RdfromMemFinish)
        P0_same_rd_r <= 0;
end

// P1_same_rd_w: P0 read first 
//兩個core讀一樣的adress且P0先讀, P1就進入wait
assign P1_same_rd_w = (P1_S == Analysis) && 
                      (P0_S != Idle && P0_S != Analysis && P0_S != RdfromMemFinish) &&
                      (P0_L1_rw_i == 0 && P1_L1_rw_i == 0)&&
                      (P0_line_index == P1_line_index) && (P0_tag == P1_tag);
                        
always @(posedge clk_i) begin
    if(rst_i)   
        P1_same_rd_r <= 0;
    else if(P1_S == Analysis)
        P1_same_rd_r <= P1_same_rd_w;
    else if(P1_S == RdfromMemFinish)
        P1_same_rd_r <= 0;
end

// same_rd_done_w
always @(*) begin
    if((P0_same_rd_w || P0_same_rd_r) && P1_S == RdfromMem && P1_m_ready_i)
        P0_same_rd_done_w = 1;
    else 
        P0_same_rd_done_w = 0;
end

always @(*) begin
    if(same_rd_r && P0_S == RdfromMem && P0_m_ready_i)
        P1_same_rd_done_w = 1;
    else if((P1_same_rd_w || P1_same_rd_r) && P0_S == RdfromMem && P0_m_ready_i)
        P1_same_rd_done_w = 1;
    else 
        P1_same_rd_done_w = 0;
end

// same_rd_done_r
always @(posedge clk_i) begin
    if(rst_i)   
        P0_same_rd_done_r <= 0;
    else if(P0_same_rd_done_w)
        P0_same_rd_done_r <= 1;
    else if(P0_S == RdfromMemFinish)
        P0_same_rd_done_r <= 0;
end

always @(posedge clk_i) begin
    if(rst_i)   
        P1_same_rd_done_r <= 0;
    else if(P1_same_rd_done_w)
        P1_same_rd_done_r <= 1;
    else if(P1_S == RdfromMemFinish)
        P1_same_rd_done_r <= 0;
end

always @(posedge clk_i) begin
    if(rst_i)   
        same_rd_done <= 0;
    else
        same_rd_done <= P0_same_rd_done_r | P1_same_rd_done_r;
end

//====================================================
// Check if there is a cache hit or not
//====================================================

// Initialization of the valid bits to zeros upon reset.
always @ (posedge clk_i)
begin
    if (P0_S == Init && P1_S == Init)
        init_count <= init_count + 1;
    else
        init_count <= {LINE_BITS{1'b0}};
end

// Check and see if any cache way has the matched memory block.
assign P0_way_hit[0] = (P0_c_valid_o[0] && (P0_c_tag_o[0] == P0_tag))? 1 : 0;
assign P0_way_hit[1] = (P0_c_valid_o[1] && (P0_c_tag_o[1] == P0_tag))? 1 : 0;
assign P0_way_hit[2] = (P0_c_valid_o[2] && (P0_c_tag_o[2] == P0_tag))? 1 : 0;
assign P0_way_hit[3] = (P0_c_valid_o[3] && (P0_c_tag_o[3] == P0_tag))? 1 : 0;
assign P0_cache_hit  = (P0_way_hit[0] || P0_way_hit[1] || P0_way_hit[2] || P0_way_hit[3]);

assign P1_way_hit[0] = (P1_c_valid_o[0] && (P1_c_tag_o[0] == P1_tag))? 1 : 0;
assign P1_way_hit[1] = (P1_c_valid_o[1] && (P1_c_tag_o[1] == P1_tag))? 1 : 0;
assign P1_way_hit[2] = (P1_c_valid_o[2] && (P1_c_tag_o[2] == P1_tag))? 1 : 0;
assign P1_way_hit[3] = (P1_c_valid_o[3] && (P1_c_tag_o[3] == P1_tag))? 1 : 0;
assign P1_cache_hit  = (P1_way_hit[0] || P1_way_hit[1] || P1_way_hit[2] || P1_way_hit[3]);

// way hit
always @(*)
begin
    case ( { P0_way_hit[0], P0_way_hit[1], P0_way_hit[2], P0_way_hit[3] } )
        4'b1000: P0_hit_index = 0;
        4'b0100: P0_hit_index = 1;
        4'b0010: P0_hit_index = 2;
        4'b0001: P0_hit_index = 3;
        default: P0_hit_index = 0; // error: multiple-way hit!
    endcase
end

always @(*)
begin
    case ( { P1_way_hit[0], P1_way_hit[1], P1_way_hit[2], P1_way_hit[3] } )
        4'b1000: P1_hit_index = 0;
        4'b0100: P1_hit_index = 1;
        4'b0010: P1_hit_index = 2;
        4'b0001: P1_hit_index = 3;
        default: P1_hit_index = 0; // error: multiple-way hit!
    endcase
end

// victim selection
always @(posedge clk_i)
begin
    if (rst_i)
        P0_victim_sel <= 0;
    else if(P0_S == Idle)
        P0_victim_sel <= FIFO_cnt[P0_line_index];
end

always @(posedge clk_i)
begin
    if (rst_i)
        P1_victim_sel <= 0;
    else if(P1_S == Idle)
        P1_victim_sel <= FIFO_cnt[P1_line_index];
end

// FIFO record
always @(posedge clk_i)
begin
    if (rst_i)
        for (idx = 0; idx < N_LINES; idx = idx + 1) FIFO_cnt[idx] <= 0;
    else begin
        if (P0_S == RdfromMemFinish)
            FIFO_cnt[P0_line_index] <= FIFO_cnt[P0_line_index] + 1;
        else if (P1_S == RdfromMemFinish)
            FIFO_cnt[P1_line_index] <= FIFO_cnt[P1_line_index] + 1;
    end
end

//====================================================
// Register some input signals from the processor.
//====================================================
// If a strobe occurs in the initial state.
always@(posedge clk_i) begin
    if (rst_i) 
        P0_L1_strobe_r <= 0;
    //else if (P0_S == Init && P0_L1_strobe_i)
    else if (P0_L1_strobe_i)
        P0_L1_strobe_r <= 1;
    else if (P0_L1_ready_o)
        P0_L1_strobe_r <= 0;
end

always@(posedge clk_i) begin
    if (rst_i) 
        P1_L1_strobe_r <= 0;
    //else if (P1_S == Init && P1_L1_strobe_i)
    else if (P1_L1_strobe_i)
        P1_L1_strobe_r <= 1;
    else if (P1_L1_ready_o)
        P1_L1_strobe_r <= 0;
end
// Register the address from the processor.
always@(posedge clk_i) begin
    if (rst_i) begin
        P0_L1_addr_r <= 0;
    end else if (P0_L1_strobe_i) begin
        P0_L1_addr_r <= P0_L1_addr_i;
    end
end

always@(posedge clk_i) begin
    if (rst_i) begin
        P1_L1_addr_r <= 0;
    end else if (P1_L1_strobe_i) begin
        P1_L1_addr_r <= P1_L1_addr_i;
    end
end

// Register the input data from the memory.
always @(posedge clk_i)
begin
    if (rst_i)
        P0_m_data <= 0;
    else if (P0_S == RdfromMem)
        P0_m_data <= P0_m_data_i;
end

always @(posedge clk_i)
begin
    if (rst_i)  
        P1_m_data <= 0;
    else if (P1_S == RdfromMem)
        P1_m_data <= P1_m_data_i;
end

// Register the input data from the L1 cache.
always @(posedge clk_i)
begin
    if (rst_i)
        P0_L1_data_r <= 0;
    else if (P0_S == Idle)
        P0_L1_data_r <= P0_L1_data_i;
end

always @(posedge clk_i)
begin
    if (rst_i)
        P1_L1_data_r <= 0;
    else if (P1_S == Idle)
        P1_L1_data_r <= P1_L1_data_i;
end

// Register the R/W signal from the L1 cache.
always @(posedge clk_i)
begin
    if (rst_i)
        P0_rw_r <= 0;
    else if (P0_S == Idle)
        P0_rw_r <= P0_L1_rw_i;
end

always @(posedge clk_i)
begin
    if (rst_i)
        P1_rw_r <= 0;
    else if (P1_S == Idle)
        P1_rw_r <= P1_L1_rw_i;
end

always @(posedge clk_i)
begin
    if (rst_i)
        same_wt_r <= 0;
    else if(P0_S == Idle || P1_S == Idle)
    //else if(P0_S == Idle) // yyyenn 0509
    //寫到同一個address
        if((P0_L1_rw_i && P1_L1_rw_i) &&  (P0_L1_addr_i[XLEN-1 : WORD_BITS+2] == P1_L1_addr_i[XLEN-1 : WORD_BITS+2]))
            same_wt_r <= 1;
        else 
            same_wt_r <= 0;
end
//-----------------------------------------------
// Read a 32-bit word from the target cache line
//-----------------------------------------------
// Output signals

//////////debug區///////////////////////////////////
// (* mark_debug = "true" *) reg [15:0] p0_cnt, p1_cnt;
// (* mark_debug = "true" *) reg [15:0] p0_same_cnt, p1_same_cnt;
// reg p0_cnt_flag;
// reg p1_cnt_flag;
// reg p0_same_cnt_flag;
// reg p1_same_cnt_flag;
// initial begin
//     p0_cnt_flag = 0;
//     p1_cnt_flag = 0;
//     p0_cnt = 0;
//     p1_cnt = 0;
//     p0_same_cnt_flag = 0;
//     p1_same_cnt_flag = 0;
//     p0_same_cnt = 0;
//     p1_same_cnt = 0;
// end
// always @(posedge clk_i)begin
//     if(p0_cnt_flag) p0_cnt <= p0_cnt + 1;
//     if(p1_cnt_flag) p1_cnt <= p1_cnt + 1;
//     if(p0_same_cnt_flag) p0_same_cnt <= p0_same_cnt + 1;
//     if(p1_same_cnt_flag) p1_same_cnt <= p1_same_cnt + 1;
// end
////debug/////////////////////////////

// reg [4:0] t; //??沒用
always @(*)
begin // Note: P0_L1_data_o is significant when processor read data
    if ( (P0_S == Analysis) && P0_cache_hit && !P0_rw_r)begin
        P0_L1_data_o = P0_c_data_hit;
    end
        
    else if ((P0_S == RdfromMemFinish) && !P0_rw_r)
        if(P0_same_rd_r) begin
            //看為什麼要判斷這個 理論上這裡same_rd_done要是1
            if(same_rd_done)begin
                P0_L1_data_o = P1_c_block[P1_victim_sel];
                // p0_same_cnt_flag= 1;
            end
            else begin
                P0_L1_data_o = P1_m_data;
                // p0_cnt_flag = 1;
            end
        end
        else begin
            P0_L1_data_o = P0_m_data;
        end
    else begin
        P0_L1_data_o = {CLSIZE{1'b0}};
        end
        
end

always @(*)
begin // Note: P1_L1_data_o is significant when processor read data
    if ( (P1_S == Analysis) && P1_cache_hit && !P1_rw_r)
        P1_L1_data_o = P1_c_data_hit;
    else if ((P1_S == RdfromMemFinish) && !P1_rw_r)
        if(same_rd_r)
            P1_L1_data_o = P0_m_data;
        else if(P1_same_rd_r)  begin
            //看為什麼要判斷這個 理論上這裡same_rd_done要是1
            if(same_rd_done) begin
                P1_L1_data_o = P0_c_block[P0_victim_sel];
                // p1_same_cnt_flag = 1;
            end
            else begin
                // p1_cnt_flag = 1;
                P1_L1_data_o = P0_m_data;
            end
        end
        else 
            P1_L1_data_o = P1_m_data;
    else
        P1_L1_data_o = {CLSIZE{1'b0}};
end

always @(*)
begin
    if ((P0_S == Analysis && P0_cache_hit) || (P0_S == RdfromMemFinish))
        P0_L1_ready_r = 1;
    else
        P0_L1_ready_r = 0;
end

always @(*)
begin
    if ((P1_S == Analysis && P1_cache_hit) || (P1_S == RdfromMemFinish))
        P1_L1_ready_r = 1;
    else
        P1_L1_ready_r = 0;
end

assign P0_L1_ready_o = P0_L1_ready_r;
assign P1_L1_ready_o = P1_L1_ready_r;

assign P0_addr_sram = P0_line_index;
assign P1_addr_sram = P1_line_index;

//======================================================================
// Create a single-cycle memory request pluse for the memory controller
//======================================================================
// The old code uses the reqest/act protocol, which is corrected by the
// CDC synchronizer to match the strobe protocol of MIG. Modified to
// strobe protocol by Chun-Jen Tsai, 09/29/2023.
wire P0_m_strobe;
reg  P0_m_strobe_r;

wire P1_m_strobe;
reg  P1_m_strobe_r;

// Core 0 strobe to memory
assign P0_m_strobe = (P0_S == RdfromMem || P0_S == WbtoMem) && !P0_m_ready_i;

always @(posedge clk_i) begin
    P0_m_strobe_r <= P0_m_strobe;
end

always @(posedge clk_i)
begin
    if (rst_i)
        P0_m_strobe_o <= 0;
    else if (P0_m_strobe && !P0_m_strobe_r)
        P0_m_strobe_o <= 1;
    else
        P0_m_strobe_o <= 0;
end

// Core 1 strobe to memory
assign P1_m_strobe = (P1_S == RdfromMem || P1_S == WbtoMem) && !P1_m_ready_i;

always @(posedge clk_i) begin
    P1_m_strobe_r <= P1_m_strobe;
end

always @(posedge clk_i)
begin
    if (rst_i)
        P1_m_strobe_o <= 0;
    else if (P1_m_strobe && !P1_m_strobe_r)
        P1_m_strobe_o <= 1;
    else
        P1_m_strobe_o <= 0;
end
//======================================================================
// address to memory
always @(posedge clk_i)
begin
    if (rst_i)
        P0_m_addr_o <= 0;
    else if (P0_S == WbtoMem) // the dirty data addr
        P0_m_addr_o <= {P0_c_tag_o[P0_victim_sel], P0_line_index, {WORD_BITS{1'b0}}, 2'b0};
    else if (P0_S == RdfromMem) // read a cache block
        P0_m_addr_o <= {P0_L1_addr_i[XLEN-1 : WORD_BITS+2], {WORD_BITS{1'b0}}, 2'b0};
    else
        P0_m_addr_o <= {XLEN{1'b0}};
end

always @(posedge clk_i)
begin
    if (rst_i)
        P1_m_addr_o <= 0;
    else if (P1_S == WbtoMem) // the dirty data addr
        P1_m_addr_o <= {P1_c_tag_o[P1_victim_sel], P1_line_index, {WORD_BITS{1'b0}}, 2'b0};
    else if (P1_S == RdfromMem) // read a cache block
        P1_m_addr_o <= {P1_L1_addr_i[XLEN-1 : WORD_BITS+2], {WORD_BITS{1'b0}}, 2'b0};
    else
        P1_m_addr_o <= {XLEN{1'b0}};
end

// data to memory
always @(posedge clk_i)
begin
    if (rst_i)
        P0_m_data_o <= 0;
    else if (P0_S == WbtoMem) // the dirty data write back to memory
        P0_m_data_o <= P0_c_block[P0_victim_sel];
    else
        P0_m_data_o <= 0;
end

always @(posedge clk_i)
begin
    if (rst_i)
        P1_m_data_o <= 0;
    else if (P1_S == WbtoMem) 
        P1_m_data_o <= P1_c_block[P1_victim_sel];
    else
        P1_m_data_o <= 0;
end

//------------------------------------------------------------------------
// Write a 32-bit word into the target cache line.
//------------------------------------------------------------------------
// If two cores write to the same cache line with different line offsets.
always @(*)
begin
    //寫到一樣的話 把P1的data放到offset位置 其他都放P0
    //然後只更新在P0的cache (?)
    case (P1_line_offset)
`ifdef ARTY
            2'b11: c_data_i = {P0_L1_data_r[127:32], P1_L1_data_r[31:0]};
            2'b10: c_data_i = {P0_L1_data_r[127:64], P1_L1_data_r[63:32], P0_L1_data_r[31:0]};
            2'b01: c_data_i = {P0_L1_data_r[127:96], P1_L1_data_r[95:64], P0_L1_data_r[63:0]};
            2'b00: c_data_i = {P1_L1_data_r[127:96], P0_L1_data_r[95:0]};
`else // KC705
    
            3'b111: c_data_i = {P0_L1_data_r[255: 32], P1_L1_data_r[31:0]};
            3'b110: c_data_i = {P0_L1_data_r[255: 64], P1_L1_data_r[63:32],   P0_L1_data_r[ 31:0]};
            3'b101: c_data_i = {P0_L1_data_r[255: 96], P1_L1_data_r[95:64],   P0_L1_data_r[ 63:0]};
            3'b100: c_data_i = {P0_L1_data_r[255:128], P1_L1_data_r[127:96],  P0_L1_data_r[ 95:0]};
            3'b011: c_data_i = {P0_L1_data_r[255:160], P1_L1_data_r[159:128], P0_L1_data_r[127:0]};
            3'b010: c_data_i = {P0_L1_data_r[255:192], P1_L1_data_r[191:160], P0_L1_data_r[159:0]};
            3'b001: c_data_i = {P0_L1_data_r[255:224], P1_L1_data_r[223:192], P0_L1_data_r[191:0]};
            3'b000: c_data_i = {P1_L1_data_r[225:224], P0_L1_data_r[223:0]};
`endif
        endcase
end

always @(*)
begin
    if (!P0_rw_r) // Processor read miss and update cache data
        P0_c_data_i = (P0_S == RdfromMemFinish) ? P0_m_data : {CLSIZE{1'b0}};
    else begin   // Processor write cache
        if ( (P0_S == Analysis) && P0_cache_hit) // write hit
            //寫到同一個地方 (只寫到P0的cache)
            if(same_wt_r)
                P0_c_data_i = c_data_i;
            else
                P0_c_data_i = P0_L1_data_r;
        else if (P0_S == RdfromMemFinish)      // write miss
            P0_c_data_i = P0_L1_data_r;
        else
            P0_c_data_i = {CLSIZE{1'b0}};
    end
end

always @(*)
begin
    if (!P1_rw_r) // Processor read miss and update cache data
        P1_c_data_i = (P1_S == RdfromMemFinish) ? P1_m_data : {CLSIZE{1'b0}};
    else begin   // Processor write cache
        if ( (P1_S == Analysis) && P1_cache_hit) // write hit
            P1_c_data_i = P1_L1_data_r;
        else if (P1_S == RdfromMemFinish)      // write miss
            P1_c_data_i = P1_L1_data_r;
        else
            P1_c_data_i = {CLSIZE{1'b0}};
    end
end

always @(posedge clk_i)
begin
    if (rst_i)
        P0_m_rw_o <= 0;
    else if (P0_S == WbtoMem) 
        P0_m_rw_o <= 1;
    else
        P0_m_rw_o <= 0; // default: Read memory
end

always @(posedge clk_i)
begin
    if (rst_i)
        P1_m_rw_o <= 0;
    else if (P1_S == WbtoMem)
        P1_m_rw_o <= 1;
    else
        P1_m_rw_o <= 0; // default: Read memory
end



//=======================================================================
//  Compute the write flags for cache block & tag, valid, and dirty bits
//=======================================================================
// cache block
always @(*)
begin
    if ((P0_S == Analysis) && P0_cache_hit && P0_rw_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_cache_write[idx] = P0_way_hit[idx];
    else if (P0_S == RdfromMemFinish && !P0_same_rd_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_cache_write[idx] = (idx == P0_victim_sel);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_cache_write[idx] = 1'b0;
end

always @(*)
begin
    if ((P1_S == Analysis) && P1_cache_hit && P1_rw_r && !same_wt_r) //same_cache_line: P0 write
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_cache_write[idx] = P1_way_hit[idx];
    else if (P1_S == RdfromMemFinish && !(same_rd_r || P1_same_rd_r))
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_cache_write[idx] = (idx == P1_victim_sel);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_cache_write[idx] = 1'b0;
end

// vaild
always @(*)
begin
    if (P0_S == Init)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_valid_write[idx] = 1'b1;
    else if (P0_S == RdfromMem && P0_m_ready_i)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_valid_write[idx] = (idx == P0_victim_sel);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_valid_write[idx] = 1'b0;
end

always @(*)
begin
    if (P1_S == Init)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_valid_write[idx] = 1'b1;
    else if (P1_S == RdfromMem && P1_m_ready_i)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_valid_write[idx] = (idx == P1_victim_sel);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_valid_write[idx] = 1'b0;
end

// dirty
always @(*)
begin
    if (P0_S == Init)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_dirty_write[idx] = 1'b1;
    else if(P0_S_nxt == WbtoMemFinish && P0_m_ready_i && !P0_rw_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_dirty_write[idx] = (idx == P0_victim_sel);
    else if (P0_S == RdfromMem && P0_m_ready_i && P0_rw_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_dirty_write[idx] = (idx == P0_victim_sel);
    else if ((P0_S == Analysis && P0_cache_hit && P0_rw_r))
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_dirty_write[idx] = (idx == P0_hit_index);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P0_dirty_write[idx] = 1'b0;
end

always @(*)
begin
    if (P1_S == Init)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_dirty_write[idx] = 1'b1;
    else if(P1_S_nxt == WbtoMemFinish && P1_m_ready_i && !P1_rw_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_dirty_write[idx] = (idx == P1_victim_sel);
    else if (P1_S == RdfromMem && P1_m_ready_i && P1_rw_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_dirty_write[idx] = (idx == P1_victim_sel);
    else if ((P1_S == Analysis && P1_cache_hit && P1_rw_r) && !same_wt_r) //same_cache_line: P0 write
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_dirty_write[idx] = (idx == P1_hit_index);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            P1_dirty_write[idx] = 1'b0;
end

//=======================================================
//  Cache data storage in Block RAM
//=======================================================
genvar i;
generate
    for (i = 0; i < N_WAYS; i = i + 1)
    begin
        bram_dp #(.DATA_WIDTH(CLSIZE), .N_ENTRIES(N_LINES))
             DATA_BRAM(
                 .clk_i(clk_i),
                 .en_i(1'b1),
                 
                 .a_we_i  (P0_cache_write[i]),
                 .a_addr_i(P0_addr_sram),
                 .a_data_i(P0_c_data_i),  // data from processor or memory.
                 .a_data_o(P0_c_block[i]),

                 .b_we_i  (P1_cache_write[i]),
                 .b_addr_i(P1_addr_sram),
                 .b_data_i(P1_c_data_i),  // data from processor or memory.
                 .b_data_o(P1_c_block[i])
             );
    end
endgenerate

//=======================================================
//  Tags storage in Block RAM
//=======================================================
genvar j;
generate
    for (j = 0; j < N_WAYS; j = j + 1)
    begin
        bram_dp #(.DATA_WIDTH(TAG_BITS), .N_ENTRIES(N_LINES))
            TAG_BRAM(
                .clk_i(clk_i),
                .en_i(1'b1),
                
                .a_we_i  (P0_cache_write[j]),
                .a_addr_i(P0_addr_sram),
                .a_data_i(P0_tag),
                .a_data_o(P0_c_tag_o[j]),

                .b_we_i  (P1_cache_write[j]),
                .b_addr_i(P1_addr_sram),
                .b_data_i(P1_tag),
                .b_data_o(P1_c_tag_o[j])
        );
    end
endgenerate

//****************************************************************
//  Distributed RAM FIFO input 
//****************************************************************
wire                   P0_valid_req;
wire                   P1_valid_req;
wire                   P0_dirty_req;
wire                   P1_dirty_req;
reg  [WAY_BITS : 0]    P0_dirty_write_idx;// yyyenn 0418
reg  [WAY_BITS : 0]    P1_dirty_write_idx;
//**************** VALID_RAM signal ****************//
reg   valid_write_r [0 : N_WAYS-1];
reg   valid_write_w [0 : N_WAYS-1];

reg   valid_data_i_r [0 : N_WAYS-1];
reg   valid_data_i_w [0 : N_WAYS-1];

reg   valid_same_time_r [0 : N_WAYS-1];
wire  valid_same_time_w [0 : N_WAYS-1];
wire  valid_same_time_all_w;

reg [LINE_BITS-1 : 0]  valid_write_addr_r;
reg [LINE_BITS-1 : 0]  valid_write_addr_w;
//**************** DIRTY_RAM reg ****************//
reg   dirty_write_r [0 : N_WAYS-1];
reg   dirty_write_w [0 : N_WAYS-1];

reg   dirty_data_i_r [0 : N_WAYS-1];
reg   dirty_data_i_w [0 : N_WAYS-1];

reg   dirty_same_time_r [0 : N_WAYS-1];
wire  dirty_same_time_w [0 : N_WAYS-1];

reg [LINE_BITS-1 : 0]  dirty_write_addr_r;
reg [LINE_BITS-1 : 0]  dirty_write_addr_w[0 : N_WAYS-1];

// valid write_addr
assign P0_valid_req = (P0_valid_write[0] | P0_valid_write[1] | P0_valid_write[2] | P0_valid_write[3]);
assign P1_valid_req = (P1_valid_write[0] | P1_valid_write[1] | P1_valid_write[2] | P1_valid_write[3]);

assign valid_same_time_all_w = (valid_same_time_w[0] | valid_same_time_w[1] | valid_same_time_w[2] | valid_same_time_w[3]) |
                               (valid_same_time_r[0] | valid_same_time_r[1] | valid_same_time_r[2] | valid_same_time_r[3]);
always @(*) begin
    if(P0_valid_req) 
        valid_write_addr_w = P0_line_index;
    else if(valid_same_time_all_w)
        valid_write_addr_w = valid_write_addr_r;
    else if(P1_valid_req)
        valid_write_addr_w = P1_line_index;
    else
        valid_write_addr_w = 0;
end

always @(posedge clk_i) begin
    if (rst_i)
        valid_write_addr_r <= 0;
    else if(valid_same_time_all_w)
        valid_write_addr_r <= P1_line_index;
end

// dirty write_addr
assign P0_dirty_req = (P0_dirty_write[0] | P0_dirty_write[1] | P0_dirty_write[2] | P0_dirty_write[3]);
assign P1_dirty_req = (P1_dirty_write[0] | P1_dirty_write[1] | P1_dirty_write[2] | P1_dirty_write[3]);

// dirty write index
always @(*)
begin
    case ( { P0_dirty_write[0], P0_dirty_write[1], P0_dirty_write[2], P0_dirty_write[3] } )
        4'b1000: P0_dirty_write_idx = 0;
        4'b0100: P0_dirty_write_idx = 1;
        4'b0010: P0_dirty_write_idx = 2;
        4'b0001: P0_dirty_write_idx = 3;
        default: P0_dirty_write_idx = 4; // error: multiple-way hit!
    endcase
end

always @(*)
begin
    case ( { P1_dirty_write[0], P1_dirty_write[1], P1_dirty_write[2], P1_dirty_write[3] } )
        4'b1000: P1_dirty_write_idx = 0;
        4'b0100: P1_dirty_write_idx = 1;
        4'b0010: P1_dirty_write_idx = 2;
        4'b0001: P1_dirty_write_idx = 3;
        default: P1_dirty_write_idx = 4; // error: multiple-way hit!
    endcase
end


assign dirty_same_time_all_w = (dirty_same_time_w[0] | dirty_same_time_w[1] | dirty_same_time_w[2] | dirty_same_time_w[3]) |
                               (dirty_same_time_r[0] | dirty_same_time_r[1] | dirty_same_time_r[2] | dirty_same_time_r[3]);
generate
    for (i = 0; i < N_WAYS; i = i + 1) begin
        always @(*) begin
            if(P0_dirty_req && i == P0_dirty_write_idx)
                dirty_write_addr_w[i] = (P0_cache_hit) ? ((i == P0_hit_index) ? P0_line_index : 'b0) :  ((i == P0_victim_sel) ? P0_line_index : 'b0);
            else if(dirty_same_time_all_w)
                dirty_write_addr_w[i] = dirty_write_addr_r;
            else if(P1_dirty_req && i == P1_dirty_write_idx)
                dirty_write_addr_w[i] = (P1_cache_hit) ? ((i == P1_hit_index) ? P1_line_index : 'b0) :  ((i == P1_victim_sel) ? P1_line_index : 'b0);
            else
                dirty_write_addr_w[i] = 'b0;
        end
    end  
endgenerate

always @(posedge clk_i) begin
    if (rst_i)
        dirty_write_addr_r <= 0;
    else if(dirty_same_time_all_w)
        dirty_write_addr_r <= P1_line_index;
end


genvar n;
generate
    for (n = 0; n < N_WAYS; n = n + 1) begin
        //************ valid **********//
        // valid_same_time
        assign valid_same_time_w[n] = (P0_valid_write[n] & P1_valid_write[n]) ? 1'b1 :1'b0;    

        always @(posedge clk_i) begin
            if(rst_i)
                valid_same_time_r[n] <= 0;
            else if(P0_valid_write[n] & P1_valid_write[n])
                valid_same_time_r[n] <= 1;
            else if(P1_S == Idle) // P0 first
                valid_same_time_r[n] <= 0;    
        end

        // valid_write
        always @(*) begin
            if(P0_valid_write[n]) 
                valid_write_w[n] = P0_valid_write[n];
            else if(valid_same_time_r[n])
                valid_write_w[n] = valid_write_r[n];
            else if(P1_valid_write[n])
                valid_write_w[n] = P1_valid_write[n];
            else
                valid_write_w[n] = 0;
        end

        always @(posedge clk_i) begin
            if(valid_same_time_w[n]) 
                valid_write_r[n] <= 0;
            else if(valid_same_time_w[n]) 
                valid_write_r[n] <= P1_valid_write[n];
        end

        // valid_data_i
        always @(*) begin
            if(P0_valid_write[n]) 
                valid_data_i_w[n] = (P0_S == RdfromMem && P0_m_ready_i);
            else if(valid_same_time_r[n])
                valid_data_i_w[n] = valid_data_i_r[n];
            else if(P1_valid_write[n])
                valid_data_i_w[n] = (P1_S == RdfromMem && P1_m_ready_i);
            else
                valid_data_i_w[n] = 0;
        end

        always @(posedge clk_i) begin
            if (rst_i)
                valid_data_i_r[n] <= 0;
            else if(valid_same_time_w[n])
                valid_data_i_r[n] <= (P1_S == RdfromMem && P1_m_ready_i);
        end

        //************ dirty **********//
        // dirty_same_time
        // P0 first
        assign dirty_same_time_w[n] = (P0_dirty_write[n] && P1_dirty_write[n] && (P0_S != Init))  ? 1'b1 :1'b0;    
        // P1 Second
        always @(posedge clk_i) begin
            if(rst_i)
                dirty_same_time_r[n] <= 0;
            else 
                dirty_same_time_r[n] <= dirty_same_time_w[n];
        end

        // dirty_write
        always @(*) begin
            if(P0_dirty_write[n]) 
                dirty_write_w[n] = P0_dirty_write[n];
            else if(dirty_same_time_r[n])
                dirty_write_w[n] = dirty_write_r[n];
            else if(P1_dirty_write[n])
                dirty_write_w[n] = P1_dirty_write[n];
            else
                dirty_write_w[n] = 0;
        end

        always @(posedge clk_i) begin
            if (rst_i)
                dirty_write_r[n] <= 0;
            else if(dirty_same_time_w[n])
                dirty_write_r[n] <= P1_dirty_write[n];
        end

        // dirty_data_i
        always @(*) begin
            if(P0_dirty_write[n]) 
                dirty_data_i_w[n] = (P0_S_nxt == WbtoMemFinish && P0_m_ready_i && !P0_rw_r) ? 1'b0 : 1'b1;
            else if(dirty_same_time_r[n])
                dirty_data_i_w[n] = dirty_data_i_r[n];
            else if(P1_dirty_write[n])
                dirty_data_i_w[n] = (P1_S_nxt == WbtoMemFinish && P1_m_ready_i && !P1_rw_r) ? 1'b0 : 1'b1;    
            else
                dirty_data_i_w[n] = 0;
        end

        always @(posedge clk_i) begin
            if (rst_i)
                dirty_data_i_r[n] <= 0;
            else if(dirty_same_time_w[n])
                dirty_data_i_r[n] <= (P1_S_nxt == WbtoMemFinish && P1_m_ready_i && !P1_rw_r) ? 1'b0 : 1'b1;
        end
    end
endgenerate
//=======================================================
//  Valid bits storage in distributed RAM
//=======================================================
genvar k;
generate
    for (k = 0; k < N_WAYS; k = k + 1)
    begin
        distri_ram_dp #(.ENTRY_NUM(N_LINES), .XLEN(1))
             VALID_RAM(
                 .clk_i(clk_i),
                 .we_i        (valid_write_w[k]),
                 .write_addr_i((P0_S == Init)? init_count : valid_write_addr_w),
                 .data_i      ((P0_S == Init)? 1'b0 : valid_data_i_w[k]),
                 // port a
                 .a_read_addr_i (P0_line_index),
                 .a_data_o      (P0_c_valid_o[k]),
                 // port b
                 .b_read_addr_i (P1_line_index),
                 .b_data_o      (P1_c_valid_o[k])
             );
    end
endgenerate

//=======================================================
//  Dirty bits storage in distributed RAM
//=======================================================
genvar m;
generate
    for (m = 0; m < N_WAYS; m = m + 1)
    begin
        distri_ram_dp #(.ENTRY_NUM(N_LINES), .XLEN(1))
             DIRTY_RAM(
                 .clk_i(clk_i),
                 .we_i        (dirty_write_w[m]),
                 .write_addr_i((P0_S == Init) ? init_count : dirty_write_addr_w[m]),
                 .data_i      ((P0_S == Init) ? 1'b0 : dirty_data_i_w[m]),
                 //port a
                 .a_read_addr_i (P0_line_index),
                 .a_data_o      (P0_c_dirty_o[m]),
                 //port b
                 .b_read_addr_i (P1_line_index),
                 .b_data_o      (P1_c_dirty_o[m])
             );
    end
endgenerate

endmodule