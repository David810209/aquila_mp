`timescale 1ns / 1ps
// =============================================================================
//  Program : dcache.v
//  Author  : Jin-you Wu
//  Date    : Nov/01/2018
// -----------------------------------------------------------------------------
//  Description:
//  This module implements the L1 Data Cache with the following
//  properties:
//      4-way set associative
//      FIFO replacement policy
//      Write-back
//      Write allocate
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Mar/03/2020, by Chih-Yu Hsiang:
//    Added AMO support.
//
//  Sep/24/2023, by Chun-Jen Tsai:
//    Modify the code to use distributed RAM to store VALID and DIRTY bits.
//    This modification significantly reduces the resource usage.
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

module dcache_new
#(
  parameter XLEN = 32,
  parameter CACHE_SIZE = 64,
  parameter CLSIZE = `CLP    // Cache line size.
)
(
    /////////// System signals   ///////////////////////////////////////////////
    input                     clk_i, rst_i,

    /////////// Processor signals //////////////////////////////////////////////
    input                     p_strobe_i,      // Processor request signal.
    input                     p_rw_i,          // 0 for read, 1 for write.
    input  [XLEN/8-1 : 0]     p_byte_enable_i, // Byte-enable signal.
    input  [XLEN-1 : 0]       p_addr_i,        // Memory addr of the request.
    input  [XLEN-1 : 0]       p_data_i,        // Data to main memory.
    output reg [XLEN-1 : 0]   p_data_o,        // Data from main memory.
    output                    p_ready_o,       // The cache data is ready.
    input                     p_flush_i,       // Cache flush request.,
    output     reg            busy_flushing_o, // Cache is flushing.

    /////////// Cache coherence signals  ///////////////////////////////////////
    input                     probe_strobe_i,
    input                     invalidate_i,          
    input  [XLEN-1 : 0]       probe_addr_i,  
    input  [CLSIZE-1 : 0]     coherence_data_i,
    input                     coherence_done_i, 
    input                     make_exclusive_i,

    output [CLSIZE-1 : 0]     coherence_data_o,
    output [XLEN-1 : 0]       coherence_addr_o,
    output                    coherence_strobe_o,
    output                    coherence_replacement_o,
    output                    coherence_rw_o,
    output                    share_modify_o,
    output       reg          response_ready_o,

    /////////// Test signals   /////////////////////////////////////////////////
    output reg                init_done_o ,  //for testing
    output                    test_valid_o,  //for testing
    output                    test_dirty_o,  //for testing
    output                    test_share_o   //for testing
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
wire                   way_hit[0 : N_WAYS-1];     // Cache-way hit flag.
reg  [WAY_BITS-1 : 0]  hit_index;                 // Decoded way_hit[] signal.
wire                   cache_hit;                 // Got a cache hit?
reg  [CLSIZE-1 : 0]    c_data_i;                  // Data to write into cache.
reg  [CLSIZE-1 : 0]    c_data_update;             // Updated cache data.
reg  [CLSIZE-1 : 0]    m_data_update;             // Updated memory data.
wire [CLSIZE-1 : 0]    c_block[0 : N_WAYS-1];     // Cache blocks from N cache way.
wire [CLSIZE-1 : 0]    c_data_hit;                // Data from the hit cache block.
reg                    cache_write[0 : N_WAYS-1]; // WE signal for a $ tag & block.
reg                    valid_write[0 : N_WAYS-1]; // WE signal for a $ valid bit.
reg                    dirty_write[0 : N_WAYS-1]; // WE signal for a $ dirty bit.
reg                    share_write[0 : N_WAYS-1]; // WE signal for a $ share bit.

wire [TAG_BITS-1 : 0]  c_tag_o[0 : N_WAYS-1];     // Tag bits of current $ blocks.
wire                   c_valid_o[0 : N_WAYS-1];   // Validity of current $ blocks.
wire                   c_dirty_o[0 : N_WAYS-1];   // Dirtiness of current $ blocks.
wire                   c_share_o[0 : N_WAYS-1];   // share of current $ blocks.

reg  [LINE_BITS-1 : 0] init_count;                // Counter to initialize valid bits.

integer idx;

assign c_data_hit = c_block[hit_index];

//=======================================================
// FIFO replace policy signals
//=======================================================
reg  [WAY_BITS-1 : 0] FIFO_cnt[0 : N_LINES-1];   // Replace policy counter.
reg  [WAY_BITS-1 : 0] victim_sel;                // The victim cache select.

//=======================================================
// Cache line and tag calculations
//=======================================================
wire [WORD_BITS-1 : 0] line_offset;
wire [LINE_BITS-1 : 0] line_index;
wire [TAG_BITS-1  : 0] tag;
wire [LINE_BITS-1 : 0] addr_sram;

assign line_offset =  p_addr_i[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS];
assign line_index  = p_addr_i[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS] ;
assign tag         = p_addr_i[XLEN - 1 : NONTAG_BITS];
// Control signals for flushing all cache blocks
//=======================================================
reg [LINE_BITS-1 : 0] N_LINES_cnt;
reg [WAY_BITS-1 : 0]  N_WAYS_cnt;
wire NeedtoWb = c_dirty_o[N_WAYS_cnt];
wire WbAllFinish = (N_LINES_cnt == N_LINES - 1 && N_WAYS_cnt == N_WAYS - 1);
reg WbAllFinish_r;


//=======================================================
// Cache Finite State Machine
//=======================================================
localparam Init             = 0,
           Idle             = 1,
           Analysis         = 2,
           WriteHitShare    = 3,
           WbtoMem          = 4,
           RdfromMem        = 5,
           WbtoMemAll       = 7,
           WbtoMemAllFinish = 8,
           RdAmo            = 9,
           RdAmoFinish      = 10;

// Cache controller state registers
reg [ 3 : 0] S, S_nxt;

//====================================================
// Cache Controller FSM
//====================================================
always @(posedge clk_i)
begin
    if (rst_i)
        S <= Init;
    else
        S <= S_nxt;
end

always @(*)
begin
    case (S)
        Init: // Multi-cycle initialization of the VALID bits memory.
            if (init_count < N_LINES - 1)
                S_nxt = Init;
            else
                S_nxt = Idle;
        Idle:
            if (p_strobe_i || p_flush_i)
                S_nxt = Analysis;
            else
                S_nxt = Idle;
        Analysis:
            if (busy_flushing_o)
                S_nxt = WbtoMemAll;
            else if (!cache_hit)
                // victim cache line is M/E state -> Replacement
                S_nxt = (c_valid_o[victim_sel] && !c_share_o[victim_sel])? WbtoMem : RdfromMem;
            // write hit on share state -> Invalidate remote cache
            else if(cache_hit && p_rw_i && c_share_o[hit_index])
                S_nxt = WriteHitShare;
            // hit on other state (silent)
            else
                S_nxt = Idle;
        WriteHitShare:
        // Invalidate remote cache finish -> Idle
            if (coherence_done_i)
                S_nxt = Idle;
            else
                S_nxt = WriteHitShare;
        WbtoMem:
        // wb to L2 cache finish -> Broadcasts
            if (coherence_done_i)
                S_nxt = RdfromMem;
            else
                S_nxt = WbtoMem;
        RdfromMem:
        // get response from remote cache -> Idle
            if (coherence_done_i)
                S_nxt = Idle;
            else
                S_nxt = RdfromMem;
        WbtoMemAll:
            if (NeedtoWb)
                if (coherence_done_i)
                    S_nxt = WbtoMemAllFinish;
                else
                    S_nxt = WbtoMemAll;
            else
                S_nxt = WbtoMemAllFinish;
        WbtoMemAllFinish:
            S_nxt = (WbAllFinish_r)? Idle : WbtoMemAll;
        default:
            S_nxt = Idle;
    endcase
end
//====================================================
// Cache Coherence FSM
//====================================================
reg  [ 3 : 0]          PROBE_S, PROBE_S_nxt;

localparam PROBE_Idle       = 0,
           PROBE_Analysis   = 1;
always @(posedge clk_i)
begin
    if (rst_i)
        PROBE_S <= PROBE_Idle;
    else
        PROBE_S <= PROBE_S_nxt;
end

always @(*)
begin
    case (PROBE_S)
        PROBE_Idle: 
        //remote cache get a strobe (probe from cache coherence unit)
            if(probe_strobe_i)
                PROBE_S_nxt = PROBE_Analysis;
            else
                PROBE_S_nxt = PROBE_Idle;
        PROBE_Analysis:
            PROBE_S_nxt = PROBE_Idle;
        default:
            PROBE_S_nxt = PROBE_Idle;
    endcase
end


//for testing
always @(posedge clk_i)
begin
    if (rst_i)
        init_done_o <= 0;
    else if (S == Idle)
        init_done_o <= 1;
end

assign test_valid_o = c_valid_o[hit_index];
assign test_dirty_o = c_dirty_o[hit_index];
assign test_share_o = c_share_o[hit_index];
//=======================================================
// Cache Coherence through Broadcast
//=======================================================
wire [CLSIZE-1 : 0]    probe_block[0 : N_WAYS-1];     // Cache blocks from N cache way.
wire [TAG_BITS-1 : 0]  probe_tag_o[0 : N_WAYS-1];     // Tag bits of current $ blocks.
wire                   probe_valid_o[0 : N_WAYS-1];   // Validity of current $ blocks.
wire                   probe_dirty_o[0 : N_WAYS-1];   // Dirtiness of current $ blocks.
wire                   probe_share_o[0 : N_WAYS-1];   // Share of current $ blocks.

reg                    probe_valid_write[0 : N_WAYS-1]; // WE signal for a $ valid bit.
reg                    probe_dirty_write[0 : N_WAYS-1]; // WE signal for a $ dirty bit.
reg                    probe_share_write[0 : N_WAYS-1]; // WE signal for a $ share bit.

wire [TAG_BITS-1  : 0] probe_tag;

wire                   probe_way_hit[0 : N_WAYS-1];     // Cache-way hit flag.
reg  [WAY_BITS-1 : 0]  probe_hit_index;                 // Decoded way_hit[] signal.
wire                   probe_cache_hit;                 // Got a cache hit (valid)      
wire                   probe_cache_dirty;               // Probe cache line is dirty.
wire                   probe_shared;                    // Probe cache line is shared.
// probe_cache_hit + probe_cache_dirty -> M
// probe_cache_hit + !probe_cache_dirty -> E
// probe_cache_hit + probe_shared -> S
// !probe_cache_hit -> I

wire [LINE_BITS-1 : 0] probe_line_index  = probe_addr_i[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS];
assign probe_tag         = probe_addr_i[XLEN - 1 : NONTAG_BITS];

// Check and see if any cache way has the matched memory block.
assign probe_way_hit[0] = (probe_valid_o[0] && (probe_tag_o[0] == probe_tag))? 1 : 0;
assign probe_way_hit[1] = (probe_valid_o[1] && (probe_tag_o[1] == probe_tag))? 1 : 0;
assign probe_way_hit[2] = (probe_valid_o[2] && (probe_tag_o[2] == probe_tag))? 1 : 0;
assign probe_way_hit[3] = (probe_valid_o[3] && (probe_tag_o[3] == probe_tag))? 1 : 0;

always @(*) begin
    case ( { probe_way_hit[0], probe_way_hit[1], probe_way_hit[2], probe_way_hit[3] } )
        4'b1000: probe_hit_index = 0;
        4'b0100: probe_hit_index = 1;
        4'b0010: probe_hit_index = 2;
        4'b0001: probe_hit_index = 3;
        default: probe_hit_index = 0; // error: multiple-way hit!
    endcase
end

assign probe_cache_hit  = (probe_way_hit[0] || probe_way_hit[1] || probe_way_hit[2] || probe_way_hit[3]);
assign probe_cache_dirty = probe_dirty_o[probe_hit_index];
assign probe_shared       = probe_share_o[probe_hit_index];
assign response_data_o = probe_block[probe_hit_index];
always@(posedge clk_i)
begin
    if (rst_i)
        response_ready_o <= 0;
    else if (probe_cache_hit && !probe_shared)
        response_ready_o <= 1;
    else
        response_ready_o <= 0;
end

//*** Control writing bits for cache memory using probe data. ***//

//valid bit
always @(*) begin
    if(PROBE_S == PROBE_Analysis && invalidate_i) // MESI: M/E/S -> I
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_valid_write[idx] = probe_way_hit[idx];
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_valid_write[idx] = 1'b0;
end

always @(*) begin
    if(PROBE_S == PROBE_Analysis) 
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_dirty_write[idx] = probe_way_hit[idx]; // MESI: M/E -> M  or M -> S
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_dirty_write[idx] = 1'b0;
end

always @(*) begin
     // MESI: M/E -> S
    if(PROBE_S == PROBE_Analysis && (probe_cache_hit && !probe_shared))
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_share_write[idx] = probe_way_hit[idx];
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_share_write[idx] = 1'b0;
end

// Initialization of the valid bits to zeros upon reset.
always @ (posedge clk_i)
begin
    if (S == Init)
        init_count <= init_count + 1;
    else
        init_count <= {LINE_BITS{1'b0}};
end

// Check and see if any cache way has the matched memory block.
assign way_hit[0] = (c_valid_o[0] && (c_tag_o[0] == tag))? 1 : 0;
assign way_hit[1] = (c_valid_o[1] && (c_tag_o[1] == tag))? 1 : 0;
assign way_hit[2] = (c_valid_o[2] && (c_tag_o[2] == tag))? 1 : 0;
assign way_hit[3] = (c_valid_o[3] && (c_tag_o[3] == tag))? 1 : 0;
assign cache_hit  = (way_hit[0] || way_hit[1] || way_hit[2] || way_hit[3]);

always @(*)
begin
    case ( { way_hit[0], way_hit[1], way_hit[2], way_hit[3] } )
        4'b1000: hit_index = 0;
        4'b0100: hit_index = 1;
        4'b0010: hit_index = 2;
        4'b0001: hit_index = 3;
        default: hit_index = 0; // error: multiple-way hit!
    endcase
end

always @(posedge clk_i)
begin
    victim_sel <= FIFO_cnt[line_index];
end

always @(posedge clk_i)
begin
    if (rst_i)
        for (idx = 0; idx < N_LINES; idx = idx + 1) FIFO_cnt[idx] <= 0;
    else if (S == RdfromMem && coherence_done_i)
        FIFO_cnt[line_index] <= FIFO_cnt[line_index] + 1;
end

//====================================================
// Register some input signals from the processor.
//====================================================

//=======================================================
// Wback all cache blocks to the main memory
//=======================================================
assign addr_sram = (busy_flushing_o)? N_LINES_cnt : line_index;

always @(posedge clk_i)
begin
    if (rst_i)
        N_LINES_cnt <= 0;
    else if (S_nxt == WbtoMemAllFinish)
        N_LINES_cnt <= N_LINES_cnt + 1;
end

always @(posedge clk_i)
begin
    if (rst_i)
        N_WAYS_cnt <= 0;
    else if (N_LINES_cnt == N_LINES - 1 && S_nxt == WbtoMemAllFinish)
        N_WAYS_cnt <= N_WAYS_cnt + 1;
end

always @(posedge clk_i) begin
    WbAllFinish_r <= WbAllFinish;
end

//-----------------------------------------------
// Read a 32-bit word from the target cache line
//-----------------------------------------------
reg [XLEN-1 : 0] fromCache; // Get the specific word in cache line
reg [XLEN-1 : 0] fromMem;   // Get the specific word in memory line

always @(*)
begin // for hit
    case (line_offset)
`ifdef ARTY
        2'b11: fromCache = c_data_hit[ 31: 0];     // [127: 96]
        2'b10: fromCache = c_data_hit[ 63: 32];    // [ 95: 64]
        2'b01: fromCache = c_data_hit[ 95: 64];    // [ 63: 32]
        2'b00: fromCache = c_data_hit[127: 96];    // [ 31:  0]
`else // KC705
        3'b111: fromCache = c_data_hit[ 31: 0];    // [255:224]
        3'b110: fromCache = c_data_hit[ 63: 32];   // [223:192]
        3'b101: fromCache = c_data_hit[ 95: 64];   // [191:160]
        3'b100: fromCache = c_data_hit[127: 96];   // [159:128]
        3'b011: fromCache = c_data_hit[159: 128];  // [127: 96]
        3'b010: fromCache = c_data_hit[191: 160];  // [ 95: 64]
        3'b001: fromCache = c_data_hit[223: 192];  // [ 63: 32]
        3'b000: fromCache = c_data_hit[255: 224];  // [ 31:  0]
`endif
    endcase
end

always @(*)
begin // for miss
    case (line_offset)
`ifdef ARTY
        2'b11: fromMem = coherence_data_i[ 31: 0];        // [127: 96]
        2'b10: fromMem = coherence_data_i[ 63: 32];       // [ 95: 64]
        2'b01: fromMem = coherence_data_i[ 95: 64];       // [ 63: 32]
        2'b00: fromMem = coherence_data_i[127: 96];       // [ 31:  0]
`else // KC705
        3'b111: fromMem = coherence_data_i[ 31: 0];       // [255:224]
        3'b110: fromMem = coherence_data_i[ 63: 32];      // [223:192]
        3'b101: fromMem = coherence_data_i[ 95: 64];      // [191:160]
        3'b100: fromMem = coherence_data_i[127: 96];      // [159:128]
        3'b011: fromMem = coherence_data_i[159: 128];     // [127: 96]
        3'b010: fromMem = coherence_data_i[191: 160];     // [ 95: 64]
        3'b001: fromMem = coherence_data_i[223: 192];     // [ 63: 32]
        3'b000: fromMem = coherence_data_i[255: 224];     // [ 31:  0]
`endif
    endcase
end

// Output signals   ////////////////////////////////////////////////////////////
always @(*)
begin // Note: p_data_o is significant when processor read data
    if ( (S == Analysis) && cache_hit && !p_rw_i)
        p_data_o = fromCache;
    else if ((S == RdfromMem && coherence_done_i) && !p_rw_i)
        p_data_o = fromMem;
    else
        p_data_o = {XLEN{1'b0}};
end

assign p_ready_o = ((S == Analysis) && cache_hit && !busy_flushing_o && (!p_rw_i || !c_share_o[hit_index])) ||
                    (S == RdfromMem && coherence_done_i) || (S == WriteHitShare && coherence_done_i);

//======================================================================
// Create a single-cycle memory request pluse for the memory controller
//======================================================================
// The old code uses the reqest/act protocol, which is corrected by the
// CDC synchronizer to match the strobe protocol of MIG. Modified to
// strobe protocol by Chun-Jen Tsai, 09/29/2023.
assign coherence_strobe_o = (S == RdfromMem ) && !coherence_done_i;
assign coherence_replacement_o = (S == WbtoMem || (S == WbtoMemAll && NeedtoWb) ) && !coherence_done_i;

//======================================================================

assign coherence_addr_o = (S == WbtoMemAll) ? {c_tag_o[N_WAYS_cnt], N_LINES_cnt, {WORD_BITS{1'b0}}, 2'b0} :
                  (S == WbtoMem) ? {c_tag_o[victim_sel], line_index, {WORD_BITS{1'b0}}, 2'b0} :
                  (S == RdfromMem) ? {p_addr_i[XLEN-1 : WORD_BITS+2], {WORD_BITS{1'b0}}, 2'b0} : {XLEN{1'b0}};

assign coherence_data_o = (S == WbtoMemAll && NeedtoWb) ? c_block[N_WAYS_cnt] :
                  (PROBE_S == PROBE_Analysis && probe_cache_hit) ? 
                  probe_block[probe_hit_index] :
                  (S == WriteHitShare) ? c_block[line_index] : c_block[victim_sel];

//------------------------------------------------------------------------
// Write the correct bytes according to the signal p_byte_enable_r
//------------------------------------------------------------------------
reg [XLEN-1 : 0] update_data;

always @(*)
begin           // write miss : write hit;
    case (p_byte_enable_i)
        // DataMem_Addr[1:0] == 2'b00
        4'b0001: update_data = (S == RdfromMem && coherence_done_i) ?
                      { fromMem[31:8], p_data_i[7:0] } :
                      { fromCache[31:8], p_data_i[7:0] };
        4'b0011: update_data = (S == RdfromMem && coherence_done_i) ?
                      { fromMem[31:16], p_data_i[15:0] } :
                      { fromCache[31:16], p_data_i[15:0]};
        4'b1111: update_data = p_data_i;

        // DataMem_Addr[1:0] == 2'b01
        4'b0010: update_data = (S == RdfromMem && coherence_done_i) ?
                      { fromMem[31:16], p_data_i[15:8], fromMem[7:0] } :
                      { fromCache[31 : 16], p_data_i[15:8], fromCache[7:0] };

        // DataMem_Addr[1:0] == 2'b10
        4'b0100: update_data = (S == RdfromMem && coherence_done_i) ?
                      { fromMem[31:24], p_data_i[23:16], fromMem[15:0] } :
                      { fromCache[31:24], p_data_i[23:16], fromCache[15:0] };
        4'b1100: update_data = (S == RdfromMem && coherence_done_i) ?
                      { p_data_i[31:16], fromMem[15:0] } :
                      { p_data_i[31:16], fromCache[15:0] };

        // DataMem_Addr[1:0] == 2'b11
        4'b1000: update_data = (S == RdfromMem && coherence_done_i) ?
                      { p_data_i[31:24], fromMem[23:0] } :
                      { p_data_i[31:24], fromCache[23:0] };
        default: update_data = 32'b0;
    endcase
end

//------------------------------------------------------------------------
// Write a 32-bit word into the target cache line.
//------------------------------------------------------------------------
/* Writing into cache from the processor or the main memory */
always @(*) begin
    begin
        case (line_offset)
`ifdef ARTY
            2'b11: c_data_update = {c_data_hit[127:32], update_data};
            2'b10: c_data_update = {c_data_hit[127:64], update_data, c_data_hit[31:0]};
            2'b01: c_data_update = {c_data_hit[127:96], update_data, c_data_hit[63:0]};
            2'b00: c_data_update = {update_data, c_data_hit[95:0]};
`else // KC705
    
            3'b111: c_data_update = {c_data_hit[255: 32], update_data};
            3'b110: c_data_update = {c_data_hit[255: 64], update_data, c_data_hit[ 31:0]};
            3'b101: c_data_update = {c_data_hit[255: 96], update_data, c_data_hit[ 63:0]};
            3'b100: c_data_update = {c_data_hit[255:128], update_data, c_data_hit[ 95:0]};
            3'b011: c_data_update = {c_data_hit[255:160], update_data, c_data_hit[127:0]};
            3'b010: c_data_update = {c_data_hit[255:192], update_data, c_data_hit[159:0]};
            3'b001: c_data_update = {c_data_hit[255:224], update_data, c_data_hit[191:0]};
        3'b000: c_data_update = {update_data, c_data_hit[223:0]};
`endif
        endcase
    end
end

always @(*) begin
    case (line_offset)
`ifdef ARTY
        2'b11: m_data_update = {coherence_data_i[127:32], update_data};
        2'b10: m_data_update = {coherence_data_i[127:64], update_data, coherence_data_i[31:0]};
        2'b01: m_data_update = {coherence_data_i[127:96], update_data, coherence_data_i[63:0]};
        2'b00: m_data_update = {update_data, coherence_data_i[95:0]};
`else // KC705
        3'b111: m_data_update = {coherence_data_i[255: 32], update_data};
        3'b110: m_data_update = {coherence_data_i[255: 64], update_data, coherence_data_i[ 31:0]};
        3'b101: m_data_update = {coherence_data_i[255: 96], update_data, coherence_data_i[ 63:0]};
        3'b100: m_data_update = {coherence_data_i[255:128], update_data, coherence_data_i[ 95:0]};
        3'b011: m_data_update = {coherence_data_i[255:160], update_data, coherence_data_i[127:0]};
        3'b010: m_data_update = {coherence_data_i[255:192], update_data, coherence_data_i[159:0]};
        3'b001: m_data_update = {coherence_data_i[255:224], update_data, coherence_data_i[191:0]};
        3'b000: m_data_update = {update_data, coherence_data_i[223:0]};
`endif
    endcase
end

always @(*)
begin
    if (!p_rw_i) // Processor read miss and update cache data
        c_data_i = (S == RdfromMem && coherence_done_i) ? coherence_data_i : {CLSIZE{1'b0}}; // read/write miss
    else begin   // Processor write cache
        if ( (S == Analysis) && cache_hit) // write hit
            c_data_i = c_data_update;
        else if (S == RdfromMem && coherence_done_i)     // write miss
            c_data_i = m_data_update;
        else
            c_data_i = {CLSIZE{1'b0}};
    end
end

assign coherence_rw_o = p_rw_i;
assign share_modify_o = (S == WriteHitShare); // write hit on share state
// Set a signal for flushing-in-progress notification
always @(posedge clk_i) begin
    if (rst_i)
        busy_flushing_o <= 0;
    else if (S == Idle && !busy_flushing_o)
        busy_flushing_o <= p_flush_i;
    else if (WbAllFinish_r && S == WbtoMemAllFinish)
        busy_flushing_o <= 0;
end

//=======================================================================
//  Compute the write flags for cache block & tag, valid, and dirty bits
//=======================================================================
//**** cache write ****//
always @(*) begin
    if ((S == Analysis) && cache_hit && p_rw_i)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            cache_write[idx] = way_hit[idx];
    else if (S == RdfromMem && coherence_done_i)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            cache_write[idx] = (idx == victim_sel);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            cache_write[idx] = 1'b0;
end

//**** valid write ****//
always @(*) begin
    if (S == Init)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            valid_write[idx] = 1'b1;
    else if (S == RdfromMem && coherence_done_i)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            valid_write[idx] = (idx == victim_sel);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            valid_write[idx] = 1'b0;
end

//**** dirty write ****//
always @(*) begin
    if (S == Init)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = 1'b1;
    else if (S_nxt == WbtoMemAllFinish)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = (idx == N_WAYS_cnt);
    else if ((S == RdfromMem) && coherence_done_i && p_rw_i)  //own get M
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = (idx == victim_sel);
    else if (S == Analysis && cache_hit && p_rw_i) // write hit
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = (idx == hit_index);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = 1'b0;
end

//**** share write ****//
always @(*) begin
    if (S == Init)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            share_write[idx] = 1'b1;
    else if (S == RdfromMem && coherence_done_i && !make_exclusive_i && !p_rw_i) //own get S -> S
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            share_write[idx] = (idx == victim_sel);
    else if(S == WriteHitShare && coherence_done_i) // write hit on share state
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            share_write[idx] = (idx == hit_index);
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            share_write[idx] = 1'b0;
end

//=======================================================
//  Cache data storage in Block RAM
//=======================================================
//probe write is always zero
genvar i;
generate
    for (i = 0; i < N_WAYS; i = i + 1)
    begin
        bram_dp #(.DATA_WIDTH(CLSIZE), .N_ENTRIES(N_LINES))
             DATA_BRAM(
                 .clk_i(clk_i),
                 .en_i(1'b1),
                 .a_we_i(cache_write[i]),
                 .a_addr_i(addr_sram),
                 .a_data_i(c_data_i),  // data from processor or memory.
                 .a_data_o(c_block[i]),

                 .b_we_i(1'b0), 
                 .b_addr_i(probe_line_index),
                 .b_data_i(), 
                 .b_data_o(probe_block[i])
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
                 .a_we_i(cache_write[j]),
                 .a_addr_i(addr_sram),
                 .a_data_i(tag),
                 .a_data_o(c_tag_o[j]),

                 .b_we_i(1'b0),
                 .b_addr_i(probe_line_index),
                 .b_data_i(),
                 .b_data_o(probe_tag_o[j])
             );
    end
endgenerate

//=======================================================
//  Valid bits storage in distributed RAM
//=======================================================
// MES: 1
// I: 0
// own get S   ->                 valid <= 1    (I -> E/S)
// own get M   ->                 valid <= 1    (I -> M)
// other get M ->                 valid <= 0    (M/E/S -> I)
wire valid_data = S == RdfromMem && coherence_done_i; // own get S/M

wire [LINE_BITS-1 : 0] valid_write_addr = 
            (S == Init)? init_count :
            (PROBE_S == PROBE_Analysis && invalidate_i) ? probe_line_index :  //other get M
            (S == RdfromMem && coherence_done_i) ? line_index : 0; // own get S/M


genvar k;
generate
    for (k = 0; k < N_WAYS; k = k + 1)
    begin
        distri_ram_dp #(.ENTRY_NUM(N_LINES), .XLEN(1))
             VALID_RAM(
                 .clk_i(clk_i),
                 .we_i(valid_write[k] | probe_valid_write[k]),
                  //PROBE_S == PROBE_Update && probe_cache_hit && !probe_same_wt_all => remote core write done
                 .data_i(valid_data),
                 .write_addr_i(valid_write_addr),
                 // port a
                 .a_read_addr_i(line_index),
                 .a_data_o(c_valid_o[k]),
                 // port b
                 .b_read_addr_i(probe_line_index),
                 .b_data_o(probe_valid_o[k])
             );
    end
endgenerate

//=======================================================
//  Dirty bits storage in distributed RAM 
//=======================================================
// ESI: 0
// M: 1
// own write hit ->              dirty <= 1    (M/E/S -> M)
// own get E->                    dirty <= 0    (I -> E/S)
// own get M->                    dirty <= 1    (I -> M)
wire dirty_data = (S == RdfromMem && coherence_done_i && p_rw_i) ||  // own get M
                 (S == Analysis && cache_hit && p_rw_i) ;            // own write hit

wire [LINE_BITS-1 : 0] dirty_waddr =
                     (S_nxt == WbtoMemAllFinish)? N_LINES_cnt :
                         (S == Init)? init_count :  
                ((PROBE_S == PROBE_Analysis && probe_cache_hit) ?  probe_line_index : line_index); 
genvar m;
generate
    for (m = 0; m < N_WAYS; m = m + 1)
    begin
        distri_ram_dp #(.ENTRY_NUM(N_LINES), .XLEN(1))
             DIRTY_RAM(
                 .clk_i(clk_i),
                 .we_i(dirty_write[m] | probe_dirty_write[m]),
                 //I
                 .data_i(dirty_data),
                 .write_addr_i(dirty_waddr),                 
                 // port a
                 .a_read_addr_i((S == WbtoMemAll)? N_LINES_cnt : line_index),
                 .a_data_o(c_dirty_o[m]),
                 // port b
                 .b_read_addr_i(probe_line_index),
                 .b_data_o(probe_dirty_o[m])
             );
    end
endgenerate

//=======================================================
//  Share bits storage in distributed RAM
//=======================================================
// MEI: 0
// S: 1
// own get S-> ~make_exclusive -> share <= 1    (I -> S)
// own get S-> make_exclusive ->  share <= 0    (I -> E)
// own get M->                    share <= 0    (I -> M)
// other get S ->                 share <= 1    (M/E/S -> S)
// other get M ->                 share <= 0    (M/E/S -> I) (clean share bit)
wire share_data = (PROBE_S == PROBE_Analysis && probe_cache_hit && !invalidate_i) ||          //other getS
                  (S == RdfromMem && coherence_done_i && !make_exclusive_i && !p_rw_i);      // own getS

wire [LINE_BITS-1 : 0] share_waddr =
                 ((S == RdfromMem|| S == WriteHitShare) && coherence_done_i) ?                           // own getS, getM
                  line_index  :
                ((PROBE_S == PROBE_Analysis && probe_cache_hit) ?  probe_line_index : 0 );    // other getS, get M
genvar n;
generate
    for (n = 0; n < N_WAYS; n = n + 1)
    begin
        distri_ram_dp #(.ENTRY_NUM(N_LINES), .XLEN(1))
             SHARE_RAM(
                 .clk_i(clk_i),
                 .we_i(share_write[n] | probe_share_write[n]),
                 .data_i(share_data),
                 .write_addr_i(share_waddr),       
                 // port a
                 .a_read_addr_i(line_index),
                 .a_data_o(c_share_o[n]),
                 // port b
                 .b_read_addr_i(probe_line_index),
                 .b_data_o(probe_share_o[n])
             );
    end
endgenerate

endmodule