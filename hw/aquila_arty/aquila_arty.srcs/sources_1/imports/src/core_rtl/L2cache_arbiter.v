// =============================================================================
//  Program : L2cache_arbiter.v
//  Author  : Lin-en Yen
//  Date    : Feb/25/2024
// -----------------------------------------------------------------------------
//  Description:
//      The arbiter for L2 Cache interface.
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

module L2cache_arbiter #(
    parameter XLEN       = 32,
    parameter CLSIZE     = `CLP)
(
    // System signals
    input                      clk_i, rst_i,

    // Aquila I-MEM slave interface (read-only)
    input                      S_IMEM_strobe_i,
    input  [XLEN-1 : 0]        S_IMEM_addr_i,
    output                     S_IMEM_done_o,
    output [CLSIZE-1 : 0]      S_IMEM_data_o,

    // Aquila D-MEM slave interface
    input                      S_DMEM_strobe_i,
    input  [XLEN-1 : 0]        S_DMEM_addr_i,
    input                      S_DMEM_rw_i,
    input  [CLSIZE-1 : 0]      S_DMEM_data_i,
    output                     S_DMEM_done_o,
    output [CLSIZE-1 : 0]      S_DMEM_data_o,
    
    input                      S_DMEM_same_wt_i, // For MESI (S->I)
    input                      S_DMEM_RdfromOther_i,

    // Aquila L2-Cache slave interface
    output                     L2_strobe_o,    // Cache request to L2-Cache.
    output [XLEN-1 : 0]        L2_addr_o,      // Address of the request.
    output                     L2_rw_o,        // 0 for read, 1 for write.
    output [CLSIZE-1 : 0]      L2_data_o,      // Cache data to L2-Cache controller.
    input  [CLSIZE-1 : 0]      L2_data_i,      // Data from L2-Cache controller.
    input                      L2_ready_i,      // Data from L2-Cache is ready.

    output                     L2_same_wt_o    // For MESI (S->I)
);

    // Strobe source, have two strobe sources (I-MEM, D-MEM) 
    localparam I_STROBE = 0,
               D_STROBE = 1;

    localparam M_IDLE = 0, // wait for strobe
               M_WAIT = 1, // wait for rd data readed from ddr

               //可刪
               M_DONE = 2; // delay one cycle, 'cause we need to reorder
                           // the readed data (for timing improvement)

    // Keep the strobe
    reg                      S_IMEM_strobe_r;
    reg  [XLEN-1 : 0]        S_IMEM_addr_r;

    reg                      S_DMEM_strobe_r;
    reg  [XLEN-1 : 0]        S_DMEM_addr_r;
    reg                      S_DMEM_rw_r;
    reg  [CLSIZE-1 : 0]      S_DMEM_data_r;
    
    reg  S_DMEM_SEC_strobe; //沒用？
    reg  S_DMEM_RdfromOther;

    // input selection signals
    reg  [1 : 0]             sel;
    reg  [XLEN-1 : 0]        addr;
    reg                      rw;
    reg  [CLSIZE-1 : 0]      wdata;

    // registered input signals
    reg  [  1 : 0]           sel_r;
    reg  [XLEN-1 : 0]        addr_r;
    reg                      rw_r;
    reg  [CLSIZE-1 : 0]      wdata_r;
    reg                      same_wt_r ;

    // FSM signals
    reg  [1 : 0]             c_state;
    reg  [1 : 0]             n_state;
    wire                     have_strobe;
    reg                      have_strobe_r;
    //=======================================================
    //  Keep the strobe (in case we miss strobe)
    //=======================================================
    // I-MEM slave interface (read only)

//這樣比較好看
// 存IMEM strobe和addr的reg
//    always @(posedge clk_i) begin
//        if (rst_i) begin 
//            S_IMEM_strobe_r <= 0;
//            S_IMEM_addr_r <= 0;
//        end
//        else if (S_IMEM_strobe_i) begin
//            S_IMEM_strobe_r <= 1;
//             S_IMEM_addr_r <= S_IMEM_addr_i;
//        end
//        else if (S_IMEM_done_o)
//            S_IMEM_strobe_r <= 0; // Clear the strobe
//    end

     always @(posedge clk_i) begin
         if (rst_i)
             S_IMEM_strobe_r <= 0;
         else if (S_IMEM_strobe_i)
             S_IMEM_strobe_r <= 1;
         else if (S_IMEM_done_o)
             S_IMEM_strobe_r <= 0; // Clear the strobe
     end

    always @(posedge clk_i) begin
         if (rst_i)
             S_IMEM_addr_r <= 0;
         else if (S_IMEM_strobe_i)
             S_IMEM_addr_r <= S_IMEM_addr_i;
     end


//這樣比較好看
// 存DMEM strobe和addr的reg
    // D-MEM slave interface
//    always @(posedge clk_i) begin
//        if (rst_i) begin
//            S_DMEM_strobe_r <= 0;
//            S_DMEM_addr_r <= 0;
//            S_DMEM_rw_r <= 0;
//            S_DMEM_data_r <= 0;
//        end
//        else if (S_DMEM_strobe_i) begin
//            S_DMEM_strobe_r <= 1;
//            S_DMEM_addr_r <= S_DMEM_addr_i;
//            S_DMEM_rw_r <= S_DMEM_rw_i;
//            S_DMEM_data_r <= S_DMEM_data_i;
//        end
//        else if (S_DMEM_done_o && !S_DMEM_RdfromOther)
//            S_DMEM_strobe_r <= 0;
//    end
     always @(posedge clk_i) begin
         if (rst_i)
             S_DMEM_strobe_r <= 0;
         else if (S_DMEM_strobe_i)
             S_DMEM_strobe_r <= 1;
         else if (S_DMEM_done_o && !S_DMEM_RdfromOther)
             S_DMEM_strobe_r <= 0;
     end
     always @(posedge clk_i) begin
         if (rst_i)
             S_DMEM_addr_r <= 0;
         else if (S_DMEM_strobe_i)
             S_DMEM_addr_r <= S_DMEM_addr_i;
     end

     always @(posedge clk_i) begin
         if (rst_i)
             S_DMEM_rw_r <= 0;
         else if (S_DMEM_strobe_i)
             S_DMEM_rw_r <= S_DMEM_rw_i;
     end

     always @(posedge clk_i) begin
         if (rst_i)
             S_DMEM_data_r <= 0;
         else if (S_DMEM_strobe_i)
             S_DMEM_data_r <= S_DMEM_data_i;
     end
    
    //沒用？？//////////////////////////////////
    always @(posedge clk_i) begin
        if (rst_i)
            S_DMEM_SEC_strobe <= 0;
        else if (c_state == M_WAIT && (sel == D_STROBE) && S_DMEM_strobe_i)
            S_DMEM_SEC_strobe <= 1;
        else if (c_state == M_IDLE)
            S_DMEM_SEC_strobe <= 0;
    end
    ///////////////

    //如果cache要從其他core直接毒data，就要把來自L2 cache的 L2 ready關掉
    always @(posedge clk_i) begin
        if (rst_i)
            S_DMEM_RdfromOther <= 0;
        else if ((c_state == M_WAIT) && (sel_r == D_STROBE && (S_DMEM_strobe_i || S_DMEM_RdfromOther_i)))
            S_DMEM_RdfromOther <= 1;
        else if (c_state == M_IDLE && sel_r == D_STROBE)
            S_DMEM_RdfromOther <= 0;
    end
    //================================================================================
    //  Strobe signals selection (Priority : D-MEM > I-MEM because of cache coherence)
    //================================================================================
    always @(*) begin
        if (S_DMEM_strobe_r) 
            sel = D_STROBE;
        else if (S_IMEM_strobe_r) 
            sel = I_STROBE;
        else
            sel = 0;
    end

    //這樣比較好看
    //用sel來選要用i的還是d的 addr, rw, wdata

    // always @(*) begin
    //     case (sel)
    //         I_STROBE: begin
    //              addr = S_IMEM_addr_r;
    //              rw = 0; // I-MEM is read-only
    //              wdata = 0; // I-MEM is read-only
    //         end
    //         D_STROBE: begin
    //              addr = S_DMEM_addr_r;
    //               rw = S_DMEM_rw_r;
    //               wdata = S_DMEM_data_r;
    //         end
    //         default : begin 
    //              addr = 0;
    //              rw = 0;
    //              wdata = {CLSIZE{1'b0}};
    //         end
    //     endcase
    // end
    always @(*) begin
        case (sel)
            I_STROBE: addr = S_IMEM_addr_r;
            D_STROBE: addr = S_DMEM_addr_r;
            default : addr = 0;
        endcase
    end

    always @(*) begin
        case (sel)
            I_STROBE: rw = 0; // I-MEM is read-only
            D_STROBE: rw = S_DMEM_rw_r;
            default : rw = 0;
        endcase
    end

    always @(*) begin
        case (sel) // (for scalability, you may assign wdata only with D-MEM's case)
            I_STROBE: wdata = 0; // I-MEM is read-only
            D_STROBE: wdata = S_DMEM_data_r;
            default : wdata = {CLSIZE{1'b0}};
        endcase
    end

    //============================================================================
    //  Register selected strobe's signals in IDLE state (for timing improvement)
    //============================================================================

    //這樣比較好看
    //就是把sel, addr, rw, wdata傳下去reg
    
//    always @(posedge clk_i) begin
//        if (rst_i) begin
//            sel_r <= 0;
//            addr_r <= 0;
//            rw_r <= 0;
//            wdata_r <= 0;
//            same_wt_r <= 0;
//        end
//        else if (c_state == M_IDLE)  begin
//            sel_r <= sel;
//            addr_r <= addr; 
//            rw_r <= rw;
//            wdata_r <= wdata;
//            same_wt_r <= S_DMEM_same_wt_i;
//        end
//    end
     always @(posedge clk_i) begin
         if (rst_i)
             sel_r <= 0;
         else if (c_state == M_IDLE) 
             sel_r <= sel;
     end

     always @(posedge clk_i) begin
         if (rst_i)
             addr_r <= 0;
         else if (c_state == M_IDLE)
             addr_r <= addr; 
     end

     always @(posedge clk_i) begin
         if (rst_i)
             rw_r <= 0;
         else if (c_state == M_IDLE)
             rw_r <= rw;
     end

     always @(posedge clk_i) begin
         if (rst_i)
             wdata_r <= 0;
         else if (c_state == M_IDLE)
             wdata_r <= wdata;
     end

     always @(posedge clk_i) begin
         if (rst_i)
             same_wt_r <= 0;
         else if (c_state == M_IDLE)
             same_wt_r <= S_DMEM_same_wt_i;
     end

    assign have_strobe = S_IMEM_strobe_r | S_DMEM_strobe_r;

    always @(posedge clk_i) begin
        if (rst_i)
            have_strobe_r <= 0;
        else if (c_state == M_IDLE)
            have_strobe_r <= have_strobe;
        else 
            have_strobe_r <= 0;
    end
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
                    n_state = M_WAIT;
                else 
                    n_state = M_IDLE;
            M_WAIT: 
                if(L2_ready_i)
                    n_state = M_IDLE;
                else 
                    n_state = M_WAIT;
        endcase
    end

    
    //=======================================================
    //  Output logic
    //=======================================================

    assign S_IMEM_data_o = L2_data_i;
    assign S_DMEM_data_o = L2_data_i;
    assign S_IMEM_done_o = (sel_r == I_STROBE) ? L2_ready_i : 0;
    assign S_DMEM_done_o = (sel_r == D_STROBE && !S_DMEM_RdfromOther) ? L2_ready_i : 0;

    assign L2_strobe_o  = have_strobe_r;
    assign L2_addr_o    = addr_r;
    assign L2_rw_o      = rw_r;
    assign L2_data_o    = wdata_r;
    assign L2_same_wt_o = same_wt_r;
endmodule