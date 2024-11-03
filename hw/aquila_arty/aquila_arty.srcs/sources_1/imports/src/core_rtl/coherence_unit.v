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

module coherence_unit #(parameter XLEN = 32,
                        parameter CLSIZE = `CLP)
(   //===================== System signals =====================//
    input                     clk_i, rst_i,

    //==================== L1 cache signals ====================//
`ifdef ENABLE_ATOMIC_UNIT
    input  [1 : 0]            AMO_core_id,

    input                     P0_broadcast_is_amo_i,
    input                     P1_broadcast_is_amo_i,

    output                    P0_probe_is_amo_o,
    output                    P1_probe_is_amo_o,
`endif
    // From L1 D-cache 
    input                     P0_broadcast_strobe_i, 
    input                     P0_broadcast_rw_i,          
    input  [XLEN-1 : 0]       P0_broadcast_addr_i,
    input  [CLSIZE-1 : 0]     P0_broadcast_data_rd_i,  
    input                     P0_broadcast_ready_i,  // To get write data
    input                     P0_broadcast_hit_i, 
    input                     P0_broadcast_shared_i,
    input                     P0_broadcast_shared_ready_i, 

    input                     P1_broadcast_strobe_i,
    input                     P1_broadcast_rw_i,          
    input  [XLEN-1 : 0]       P1_broadcast_addr_i,
    input  [CLSIZE-1 : 0]     P1_broadcast_data_rd_i,
    input                     P1_broadcast_ready_i,  // To get write data    
    input                     P1_broadcast_hit_i,    
    input                     P1_broadcast_shared_i,
    input                     P1_broadcast_shared_ready_i,

    // TO L1 D-cache 
    output                    P0_probe_strobe_o,
    output                    P0_probe_rw_o,      
    output   [XLEN-1 : 0]     P0_probe_addr_o,
    output   [CLSIZE-1 : 0]   P0_probe_data_rd_o, 
    output   [1:0]            P0_probe_same_wt_o,
    output                    P0_probe_ready_o,
    output                    P0_probe_hit_o,       
    output                    P0_probe_shared_o,
    output                    P0_probe_shared_ready_o,
    
    output                    P1_probe_strobe_o,     
    output                    P1_probe_rw_o,    
    output   [XLEN-1 : 0]     P1_probe_addr_o,
    output   [CLSIZE-1 : 0]   P1_probe_data_rd_o, 
    output   [1:0]            P1_probe_same_wt_o,
    output                    P1_probe_ready_o, 
    output                    P1_probe_hit_o,
    output                    P1_probe_shared_o,
    output                    P1_probe_shared_ready_o
);

// Input signals
reg                    P0_broadcast_strobe_r;
reg                    P0_broadcast_rw_r;     
reg [XLEN-1 : 0]       P0_broadcast_addr_r;
reg                    P0_broadcast_ready_r;    
reg [CLSIZE-1 : 0]     P0_broadcast_data_rd_r; 
reg                    P0_broadcast_hit_r;  
reg                    P0_broadcast_shared_r; 
reg                    P0_broadcast_shared_ready_r; 
reg                    P1_broadcast_strobe_r;
reg                    P1_broadcast_rw_r;     
reg [XLEN-1 : 0]       P1_broadcast_addr_r;
reg                    P1_broadcast_ready_r;     
reg [CLSIZE-1 : 0]     P1_broadcast_data_rd_r;
reg                    P1_broadcast_hit_r; 
reg                    P1_broadcast_shared_r; 
reg                    P1_broadcast_shared_ready_r;

reg                    same_wt_req_hi; //[XLEN-1 : WORD_BITS + BYTE_BITS]
reg                    same_wt_req_lo; //[WORD_BITS + BYTE_BITS -1 : BYTE_BIT]
reg [1:0]              same_wt_req_o; // hi:10 hi+lo:11 

`ifdef ENABLE_ATOMIC_UNIT
reg                    P0_broadcast_is_amo_r;
reg                    P1_broadcast_is_amo_r;

reg                    P0_previous_is_amo;
reg                    P1_previous_is_amo;
`endif

localparam BYTE_BITS   = 2;
localparam WORD_BITS   = $clog2(CLSIZE/XLEN);
//====================================================
// Cache Coherence FSM
//====================================================
localparam Idle             = 0,
           Analysis         = 1,
           ProbeWait        = 2,
           Broadcast        = 3,
           WaitForAmo       = 4;

reg [ 2 : 0] P0_S, P0_S_nxt;
reg [ 2 : 0] P1_S, P1_S_nxt;

always @(posedge clk_i) begin
    if (rst_i)
        P0_S <= Idle;
    else
        P0_S <= P0_S_nxt;
end

always @(posedge clk_i) begin
    if (rst_i)
        P1_S <= Idle;
    else
        P1_S <= P1_S_nxt;
end

always @(*) begin
    case (P0_S)
        Idle:
`ifdef ENABLE_ATOMIC_UNIT
            if((AMO_core_id == 'b10) && (!P0_broadcast_is_amo_i && P1_broadcast_is_amo_i))  // If other is amo
                P0_S_nxt = WaitForAmo;   

            //memory request
            else if (P0_broadcast_strobe_i || (P0_broadcast_strobe_r && (AMO_core_id == 'b10) && P1_previous_is_amo))
                P0_S_nxt = Analysis;
            else
                P0_S_nxt = Idle;
`else
            if (P0_broadcast_strobe_i)
                P0_S_nxt = Analysis;
            else
                P0_S_nxt = Idle;
`endif     
        Analysis:
            if(P0_broadcast_hit_i)  // hit
            //write hit
                if(P0_broadcast_rw_r)
                    P0_S_nxt = Broadcast;
            //read hit
                else
                    P0_S_nxt = Idle;
            else                    // read/write miss
                P0_S_nxt = ProbeWait;
        ProbeWait:
        // two cores write to the same cache line
            if(same_wt_req_hi & same_wt_req_lo)
                P0_S_nxt = Idle;
            else if(P1_broadcast_shared_ready_i)
            //write done
                if(P0_broadcast_rw_r)
                    P0_S_nxt = Broadcast;
            //read done
                else begin
                    P0_S_nxt = Idle;
                end
            else
                P0_S_nxt = ProbeWait;
        Broadcast:
            if(P0_broadcast_strobe_i) //strobe occur and pervious is hit
                P0_S_nxt = Analysis;
            else 
                P0_S_nxt = Idle;
        WaitForAmo:
            if (P1_broadcast_ready_i)
                P0_S_nxt = Idle;
            else
                P0_S_nxt = WaitForAmo;
        default:
            P0_S_nxt = Idle;
    endcase
end

//一樣
always @(*) begin
    case (P1_S)
        Idle:
`ifdef ENABLE_ATOMIC_UNIT
            if((AMO_core_id == 'b01) && (!P1_broadcast_is_amo_i && P0_broadcast_is_amo_i))
                P1_S_nxt = WaitForAmo;   
            else if (P1_broadcast_strobe_i || (P1_broadcast_strobe_r && (AMO_core_id == 'b01) && P0_previous_is_amo))
                P1_S_nxt = Analysis;
            else
                P1_S_nxt = Idle;
`else
            if (P1_broadcast_strobe_i)
                P1_S_nxt = Analysis;
            else
                P1_S_nxt = Idle;
`endif     
        Analysis:
            if(P1_broadcast_hit_i)  // hit
                if(P1_broadcast_rw_r)
                    P1_S_nxt = Broadcast;   
                else
                    P1_S_nxt = Idle;
            else                    // miss
                P1_S_nxt = ProbeWait;
        ProbeWait: // read/write miss
            if(same_wt_req_hi & same_wt_req_lo)
                P1_S_nxt = Idle;
            else if(P0_broadcast_shared_ready_i)
                if(P1_broadcast_rw_r)
                    P1_S_nxt = Broadcast;
                else begin
                    P1_S_nxt = Idle;
                end
            else
                P1_S_nxt = ProbeWait;
        Broadcast: // write miss
            if(P1_broadcast_strobe_i) //strobe occur and pervious is hit
                P1_S_nxt = Analysis;
            else 
                P1_S_nxt = Idle;
        WaitForAmo:
            if (P0_broadcast_ready_i)
                P1_S_nxt = Idle;
            else
                P1_S_nxt = WaitForAmo;
        default:
            P1_S_nxt = Idle;
    endcase
end

//====================================================
// Input signals
//====================================================
//save input signal to register//////////////////////////////////////////////////////////////
// strobe
always @(posedge clk_i) begin
    if(rst_i)
        P0_broadcast_strobe_r <= 0;
    else if (P0_broadcast_strobe_i)
        P0_broadcast_strobe_r <= 1;
    else if(P0_S == Idle && !P1_previous_is_amo && P0_broadcast_ready_r)
        P0_broadcast_strobe_r <= 0;
end

always @(posedge clk_i) begin
    if(rst_i)
        P1_broadcast_strobe_r <= 0;
    else if (P1_broadcast_strobe_i)
        P1_broadcast_strobe_r <= 1;
    else if(P1_S == Idle && !P0_previous_is_amo && P1_broadcast_ready_r)
        P1_broadcast_strobe_r <= 0;
end

// rw
always @(posedge clk_i) begin
    if(rst_i)
        P0_broadcast_rw_r <= 0; 
    else if (P0_S == Idle || P0_S == Analysis)
        P0_broadcast_rw_r <= P0_broadcast_rw_i; 
end

always @(posedge clk_i) begin
    if(rst_i)
        P1_broadcast_rw_r <= 0; 
    else if (P1_S == Idle || P1_S == Analysis)  
        P1_broadcast_rw_r <= P1_broadcast_rw_i; 
end

// addr
always @(posedge clk_i) begin
    if(rst_i)
        P0_broadcast_addr_r <= 0;
    else if (P0_S == Idle || P0_S == Analysis)  
        P0_broadcast_addr_r <= P0_broadcast_addr_i;
end

always @(posedge clk_i) begin
    if(rst_i)
        P1_broadcast_addr_r <= 0;
    else if (P1_S == Idle || P1_S == Analysis)
        P1_broadcast_addr_r <= P1_broadcast_addr_i;
end

// ready
always @(posedge clk_i) begin
    if(rst_i) 
        P0_broadcast_ready_r <= 0;   
    else if (P0_broadcast_ready_i)
        P0_broadcast_ready_r <= 1;  
    else if (P0_S == Idle)
        P0_broadcast_ready_r <= 0;  
end

always @(posedge clk_i) begin
    if(rst_i) 
        P1_broadcast_ready_r <= 0;   
    else if (P1_broadcast_ready_i)
        P1_broadcast_ready_r <= 1;  
    else if (P1_S == Idle)
        P1_broadcast_ready_r <= 0;  
end

// hit
always @(posedge clk_i) begin
    if(rst_i) 
        P0_broadcast_hit_r <= 0;   
    else if (P0_S == Analysis)
        P0_broadcast_hit_r <= P0_broadcast_hit_i;  
    else if (P0_S == Idle)
        P0_broadcast_hit_r <= 0;  
end

always @(posedge clk_i) begin
    if(rst_i) 
        P1_broadcast_hit_r <= 0;   
    else if (P1_S == Analysis)
        P1_broadcast_hit_r <= P1_broadcast_hit_i;  
    else if (P1_S == Idle)
        P1_broadcast_hit_r <= 0;  
end

`ifdef ENABLE_ATOMIC_UNIT
// is_amo
always @(posedge clk_i) begin
    if(rst_i) 
        P0_broadcast_is_amo_r <= 0;  
    else if(AMO_core_id == 'b01 && !P0_broadcast_ready_i)
        P0_broadcast_is_amo_r <= P0_broadcast_is_amo_i; 
    else 
        P0_broadcast_is_amo_r <= 0;  
end

always @(posedge clk_i) begin
    if(rst_i) 
        P1_broadcast_is_amo_r <= 0;   
    else if(AMO_core_id == 'b10 && !P1_broadcast_ready_i)
        P1_broadcast_is_amo_r <= P1_broadcast_is_amo_i;  
    else 
        P1_broadcast_is_amo_r <= 0; 
end

always @(posedge clk_i) begin
    if(rst_i)
        P0_previous_is_amo <= 0;
    else 
        P0_previous_is_amo <= P0_broadcast_is_amo_r;
end

always @(posedge clk_i) begin
    if(rst_i)
        P1_previous_is_amo <= 0;
    else 
        P1_previous_is_amo <= P1_broadcast_is_amo_r;
end

`endif
//save input signal to register//////////////////////////////////////////////////////////////


/************* Read/Write Miss **************/
//沒用?
// read data
always @(posedge clk_i) begin
    if(rst_i) 
        P0_broadcast_data_rd_r <= 0;   
    else if (P1_S == ProbeWait)
        P0_broadcast_data_rd_r <= P0_broadcast_data_rd_i;   
    else if (P1_S == Idle)
        P0_broadcast_data_rd_r <= 0;       
end
//沒用?
always @(posedge clk_i) begin
    if(rst_i) 
        P1_broadcast_data_rd_r <= 0;   
    else if (P0_S == ProbeWait)
        P1_broadcast_data_rd_r <= P1_broadcast_data_rd_i;   
    else if (P0_S == Idle)
        P1_broadcast_data_rd_r <= 0;       
end

// share
//沒用?
always @(posedge clk_i) begin
    if(rst_i) 
        P0_broadcast_shared_r <= 0;   
    else if (P0_broadcast_shared_i)
        P0_broadcast_shared_r <= 1;  
    else
        P0_broadcast_shared_r <= 0;  
end

//沒用?
always @(posedge clk_i) begin
    if(rst_i) 
        P1_broadcast_shared_r <= 0;   
    else if (P1_broadcast_shared_i)
        P1_broadcast_shared_r <= 1;  
    else
        P1_broadcast_shared_r <= 0;  
end
//沒用?
always @(posedge clk_i) begin
    if(rst_i) 
        P0_broadcast_shared_ready_r <= 0;   
    else if (P0_broadcast_shared_ready_i)
        P0_broadcast_shared_ready_r <= 1;  
    else
        P0_broadcast_shared_ready_r <= 0;  
end
//沒用?
always @(posedge clk_i) begin
    if(rst_i) 
        P1_broadcast_shared_ready_r <= 0;   
    else if (P1_broadcast_shared_ready_i)
        P1_broadcast_shared_ready_r <= 1;  
    else
        P1_broadcast_shared_ready_r <= 0;  
end

/* same write request at the same time*/
always @(posedge clk_i) begin
    if(rst_i) 
        same_wt_req_hi <= 0;    
    else if (!(P0_broadcast_ready_r || P1_broadcast_ready_r) && 
             (P0_broadcast_strobe_r & P1_broadcast_strobe_r) && (P0_broadcast_rw_r & P1_broadcast_rw_r) &&
             (P0_broadcast_addr_r[XLEN-1 : WORD_BITS + BYTE_BITS] == P1_broadcast_addr_r[XLEN-1 : WORD_BITS + BYTE_BITS]))
        same_wt_req_hi <= 1;  
    else
        same_wt_req_hi <= 0;  
end

always @(posedge clk_i) begin
    if(rst_i) 
        same_wt_req_lo <= 0;    
    else if (!(P0_broadcast_ready_r || P1_broadcast_ready_r) && 
             (P0_broadcast_strobe_r & P1_broadcast_strobe_r) && (P0_broadcast_rw_r & P1_broadcast_rw_r) &&
             (P0_broadcast_addr_r[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS] == P1_broadcast_addr_r[WORD_BITS + BYTE_BITS - 1 : BYTE_BITS]))
        same_wt_req_lo <= 1;  
    else
        same_wt_req_lo <= 0;  
end

always @(*) begin
    if(rst_i) 
        same_wt_req_o = 0; 
    else if(same_wt_req_hi && same_wt_req_lo)
        same_wt_req_o = 'b11;
    else if(same_wt_req_hi && !same_wt_req_lo)
        same_wt_req_o = 'b10;  
    else 
        same_wt_req_o <= 0;
end

//====================================================
// Output signals
//====================================================
//把每個core的broadcast變成probe signal傳到其他core
/************* Core 0 **************/
assign P0_probe_strobe_o        = (P1_S == ProbeWait || P1_S == Broadcast)  ? P1_broadcast_strobe_r : 'b0;
assign P0_probe_rw_o            = (P1_S == Broadcast) ? P1_broadcast_rw_r : 'b0;   // ProbeWait: ReadFromOther
assign P0_probe_addr_o          = P1_broadcast_addr_r;
assign P0_probe_same_wt_o       = same_wt_req_o; 
assign P0_probe_ready_o         = P1_broadcast_ready_i;  
assign P0_probe_hit_o           = (P1_S == Broadcast) ? P1_broadcast_hit_r : 'b0; 
// Read/Write Miss
assign P0_probe_data_rd_o       = (P0_S == ProbeWait) ? P1_broadcast_data_rd_i      : 'b0;
assign P0_probe_shared_o        = (P0_S == ProbeWait) ? P1_broadcast_shared_i       : 'b0;
assign P0_probe_shared_ready_o  = (P0_S == ProbeWait) ? P1_broadcast_shared_ready_i : 'b0;

/************* Core 1 **************/
assign P1_probe_strobe_o        = (P0_S == ProbeWait || P0_S == Broadcast)  ? P0_broadcast_strobe_r : 'b0;
assign P1_probe_rw_o            = (P0_S == Broadcast) ? P0_broadcast_rw_r : 'b0;    // ProbeWait: ReadFromOther
assign P1_probe_addr_o          = P0_broadcast_addr_r;
assign P1_probe_same_wt_o       = same_wt_req_o; 
assign P1_probe_ready_o         = P0_broadcast_ready_i;  
assign P1_probe_hit_o           = (P0_S == Broadcast) ? P0_broadcast_hit_r : 'b0; 
// Read/Write Miss
assign P1_probe_data_rd_o       = (P1_S == ProbeWait) ? P0_broadcast_data_rd_i      : 'b0;
assign P1_probe_shared_o        = (P1_S == ProbeWait) ? P0_broadcast_shared_i       : 'b0;
assign P1_probe_shared_ready_o  = (P1_S == ProbeWait) ? P0_broadcast_shared_ready_i : 'b0;

`ifdef ENABLE_ATOMIC_UNIT
assign P0_probe_is_amo_o        = (AMO_core_id == 'b10) & P1_broadcast_is_amo_i;  
assign P1_probe_is_amo_o        = (AMO_core_id == 'b01) & P0_broadcast_is_amo_i;  
`endif
endmodule