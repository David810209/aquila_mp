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

module dcache
#(  parameter integer HART_ID  = 0,
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
    input                     p_flush_i,       // Cache flush request.

    /////////// External memory signals   //////////////////////////////////////
    output reg                m_strobe_o,      // Cache request to memory.
    output reg [XLEN-1 : 0]   m_addr_o,        // Address of the request.
    output reg                m_rw_o,          // 0 for read, 1 for write.
    input  [CLSIZE-1 : 0]     m_data_i,        // Data from memory controller.
    output reg [CLSIZE-1 : 0] m_data_o,        // Cache data to memory controller.
    input                     m_ready_i,       // Data from memory is ready.

    output                    same_wt_o,      // For MESI, write the same cache line (S->I + write back).
    /////////// Control signals to other caches   //////////////////////////////
    output reg                busy_flushing_o, // D-Cache is busy flushing

    /////////// AMO signals      ///////////////////////////////////////////////
    input                     p_is_amo_i,      // AMO request from core.
    input  [4 : 0]            p_amo_type_i,    // Type of AMO from core.

    /////////// Cache coherence signals  ///////////////////////////////////////
    //******* remote *******//
    input                     probe_strobe_i,
    input                     probe_rw_i,          
    input  [XLEN-1 : 0]       probe_addr_i,  
    input  [CLSIZE-1 : 0]     probe_data_rd_i,
    input  [1:0]              probe_same_wt_i,
    input                     probe_ready_i,
`ifdef ENABLE_ATOMIC_UNIT
    input  [1 : 0]            probe_amo_id_i,    
    input                     probe_is_amo_i,   
`endif    
    input                     probe_hit_i,
    input                     probe_shared_i,
    input                     probe_shared_ready_i,

    //******* local *******//
    output [CLSIZE-1 : 0]     broadcast_data_rd_o,
    output                    broadcast_RdfromOther_o,
    output                    broadcast_hit_o,
    output                    broadcast_shared_o,
    output                    broadcast_shared_ready_o
    
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
reg  [CLSIZE-1 : 0]    c_data_r;
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
reg  [XLEN-1 : 0]      p_addr_r;

assign line_offset = (p_strobe_i)? p_addr_i[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS] : p_addr_r[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS];
assign line_index  = (p_strobe_i)? p_addr_i[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS] : p_addr_r[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS];
assign tag         = p_addr_r[XLEN - 1 : NONTAG_BITS];
//=======================================================
// Processor and memory interface signals
//=======================================================

// Input signal from processor   //////////////////////////////////////////
reg                     p_strobe_r;      // if storbe in S_INIT
reg  [XLEN-1 : 0]       p_data_r;
reg                     p_rw_r;          // 0 is for read, 1 is for write
reg  [ 3 : 0]           p_byte_enable_r; // Which bytes are written if (rw == 1)

// Output signal to processor
reg                     p_ready_w;
reg                     p_ready_r;
// Input data from memory
reg  [CLSIZE-1 : 0]     m_data_r;

//=======================================================
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
localparam Init                 = 0,
           Idle                 = 1,
           Analysis             = 2,
           WbtoMem              = 3,
           WbtoMemFinish        = 4,
           RdfromMem            = 5,
           RdfromMemFinish      = 6,
           WbtoMemAll           = 7,
           WbtoMemAllFinish     = 8,
           RdfromOtherFinish    = 9,  // Probe the cache in the other core
           WaitForAmo           = 10,
           WaitForProbeUpdate_I = 11, // Waiting because a probe update occurs in the Idle state.
           WaitForProbeUpdate_A = 12, // Waiting because a probe update occurs in the Analysis state. (cache hit)
           WaitForProbeWb       = 13;
       
// Cache controller state register
reg [ 3 : 0] S, S_nxt;
//=======================================================
// Cache Coherence signals
//=======================================================
// Probe state
localparam PROBE_Idle       = 0,
           PROBE_Analysis   = 1,
           PROBE_WaitCheck  = 2,
           PROBE_Check      = 3, // If there's a read miss in another core, check this core for cache hits.
           PROBE_WaitUpdate = 4,
           PROBE_Update     = 5;

localparam PROBE_WbtoMemIdle   = 0,
           PROBE_WbtoMem       = 1,
           PROBE_WbtoMemFinish = 2;

reg  [ 3 : 0]          PROBE_S, PROBE_S_nxt;
reg  [ 1 : 0]          PROBE_WB_S, PROBE_WB_S_nxt;
reg                    previous_ready; //Avoid previous data reading from other caches, but the m_ready_i signal has arrived.
wire                   wt_same_cacheline_w;
reg                    wt_same_cacheline_r;
// Input data from other core
reg  [CLSIZE-1 : 0]    probe_data_rd_r;

reg                    probe_strobe_r;
reg                    probe_rw_r;  
reg                    probe_same_wt_hi;
reg                    probe_same_wt_all;   
reg  [XLEN-1 : 0]      probe_addr_r;        
reg                    probe_shared_r;
reg                    probe_hit_r;

wire [CLSIZE-1 : 0]    probe_block[0 : N_WAYS-1];     // Cache blocks from N cache way.
wire [TAG_BITS-1 : 0]  probe_tag_o[0 : N_WAYS-1];     // Tag bits of current $ blocks.
wire                   probe_valid_o[0 : N_WAYS-1];   // Validity of current $ blocks.
wire                   probe_dirty_o[0 : N_WAYS-1];   // Dirtiness of current $ blocks.
wire                   probe_share_o[0 : N_WAYS-1];   // Share of current $ blocks.

wire [LINE_BITS-1 : 0] probe_line_index;
reg [LINE_BITS-1 : 0]  probe_line_index_r;
wire [TAG_BITS-1  : 0] probe_tag;

wire                   probe_way_hit[0 : N_WAYS-1];     // Cache-way hit flag.
reg                    probe_way_hit_r[0 : N_WAYS-1];     // Cache-way hit flag.
reg  [WAY_BITS-1 : 0]  probe_hit_index;                 // Decoded way_hit[] signal.
wire                   probe_cache_hit;                 // Got a cache hit
reg                    probe_cache_hit_r;               
wire                   probe_cache_dirty;               // Probe cache line is dirty.

reg                    probe_cache_write[0 : N_WAYS-1]; // WE signal for a $ tag & block.
reg                    probe_valid_write[0 : N_WAYS-1]; // WE signal for a $ valid bit.
reg                    probe_dirty_write[0 : N_WAYS-1]; // WE signal for a $ dirty bit.
reg                    probe_share_write[0 : N_WAYS-1]; // WE signal for a $ share bit.
reg  [CLSIZE-1 : 0]    probe_data_update;               // Updated memory data.

wire                   probe_wb_valid; 
wire                   probe_needtoWb_w;
reg                    probe_needtoWb_r;
wire [CLSIZE-1 : 0]    probe_wb_data_w;  
reg  [CLSIZE-1 : 0]    probe_wb_data_r; 
wire [XLEN-1 : 0]      probe_wb_addr_w;     
reg  [XLEN-1 : 0]      probe_wb_addr_r;

wire                   probe_wait;
wire [1 : 0] probe_id = (HART_ID) ? 'b01 : 'b10;

reg                    OtherWt_same_addr; // same address
//====================================================
// Cache Coherence FSM
//====================================================
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
        //remote write
            if(probe_rw_i || probe_rw_r) begin
                //remote core write done
                if(probe_ready_i || probe_hit_r)
                    PROBE_S_nxt = PROBE_Update;
                //wait until remote core write done
                else
                    PROBE_S_nxt = PROBE_WaitUpdate;
            end
        //remote read
            else begin
                // 這個core正在write remote probe的address
                if(wt_same_cacheline_w)
                    PROBE_S_nxt = PROBE_WaitCheck;
                else    
                    PROBE_S_nxt = PROBE_Check;
            end
        PROBE_WaitCheck:
            //this core write done
            if(p_ready_o)
                PROBE_S_nxt = PROBE_Check;
            else    
                PROBE_S_nxt = PROBE_WaitCheck;
        PROBE_Check:
            //if strobe then go to analysis again
            if(probe_strobe_i)
                 PROBE_S_nxt = PROBE_Analysis;
            else
                PROBE_S_nxt = PROBE_Idle;
        PROBE_WaitUpdate: 
            // remote core write done
            if(probe_ready_i)
                PROBE_S_nxt = PROBE_Update;
            else
                PROBE_S_nxt = PROBE_WaitUpdate;
        PROBE_Update:
            if(probe_strobe_i)
            //if strobe then go to analysis again
                PROBE_S_nxt = PROBE_Analysis;
            else
                PROBE_S_nxt = PROBE_Idle;  
        default:
            PROBE_S_nxt = PROBE_Idle;
    endcase
end

//====================================================
// Cache Coherence write back  FSM
//====================================================
always @(posedge clk_i)
begin
    if (rst_i)
        PROBE_WB_S <= PROBE_WbtoMemIdle;
    else
        PROBE_WB_S <= PROBE_WB_S_nxt;
end

always @(*)
begin
    case (PROBE_WB_S)
        PROBE_WbtoMemIdle:
            //MESI (M -> S)
            // check if data is valid
            if(probe_needtoWb_r && probe_wb_valid)
                PROBE_WB_S_nxt = PROBE_WbtoMem;
            else
                PROBE_WB_S_nxt = PROBE_WbtoMemIdle;
            
        PROBE_WbtoMem:  
            //write to memory complete
            if(m_ready_i)
                PROBE_WB_S_nxt = PROBE_WbtoMemFinish;
            else
                PROBE_WB_S_nxt = PROBE_WbtoMem;
        PROBE_WbtoMemFinish:
            PROBE_WB_S_nxt = PROBE_WbtoMemIdle;
        default:
            PROBE_WB_S_nxt = PROBE_WbtoMemIdle;
    endcase
end

////沒用？？//////////////////////////////////////////////////////////
// reg                  probe_same_wt_update;
// reg [XLEN-1 : 0]     probe_same_wt_addr;

// always @(posedge clk_i) begin
//     if (rst_i)
//         probe_same_wt_update <= 0;
//     else if(probe_same_wt_i && (probe_addr_r[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS] != p_addr_r[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS]))
//         probe_same_wt_update <= 1;
//     else if(PROBE_WB_S_nxt == PROBE_WbtoMemIdle)
//         probe_same_wt_update <= 0;
// end

// always @(posedge clk_i) begin
//     if (rst_i)
//         probe_same_wt_addr <= 0;
//     else if(probe_same_wt_all)
//         probe_same_wt_addr <= p_addr_r;
// end
///////沒用？？/////////////////////////////////////////////////////////


//=======================================================
// Cache Coherence through Broadcast
//=======================================================
assign probe_line_index  = (probe_strobe_i)? probe_addr_i[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS] : 
                                             probe_addr_r[NONTAG_BITS - 1 : WORD_BITS + BYTE_BITS];
assign probe_tag         = probe_addr_r[XLEN - 1 : NONTAG_BITS];
// probe address == current address
assign probe_wait        = ((probe_strobe_i) && (p_rw_r && probe_rw_i) && (line_index == probe_line_index) &&
                            (tag == probe_tag)) ? 'b1 : 'b0;

always @(posedge clk_i) begin
    if (rst_i)
        probe_line_index_r <= 0;
    else
        probe_line_index_r <= probe_line_index;
end

// Check and see if any cache way has the matched memory block.
assign probe_way_hit[0] = (probe_valid_o[0] && (probe_tag_o[0] == probe_tag))? 1 : 0;
assign probe_way_hit[1] = (probe_valid_o[1] && (probe_tag_o[1] == probe_tag))? 1 : 0;
assign probe_way_hit[2] = (probe_valid_o[2] && (probe_tag_o[2] == probe_tag))? 1 : 0;
assign probe_way_hit[3] = (probe_valid_o[3] && (probe_tag_o[3] == probe_tag))? 1 : 0;
assign probe_cache_hit  = (probe_way_hit[0] || probe_way_hit[1] || probe_way_hit[2] || probe_way_hit[3]);

always @(*) begin
    case ( { probe_way_hit[0], probe_way_hit[1], probe_way_hit[2], probe_way_hit[3] } )
        4'b1000: probe_hit_index = 0;
        4'b0100: probe_hit_index = 1;
        4'b0010: probe_hit_index = 2;
        4'b0001: probe_hit_index = 3;
        default: probe_hit_index = 0; // error: multiple-way hit!
    endcase
end

assign probe_cache_dirty = probe_dirty_o[probe_hit_index];

genvar a;
generate
    for (a = 0; a < N_WAYS; a = a + 1) begin
        always @(posedge clk_i) begin
            if (rst_i)
                probe_way_hit_r[a] <= 0;
            else
                probe_way_hit_r[a] <= probe_way_hit[a];
        end
    end
endgenerate

//沒用?？//////////////////
// always @(posedge clk_i) begin
//     if (rst_i)
//         probe_cache_hit_r <= 0;
//     else
//         probe_cache_hit_r <= probe_cache_hit;
// end
//沒用?？//////////////////

//*** M -> S need to write back to memory***//
assign probe_wb_valid = (S == RdfromMem  || S == RdfromOtherFinish || S == WbtoMem || S == WbtoMemAll || S == WbtoMemAllFinish) ? 'b0 : 'b1;
// probe hit and dirty, or write to the same address
assign probe_needtoWb_w = ((PROBE_S == PROBE_Check && (probe_cache_dirty && probe_cache_hit)) || // MESI: M -> S

                          ((probe_same_wt_hi || probe_same_wt_all || (probe_same_wt_i[1] | probe_same_wt_i[0])) && 
                           (p_ready_w || p_ready_r)))// MESI: I(hi) S(all) 
                          ? 'b1 : 'b0;
assign probe_wb_data_w =(probe_same_wt_hi || probe_same_wt_all) ?
                         (p_ready_w) ? c_data_i : c_block[probe_hit_index] 
                         :  
                        (PROBE_S == PROBE_Check && (probe_cache_dirty && probe_cache_hit)) ? 
                        probe_block[probe_hit_index] : 'b0;

always @(posedge clk_i) begin
    if (rst_i)
        probe_needtoWb_r <= 0;
    else if(probe_needtoWb_w)
        probe_needtoWb_r <= 1;
    else if(PROBE_WB_S_nxt == PROBE_WbtoMemFinish)
        probe_needtoWb_r <= 0;
end

always @(posedge clk_i) begin
    if (rst_i)
        probe_wb_data_r <= 0;
    else if(probe_needtoWb_w)
        probe_wb_data_r <= probe_wb_data_w;
end

always @(posedge clk_i) begin
    if (rst_i)
        probe_wb_addr_r <= 0;
    else if(probe_needtoWb_w) begin
        if(probe_same_wt_hi)
            probe_wb_addr_r <= p_addr_r;
        else
            probe_wb_addr_r <= probe_addr_r;
    end
end

// Self-cache reading
always @(posedge clk_i) begin
    if(rst_i)
        OtherWt_same_addr <= 0;
    else if(!p_rw_r && probe_rw_r && (probe_line_index == line_index) && (probe_tag == tag))
        OtherWt_same_addr <= 1;
    else if(S == Idle)
        OtherWt_same_addr <= 0;
end
//*** Control writing bits for cache memory using probe data. ***//
//       這邊沒看清楚////////////////////////////
// probe cacha write en always 0 ??
always @(*) begin
    if (rst_i)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_cache_write[idx] = 1'b0;
    else 
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_cache_write[idx] = 1'b0;
end

//remote core write done 
// 為什麼write done是valid ?
always @(*) begin
    if(PROBE_S == PROBE_Update && probe_cache_hit && !probe_same_wt_all) // MESI: M/E/S -> I
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_valid_write[idx] = probe_way_hit[idx];
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_valid_write[idx] = 1'b0;
end

always @(*) begin
    // remote read done and need to write back
    //為什麼share是dirty?
    if(PROBE_S == PROBE_Check && probe_cache_hit && probe_needtoWb_w) // MESI: M -> S
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_dirty_write[idx] = probe_way_hit[idx];
    // remote core write done
    else if(PROBE_S == PROBE_Update && probe_cache_hit && !probe_same_wt_all) // MESI: M -> I
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_dirty_write[idx] = probe_way_hit[idx];
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_dirty_write[idx] = 1'b0;
end

always @(*) begin
    // remote read done 
    if(PROBE_S == PROBE_Check && probe_cache_hit) // MESI: M/E -> S
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_share_write[idx] = probe_way_hit[idx];
    // 為什麼invalid是share
    else if(PROBE_S == PROBE_Update && probe_cache_hit && !probe_same_wt_all) // MESI: S -> I
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_share_write[idx] = probe_way_hit[idx];
    else
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            probe_share_write[idx] = 1'b0;
end

//*** input ***//
always @(posedge clk_i) begin
    if (rst_i)
        probe_strobe_r <= 0;
    else if (probe_strobe_i)
        probe_strobe_r <= 1;
    else if (PROBE_S_nxt == PROBE_Idle)
        probe_strobe_r <= 0;
end

always @(posedge clk_i) begin
    if (rst_i)
        probe_rw_r <= 0;
    else if (PROBE_S == PROBE_Idle || probe_strobe_i)
        probe_rw_r <= probe_rw_i;
    else if (PROBE_S_nxt == PROBE_Idle)
        probe_rw_r <= 0;
end

always @(posedge clk_i) begin
    if (rst_i)
        probe_addr_r <= 0;
    else if ((PROBE_S == PROBE_Idle || PROBE_S == PROBE_Check || PROBE_S == PROBE_Update) && probe_strobe_i)
        probe_addr_r <= probe_addr_i;
end

//hi的特殊作用
always @(posedge clk_i) begin
    if (rst_i)
        probe_same_wt_hi = 0;
    else if (probe_same_wt_i == 'b10)
        probe_same_wt_hi = 1;
    else if(PROBE_WB_S == PROBE_WbtoMemFinish)
        probe_same_wt_hi = 0;
end
//
always @(posedge clk_i) begin
    if (rst_i)
        probe_same_wt_all = 0;
    else if (probe_same_wt_i == 'b11)
        probe_same_wt_all = 1;
    else if (PROBE_WB_S == PROBE_WbtoMemFinish)
        probe_same_wt_all = 0;
end

always @(posedge clk_i) begin
    if (rst_i)
        probe_shared_r <= 0;
    else if (probe_shared_i && probe_shared_ready_i)
        probe_shared_r <= 1;
    else if (S == Idle)
        probe_shared_r <= 0;
end

always @(posedge clk_i) begin
    if (rst_i)
        probe_hit_r <= 0;
    else if (PROBE_S == PROBE_Idle || (PROBE_S == PROBE_Check && probe_strobe_i))
        probe_hit_r <= probe_hit_i;
end 

//*** output ***//
assign wt_same_cacheline_w = (S == Idle) ? 'b0 : (p_addr_r[XLEN - 1 : WORD_BITS + BYTE_BITS] == probe_addr_r[XLEN - 1 : WORD_BITS + BYTE_BITS]) & p_rw_r;

always @(posedge clk_i) begin
    if (rst_i)
        wt_same_cacheline_r <= 0;
    else
        wt_same_cacheline_r <= wt_same_cacheline_w;
end 

assign broadcast_done_o         = p_ready_o;
assign broadcast_hit_o          = ((S == Analysis) && cache_hit && !probe_wait) ? 'b1 : 'b0; 
assign broadcast_data_rd_o      = (PROBE_S == PROBE_Check) ? ((wt_same_cacheline_r) ? c_data_r : 
                                                              (probe_cache_hit) ? probe_block[probe_hit_index] :'b0) : 'b0;
assign broadcast_shared_o       = (PROBE_S == PROBE_Check) && (probe_cache_hit || wt_same_cacheline_r) ? 'b1 : 'b0; 
assign broadcast_shared_ready_o = (PROBE_S == PROBE_Check) ? 'b1 : 'b0; 
 
assign broadcast_RdfromOther_o  = (S_nxt == RdfromOtherFinish) ? 'b1 : 'b0;

assign same_wt_o                = (PROBE_WB_S == PROBE_WbtoMem) ? probe_same_wt_hi : 'b0; //hi
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
`ifdef ENABLE_ATOMIC_UNIT
            if(!p_is_amo_i && probe_is_amo_i)
                S_nxt = WaitForAmo;// Wait for other amo
            else if (p_strobe_i || p_strobe_r || p_flush_i) 
                if ((probe_strobe_i || probe_strobe_r) && (p_rw_i && (probe_rw_i || probe_rw_r)) && 
                    (line_index == probe_line_index) && (tag == probe_tag))
                    S_nxt = WaitForProbeUpdate_I;
                else
                    S_nxt = Analysis;
`else
            if (p_strobe_i || p_strobe_r || p_flush_i) 
                if ((probe_strobe_i || probe_strobe_r) && (p_rw_i && (probe_rw_i || probe_rw_r)) && 
                    (line_index == probe_line_index) && (tag == probe_tag))
                    S_nxt = WaitForProbeUpdate_I;
                else
                    S_nxt = Analysis;
`endif
            else
                S_nxt = Idle;
        Analysis:
            if (busy_flushing_o)
                if (PROBE_WB_S_nxt == PROBE_WbtoMem)
                    S_nxt = Analysis;
                else
                    S_nxt = WbtoMemAll;
            else if (!cache_hit)
                if(PROBE_WB_S_nxt == PROBE_WbtoMem)
                    S_nxt = Analysis;   
                else
                    S_nxt = (c_dirty_o[victim_sel])? WbtoMem : RdfromMem;
            else// cache hit
                if ((probe_strobe_i) && (p_rw_r && probe_rw_i) && 
                    (line_index == probe_line_index) && (tag == probe_tag))
                    S_nxt = WaitForProbeUpdate_A;
                else
                    S_nxt = Idle;
        WbtoMem:
            if (m_ready_i)
                S_nxt = WbtoMemFinish;
            else
                S_nxt = WbtoMem;
        WbtoMemFinish: 
            if(PROBE_WB_S_nxt == PROBE_WbtoMem)
                S_nxt = WaitForProbeWb;
            else 
                S_nxt = RdfromMem; 
        RdfromMem: // Check the cache of the other core at the same time
            if((probe_shared_i && probe_shared_ready_i) || probe_shared_r)
                S_nxt = RdfromOtherFinish;
            else if (!probe_shared_i && m_ready_i && !previous_ready)
                S_nxt = RdfromMemFinish;
            else
                S_nxt = RdfromMem;
        RdfromMemFinish:
            S_nxt = Idle;
        WbtoMemAll:
            if (NeedtoWb)
                if (m_ready_i)
                    S_nxt = WbtoMemAllFinish;
                else
                    S_nxt = WbtoMemAll;
            else
                S_nxt = WbtoMemAllFinish;
        WbtoMemAllFinish:
            S_nxt = (WbAllFinish_r)? Idle : WbtoMemAll; 
        RdfromOtherFinish:
            S_nxt = Idle;
        WaitForAmo:
            if (probe_ready_i)
                S_nxt = Idle;
            else
                S_nxt = WaitForAmo;
        WaitForProbeUpdate_I:
            if (PROBE_S == PROBE_Update)
                S_nxt = Idle;
            else
                S_nxt = WaitForProbeUpdate_I;
        WaitForProbeUpdate_A:
            if (PROBE_S == PROBE_Update)
                S_nxt = Analysis;
            else
                S_nxt = WaitForProbeUpdate_A;
        WaitForProbeWb:
            if (m_ready_i)
                S_nxt = RdfromMem;
            else
                S_nxt = WaitForProbeWb;
        default:
            S_nxt = Idle;
    endcase
end

//Avoid previous data reading from other caches, but the m_ready_i signal has arrived. 0603
always @ (posedge clk_i)
begin
    if(S != RdfromMem && S_nxt == RdfromMem)
        previous_ready <= 1;
    else 
        previous_ready <= 0;
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
    else if (S == RdfromMemFinish)
        FIFO_cnt[line_index] <= FIFO_cnt[line_index] + 1;
end

//====================================================
// Register some input signals from the processor.
//====================================================
// If a strobe occurs in the initial state.
always@(posedge clk_i) begin
    if (rst_i) 
        p_strobe_r <= 0;
    else if (p_strobe_i)
        p_strobe_r <= 1;
    else if (p_ready_o)
        p_strobe_r <= 0;
end

// Register the address from the processor.
always@(posedge clk_i) begin
    if (rst_i)
        p_addr_r <= 0;
    else if (p_strobe_i) 
        p_addr_r <= p_addr_i;
end

// Register the input byte enable signals.
always @(posedge clk_i) begin
    if (rst_i)
        p_data_r <= 0;
    else if (S == Idle) 
        p_data_r <= p_data_i;
end

always @(posedge clk_i) begin
    if (rst_i)
        p_rw_r <= 0;
    else if (S == Idle || p_strobe_i)
        p_rw_r <= p_rw_i;
end

always @(posedge clk_i) begin
    if (rst_i)
        p_byte_enable_r <= 0;
    else if (S == Idle) 
        p_byte_enable_r <= p_byte_enable_i;
end

// Register the input data from the memory.
always @(posedge clk_i)
begin
    if (S == RdfromMem)
        m_data_r <= m_data_i;
    else
        m_data_r <= m_data_r;
end

// Register the input data from the probe.
always @(posedge clk_i)
begin
    if(probe_shared_i && probe_shared_ready_i)
        probe_data_rd_r <= probe_data_rd_i;
    else
        probe_data_rd_r <= probe_data_rd_r;
end

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
reg [XLEN-1 : 0] fromProbe_rd; // Get the specific word in probe line

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
        2'b11: fromMem = m_data_r[ 31: 0];        // [127: 96]
        2'b10: fromMem = m_data_r[ 63: 32];       // [ 95: 64]
        2'b01: fromMem = m_data_r[ 95: 64];       // [ 63: 32]
        2'b00: fromMem = m_data_r[127: 96];       // [ 31:  0]
`else // KC705
        3'b111: fromMem = m_data_r[ 31: 0];       // [255:224]
        3'b110: fromMem = m_data_r[ 63: 32];      // [223:192]
        3'b101: fromMem = m_data_r[ 95: 64];      // [191:160]
        3'b100: fromMem = m_data_r[127: 96];      // [159:128]
        3'b011: fromMem = m_data_r[159: 128];     // [127: 96]
        3'b010: fromMem = m_data_r[191: 160];     // [ 95: 64]
        3'b001: fromMem = m_data_r[223: 192];     // [ 63: 32]
        3'b000: fromMem = m_data_r[255: 224];     // [ 31:  0]
`endif
    endcase
end

always @(*)
begin // for miss
    case (line_offset)
`ifdef ARTY
        2'b11: fromProbe_rd = probe_data_rd_r[ 31: 0];        // [127: 96]
        2'b10: fromProbe_rd = probe_data_rd_r[ 63: 32];       // [ 95: 64]
        2'b01: fromProbe_rd = probe_data_rd_r[ 95: 64];       // [ 63: 32]
        2'b00: fromProbe_rd = probe_data_rd_r[127: 96];       // [ 31:  0]
`else // KC705
        3'b111: fromProbe_rd = probe_data_rd_r[ 31: 0];       // [255:224]
        3'b110: fromProbe_rd = probe_data_rd_r[ 63: 32];      // [223:192]
        3'b101: fromProbe_rd = probe_data_rd_r[ 95: 64];      // [191:160]
        3'b100: fromProbe_rd = probe_data_rd_r[127: 96];      // [159:128]
        3'b011: fromProbe_rd = probe_data_rd_r[159: 128];     // [127: 96]
        3'b010: fromProbe_rd = probe_data_rd_r[191: 160];     // [ 95: 64]
        3'b001: fromProbe_rd = probe_data_rd_r[223: 192];     // [ 63: 32]
        3'b000: fromProbe_rd = probe_data_rd_r[255: 224];     // [ 31:  0]
`endif
    endcase
end

// Output signals   ////////////////////////////////////////////////////////////
always @(*)
begin // Note: p_data_o is significant when processor read data
    if ( (S == Analysis) && cache_hit && !p_rw_r)
        p_data_o = fromCache;
    else if ((S == RdfromMemFinish) && !p_rw_r)
        p_data_o = fromMem;
    else if (S == RdfromOtherFinish)
        p_data_o = fromProbe_rd;
    else
        p_data_o = {XLEN{1'b0}};
end

always @(*)
begin
    //if (((S == Analysis) && cache_hit && !busy_flushing_o) ||
    if (((S == Analysis) && cache_hit && !busy_flushing_o && !probe_wait) ||
        (S == RdfromMemFinish) || (S == RdfromOtherFinish)) 
        p_ready_w = 1;
    else
        p_ready_w = 0;
end

assign p_ready_o = p_ready_w;

always @(posedge clk_i)
begin
    if (rst_i)
        p_ready_r <= 0;
    else 
        p_ready_r <= p_ready_w;
end

//======================================================================
// Create a single-cycle memory request pluse for the memory controller
//======================================================================
// The old code uses the reqest/act protocol, which is corrected by the
// CDC synchronizer to match the strobe protocol of MIG. Modified to
// strobe protocol by Chun-Jen Tsai, 09/29/2023.
wire m_strobe;
reg  m_strobe_r;

assign m_strobe = ((S == RdfromMem && !probe_shared_r) || S == WbtoMem || (S == WbtoMemAll && NeedtoWb) || 
                   (probe_needtoWb_r && probe_wb_valid)) && !m_ready_i;

always @(posedge clk_i)
    m_strobe_r <= m_strobe;

always @(posedge clk_i)
begin
    if (rst_i)
        m_strobe_o <= 0;
    else if (m_strobe && !m_strobe_r)
        m_strobe_o <= 1;
    else
        m_strobe_o <= 0;
end
//======================================================================

always @(posedge clk_i)
begin
    if (rst_i)
        m_addr_o <= 0;
    else if (S == WbtoMemAll)
        m_addr_o <= {c_tag_o[N_WAYS_cnt], N_LINES_cnt, {WORD_BITS{1'b0}}, 2'b0};
    else if (S == WbtoMem) // the dirty data addr
        m_addr_o <= {c_tag_o[victim_sel], line_index, {WORD_BITS{1'b0}}, 2'b0};
    else if (S == RdfromMem) // read a cache block
        m_addr_o <= {p_addr_i[XLEN-1 : WORD_BITS+2], {WORD_BITS{1'b0}}, 2'b0};
    else if (PROBE_WB_S_nxt == PROBE_WbtoMem) // write "same request" or dirty data to L2
        m_addr_o <= probe_wb_addr_r;
    else
        m_addr_o <= {XLEN{1'b0}};
end

always @(posedge clk_i)
begin
    if (rst_i)
        m_data_o <= 0;
    else if (S == WbtoMemAll && NeedtoWb)
        m_data_o <= c_block[N_WAYS_cnt];
    else if (S == WbtoMem) // the dirty data write back to memory
        m_data_o <= c_block[victim_sel];
    else if (PROBE_WB_S_nxt == PROBE_WbtoMem) // write "same request" data to L2
        m_data_o <= probe_wb_data_r;
    else
        m_data_o <= 0;
end

//------------------------------------------------------------------------
// Write the correct bytes according to the signal p_byte_enable_r
//------------------------------------------------------------------------
reg [XLEN-1 : 0] update_data;

always @(*)
begin           // write miss : write hit;
    case (p_byte_enable_r)
        // DataMem_Addr[1:0] == 2'b00
        4'b0001: update_data = (S == RdfromMemFinish) ?
                      { fromMem[31:8], p_data_r[7:0] } :
                      { fromCache[31:8], p_data_r[7:0] };
        4'b0011: update_data = (S == RdfromMemFinish) ?
                      { fromMem[31:16], p_data_r[15:0] } :
                      { fromCache[31:16], p_data_r[15:0]};
        4'b1111: update_data = p_data_r;

        // DataMem_Addr[1:0] == 2'b01
        4'b0010: update_data = (S == RdfromMemFinish) ?
                      { fromMem[31:16], p_data_r[15:8], fromMem[7:0] } :
                      { fromCache[31 : 16], p_data_r[15:8], fromCache[7:0] };

        // DataMem_Addr[1:0] == 2'b10
        4'b0100: update_data = (S == RdfromMemFinish) ?
                      { fromMem[31:24], p_data_r[23:16], fromMem[15:0] } :
                      { fromCache[31:24], p_data_r[23:16], fromCache[15:0] };
        4'b1100: update_data = (S == RdfromMemFinish) ?
                      { p_data_r[31:16], fromMem[15:0] } :
                      { p_data_r[31:16], fromCache[15:0] };

        // DataMem_Addr[1:0] == 2'b11
        4'b1000: update_data = (S == RdfromMemFinish) ?
                      { p_data_r[31:24], fromMem[23:0] } :
                      { p_data_r[31:24], fromCache[23:0] };
        default: update_data = 32'b0;
    endcase
end

//------------------------------------------------------------------------
// Write a 32-bit word into the target cache line.
//------------------------------------------------------------------------
/* Writing into cache from the processor or the main memory */
always @(*) begin
    if(p_is_amo_i)begin
        case (line_offset)
`ifdef ARTY
            2'b11: c_data_update = {c_data_hit[127:32], p_data_i};
            2'b10: c_data_update = {c_data_hit[127:64], p_data_i, c_data_hit[31:0]};
            2'b01: c_data_update = {c_data_hit[127:96], p_data_i, c_data_hit[63:0]};
            2'b00: c_data_update = {p_data_i, c_data_hit[95:0]};
`else // KC705
            3'b111: c_data_update = {c_data_hit[255: 32], p_data_i};
            3'b110: c_data_update = {c_data_hit[255: 64], p_data_i, c_data_hit[ 31:0]};
            3'b101: c_data_update = {c_data_hit[255: 96], p_data_i, c_data_hit[ 63:0]};
            3'b100: c_data_update = {c_data_hit[255:128], p_data_i, c_data_hit[ 95:0]};
            3'b011: c_data_update = {c_data_hit[255:160], p_data_i, c_data_hit[127:0]};
            3'b010: c_data_update = {c_data_hit[255:192], p_data_i, c_data_hit[159:0]};
            3'b001: c_data_update = {c_data_hit[255:224], p_data_i, c_data_hit[191:0]};
            3'b000: c_data_update = {p_data_i, c_data_hit[223:0]};
`endif
        endcase
    end

    else begin
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
        2'b11: m_data_update = {m_data_r[127:32], update_data};
        2'b10: m_data_update = {m_data_r[127:64], update_data, m_data_r[31:0]};
        2'b01: m_data_update = {m_data_r[127:96], update_data, m_data_r[63:0]};
        2'b00: m_data_update = {update_data, m_data_r[95:0]};
`else // KC705
        3'b111: m_data_update = {m_data_r[255: 32], update_data};
        3'b110: m_data_update = {m_data_r[255: 64], update_data, m_data_r[ 31:0]};
        3'b101: m_data_update = {m_data_r[255: 96], update_data, m_data_r[ 63:0]};
        3'b100: m_data_update = {m_data_r[255:128], update_data, m_data_r[ 95:0]};
        3'b011: m_data_update = {m_data_r[255:160], update_data, m_data_r[127:0]};
        3'b010: m_data_update = {m_data_r[255:192], update_data, m_data_r[159:0]};
        3'b001: m_data_update = {m_data_r[255:224], update_data, m_data_r[191:0]};
        3'b000: m_data_update = {update_data, m_data_r[223:0]};
`endif
    endcase
end

always @(*) begin
    case (line_offset)
`ifdef ARTY
        2'b11: probe_data_update = {probe_data_rd_r[127:32], update_data};
        2'b10: probe_data_update = {probe_data_rd_r[127:64], update_data, probe_data_rd_r[31:0]};
        2'b01: probe_data_update = {probe_data_rd_r[127:96], update_data, probe_data_rd_r[63:0]};
        2'b00: probe_data_update = {update_data, probe_data_rd_r [95:0]};
`else // KC705
        3'b111: probe_data_update = {probe_data_rd_r[255: 32], update_data};
        3'b110: probe_data_update = {probe_data_rd_r[255: 64], update_data, probe_data_rd_r[ 31:0]};
        3'b101: probe_data_update = {probe_data_rd_r[255: 96], update_data, probe_data_rd_r[ 63:0]};
        3'b100: probe_data_update = {probe_data_rd_r[255:128], update_data, probe_data_rd_r[ 95:0]};
        3'b011: probe_data_update = {probe_data_rd_r[255:160], update_data, probe_data_rd_r[127:0]};
        3'b010: probe_data_update = {probe_data_rd_r[255:192], update_data, probe_data_rd_r[159:0]};
        3'b001: probe_data_update = {probe_data_rd_r[255:224], update_data, probe_data_rd_r[191:0]};
        3'b000: probe_data_update = {update_data, probe_data_rd_r[223:0]};
`endif
    endcase
end

always @(*)
begin
    if (!p_rw_r) // Processor read miss and update cache data
        c_data_i = (S == RdfromMemFinish) ? m_data_r : 
                   (S == RdfromOtherFinish) ? probe_data_rd_r : {CLSIZE{1'b0}}; // read/write miss
    else begin   // Processor write cache
        if ( (S == Analysis) && cache_hit) // write hit
            c_data_i = c_data_update;
        else if (S == RdfromMemFinish)     // write miss
            c_data_i = m_data_update;
        else if (S == RdfromOtherFinish)   // write miss
            c_data_i = probe_data_update;
        else
            c_data_i = {CLSIZE{1'b0}};
    end
end

always @(posedge clk_i) begin
    if(rst_i)
        c_data_r <= 0;
    else
        c_data_r <= c_data_i;
end

always @(posedge clk_i)
begin
    if (rst_i)
        m_rw_o <= 0;
    else if (S == WbtoMem || S == WbtoMemAll || PROBE_WB_S_nxt == PROBE_WbtoMem)
        m_rw_o <= 1;
    else
        m_rw_o <= 0; // default: Read memory
end

// Set a signal for flushing-in-progress notification
always @(posedge clk_i) begin
    if (rst_i)
        busy_flushing_o <= 0;
    else if (S == Idle)
        busy_flushing_o <= p_flush_i;
    else if (WbAllFinish_r && S == WbtoMemAllFinish)
        busy_flushing_o <= 0;
end

//=======================================================================
//  Compute the write flags for cache block & tag, valid, and dirty bits
//=======================================================================
//**** cache write ****//
always @(*) begin
    if ((S == Analysis) && cache_hit && p_rw_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            cache_write[idx] = way_hit[idx];
    else if (S == RdfromMemFinish)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            cache_write[idx] = (idx == victim_sel);
    else if (S == RdfromOtherFinish)
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
    else if (S == RdfromMem && (m_ready_i || (probe_shared_i && probe_shared_ready_i) || probe_shared_r))
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
    // When a write-back occurs during a read miss, the dirty bit should be set to 0.
    else if(S_nxt == WbtoMemFinish && m_ready_i && !p_rw_r)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = (idx == victim_sel);
    else if (S_nxt == WbtoMemAllFinish)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = (idx == N_WAYS_cnt);
    // New: Reading from other cache or memory.
    else if ((S == RdfromMem) && (m_ready_i || (probe_shared_i && probe_shared_ready_i) || probe_shared_r) && p_rw_r) // MESI: I -> M
    // If the same address is written to, the dirty bit is set to 0.
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            dirty_write[idx] = (idx == victim_sel);
    else if (S == Analysis && cache_hit && p_rw_r) // MESI: E/S -> M
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
    else if (S == RdfromMem && (m_ready_i || (probe_shared_i && probe_shared_ready_i) || probe_shared_r) && !OtherWt_same_addr) 
    // If the same address is written to, the share bit is set to 1
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            share_write[idx] = (idx == victim_sel);
    else if (S == RdfromOtherFinish && !p_rw_r && !OtherWt_same_addr)
        for (idx = 0; idx < N_WAYS; idx = idx + 1)
            share_write[idx] = (idx == victim_sel);
    else if (S == Analysis && cache_hit && p_rw_r) // MESI: S -> M
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

                 .b_we_i(probe_cache_write[i]), 
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

                 .b_we_i(probe_cache_write[j]),
                 .b_addr_i(probe_line_index),
                 .b_data_i(),
                 .b_data_o(probe_tag_o[j])
             );
    end
endgenerate
//////////這邊還沒看清楚///////////////////////////////////////////////////////////////////////////
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
                 .we_i(valid_write[k] | probe_valid_write[k]),
                 .data_i((S == Init || (PROBE_S == PROBE_Update && probe_cache_hit && !probe_same_wt_all) || OtherWt_same_addr)? 1'b0 : 
                           (S == RdfromMem && (m_ready_i || (probe_shared_i && probe_shared_ready_i) || probe_shared_r) && !probe_same_wt_hi) || 
                           (S == Analysis && cache_hit && (probe_same_wt_i == 'b11))),
                 .write_addr_i((S == Init)? init_count : ((PROBE_S == PROBE_Update && probe_valid_write[k]) ? probe_line_index_r : line_index)),
                 // port a
                 .a_read_addr_i(line_index),
                 .a_data_o(c_valid_o[k]),
                 // port b
                 .b_read_addr_i((PROBE_S == PROBE_Update) ? probe_line_index_r : probe_line_index),
                 .b_data_o(probe_valid_o[k])
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
                 .we_i(dirty_write[m] | probe_dirty_write[m]),
                 .data_i((S == Init || (PROBE_S == PROBE_Update && probe_cache_hit && !probe_same_wt_all) ||
                           (PROBE_S == PROBE_Check && probe_cache_hit && probe_needtoWb_w) ||
                           (S_nxt == WbtoMemFinish && m_ready_i && !p_rw_r) ||
                           (S_nxt == WbtoMemAllFinish) || (PROBE_WB_S == WbtoMemFinish) || probe_same_wt_hi)? 1'b0 : 1'b1),
                 .write_addr_i((S == Init)? init_count : (S_nxt == WbtoMemAllFinish)? N_LINES_cnt : 
                               (((PROBE_S == PROBE_Check || PROBE_S == PROBE_Update) && probe_dirty_write[m]) ? probe_line_index_r : line_index)),                 
                 // port a
                 .a_read_addr_i((S == WbtoMemAll)? N_LINES_cnt : line_index),
                 .a_data_o(c_dirty_o[m]),
                 // port b
                 .b_read_addr_i((PROBE_S == PROBE_Update) ? probe_line_index_r : probe_line_index),
                 .b_data_o(probe_dirty_o[m])
             );
    end
endgenerate

//=======================================================
//  Share bits storage in distributed RAM
//=======================================================
genvar n;
generate
    for (n = 0; n < N_WAYS; n = n + 1)
    begin
        distri_ram_dp #(.ENTRY_NUM(N_LINES), .XLEN(1))
             SHARE_RAM(
                 .clk_i(clk_i),
                 .we_i(share_write[n] | probe_share_write[n]),
                 .data_i((S == RdfromOtherFinish && !p_rw_r) ||  probe_same_wt_all || 
                         (PROBE_S == PROBE_Check && probe_way_hit[n]) ? 1'b1 : 1'b0),
                 .write_addr_i((S == Init)? init_count : 
                               (S == RdfromMem && (m_ready_i || (probe_shared_i && probe_shared_ready_i) || probe_shared_r)) || 
                               (PROBE_S == PROBE_Update && probe_way_hit[n] && !probe_same_wt_all) || 
                               (PROBE_S == PROBE_Check && probe_way_hit[n]) ? probe_line_index_r : line_index),       
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
