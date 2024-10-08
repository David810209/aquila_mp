`timescale 1ns / 1ps
// =============================================================================
//  Program : soc_tb.v
//  Author  : Chun-Jen Tsai
//  Date    : Feb/24/2020
// -----------------------------------------------------------------------------
//  Description:
//  This is the top-level Aquila testbench.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
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

`define SIM_CLK_RATE 100_000_000

module soc_tb #( parameter XLEN = 32, parameter CLSIZE = `CLP )();

reg  sys_reset = 1;
reg  sys_clock = 0;

wire usr_reset;
wire ui_clk, ui_rst;
wire clk, rst;

// uart
wire                uart_rx = 1; /* When the UART rx line is idle, it carries '1'. */
wire                uart_tx;

// --------- External memory interface -----------------------------------------
localparam CORE_NUMS_BITS = (`CORE_NUMS==1) ? 0 : `CORE_NUMS-1;

// Instruction memory ports
wire                IMEM_strobe[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   IMEM_addr[0 : CORE_NUMS_BITS];
wire                IMEM_done[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] IMEM_data[0 : CORE_NUMS_BITS];

// Data memory ports
wire                DMEM_strobe[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   DMEM_addr[0 : CORE_NUMS_BITS];
wire                DMEM_rw[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] DMEM_wt_data[0 : CORE_NUMS_BITS];
wire                DMEM_done[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] DMEM_rd_data[0 : CORE_NUMS_BITS];

wire                DMEM_same_wt[0 : CORE_NUMS_BITS];

// L2 Cache ports
wire                L1_L2_strobe[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   L1_L2_addr[0 : CORE_NUMS_BITS];
wire                L1_L2_rw[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] L1_L2_wt_data[0 : CORE_NUMS_BITS];
wire                L1_L2_done[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] L1_L2_rd_data[0 : CORE_NUMS_BITS];

wire                L1_L2_same_wt[0 : CORE_NUMS_BITS];
wire                self_flushing[0 : CORE_NUMS_BITS];
wire                other_flushing[0 : CORE_NUMS_BITS];

// --------- Amo unit signals -----------------------------------------
`ifdef ENABLE_ATOMIC_UNIT 
wire                    C2AMO_strobe[0 : CORE_NUMS_BITS];
wire                    C2AMO_rw[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]       C2AMO_addr[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]       C2AMO_wt_data[0 : CORE_NUMS_BITS];
wire                    C2AMO_done[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]       C2AMO_rd_data[0 : CORE_NUMS_BITS];
wire                    C2AMO_is_amo[0 : CORE_NUMS_BITS];
wire [4 : 0]            C2AMO_amo_type[0 : CORE_NUMS_BITS];

wire [1 : 0]            AMO2C_amo_id;
wire                    AMO2C_strobe[0 : CORE_NUMS_BITS];
wire                    AMO2C_rw[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]       AMO2C_addr[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]       AMO2C_wt_data[0 : CORE_NUMS_BITS];
wire                    AMO2C_done[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]       AMO2C_rd_data[0 : CORE_NUMS_BITS];


wire [`CORE_NUMS-1 : 0] AMO_id;
wire                    AMO_strobe;
wire                    AMO_rw;
wire [XLEN-1 : 0]       AMO_addr;
wire [XLEN-1 : 0]       AMO_wt_data;
wire                    AMO_data_done;
wire [XLEN-1 : 0]       AMO_rd_data;
wire                    AMO_is_amo;
wire [4 : 0]            AMO_amo_type;

wire                    AMO_DMEM_strobe;
wire                    AMO_DMEM_rw;
wire [XLEN-1 : 0]       AMO_DMEM_addr;
wire [XLEN-1 : 0]       AMO_DMEM_wt_data;
wire                    AMO_DMEM_done;
wire [XLEN-1 : 0]       AMO_DMEM_rd_data;
`endif

// --------- Cache coherence signals -----------------------------------------
//****** remote ******//
wire                 probe_strobe[0 : CORE_NUMS_BITS];
wire                 probe_rw[0 : CORE_NUMS_BITS]; 
wire [XLEN-1 : 0]    probe_addr[0 : CORE_NUMS_BITS];  
wire [CLSIZE-1 : 0]  probe_data_rd[0 : CORE_NUMS_BITS];
wire [1:0 ]          probe_same_wt[0 : CORE_NUMS_BITS];
wire                 probe_ready[0 : CORE_NUMS_BITS];

wire                 probe_hit[0 : CORE_NUMS_BITS];  
wire                 probe_shared[0 : CORE_NUMS_BITS];
wire                 probe_shared_ready[0 : CORE_NUMS_BITS];

//****** local ******//
wire                 broadcast_strobe[0 : CORE_NUMS_BITS];
wire                 broadcast_rw[0 : CORE_NUMS_BITS];         
wire [XLEN-1 : 0]    broadcast_addr[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0]  broadcast_data_rd[0 : CORE_NUMS_BITS];
wire                 broadcast_ready[0 : CORE_NUMS_BITS];  

wire                 broadcast_wait[0 : CORE_NUMS_BITS];
wire                 broadcast_hit[0 : CORE_NUMS_BITS];
wire                 broadcast_shared[0 : CORE_NUMS_BITS];
wire                 broadcast_shared_ready[0 : CORE_NUMS_BITS];
wire                 broadcast_RdfromOther[0 : CORE_NUMS_BITS];

`ifdef ENABLE_ATOMIC_UNIT
wire                 probe_is_amo[0 : CORE_NUMS_BITS];
wire [4 : 0]         probe_amo_type[0 : CORE_NUMS_BITS];
wire                 broadcast_is_amo[0 : CORE_NUMS_BITS];
`endif
// --------- L2 cache to Memory-----------------------------------------
wire                L2_MEM_strobe[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   L2_MEM_addr[0 : CORE_NUMS_BITS];
wire                L2_MEM_rw[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] L2_MEM_wt_data[0 : CORE_NUMS_BITS];
wire                L2_MEM_done[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] L2_MEM_rd_data[0 : CORE_NUMS_BITS];

// --------- I/O device interface ----------------------------------------------
//  Device bus signals for core 0 and core 1 
wire                dev_strobe[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   dev_addr[0 : CORE_NUMS_BITS];
wire                dev_we[0 : CORE_NUMS_BITS];
wire [XLEN/8-1 : 0] dev_be[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   dev_din[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   dev_dout[0 : CORE_NUMS_BITS];
wire                dev_ready[0 : CORE_NUMS_BITS];

// Selected device bus signals
wire                M_dev_strobe;
wire [XLEN-1 : 0]   M_dev_addr;
wire                M_dev_we;
wire [XLEN/8-1 : 0] M_dev_be;
wire [XLEN-1 : 0]   M_dev_din;
wire [XLEN-1 : 0]   M_dev_dout;
wire                M_dev_ready;

// --------- cdc_sync ----------------------------------------------------------
// Core 0 Memory Ports
wire                P0_MEM_strobe_ui_clk;
wire [XLEN-1 : 0]   P0_MEM_addr_ui_clk;
wire                P0_MEM_rw_ui_clk;
wire [CLSIZE-1 : 0] P0_MEM_wt_data_ui_clk;
wire                P0_MEM_done_ui_clk;
wire [CLSIZE-1 : 0] P0_MEM_rd_data_ui_clk;

// Core 1 Memory Ports
wire                P1_MEM_strobe_ui_clk;
wire [XLEN-1 : 0]   P1_MEM_addr_ui_clk;
wire                P1_MEM_rw_ui_clk;
wire [CLSIZE-1 : 0] P1_MEM_wt_data_ui_clk;
wire                P1_MEM_done_ui_clk;
wire [CLSIZE-1 : 0] P1_MEM_rd_data_ui_clk;

// --------- Memory Controller Interface ---------------------------------------
// Xilinx MIG memory controller user-logic interface signals
wire [27:0]         MEM_addr;
wire [2:0]          MEM_cmd;
wire                MEM_en;
wire [`WDFP-1:0]    MEM_wdf_data;
wire                MEM_wdf_end;
wire [`WDFP/8-1:0]  MEM_wdf_mask = {(`WDFP/8){1'b0}};
wire                MEM_wdf_wren;
wire [`WDFP-1:0]    MEM_rd_data;
wire                MEM_rd_data_end;
wire                MEM_rd_data_valid;
wire                MEM_rdy;
wire                MEM_wdf_rdy;
wire                MEM_sr_req;
wire                MEM_ref_req;
wire                MEM_zq_req;

// Uart
wire                uart_sel;
wire [XLEN-1 : 0]   uart_dout;
wire                uart_ready;

// External reset signal
assign usr_reset = sys_reset;

// --------- System Clock Generator --------------------------------------------
assign clk = sys_clock;

always
  #((1_000_000_000/`SIM_CLK_RATE)/2) sys_clock <= ~sys_clock; // 100 MHz

// -----------------------------------------------------------------------------
// For the Aquila Core, the reset (rst) will lasts for 5 cycles to clear
//   all the pipeline registers.
//
localparam RST_CYCLES=5;
reg [RST_CYCLES-1 : 0] rst_count = {RST_CYCLES{1'b1}};
assign rst = rst_count[RST_CYCLES-1];

always @(posedge clk)
begin
    if (usr_reset)
        rst_count <= {RST_CYCLES{1'b1}};
    else
        rst_count <= {rst_count[RST_CYCLES-2 : 0], 1'b0};
end

// Simulate a clock-domain for DRAM
assign ui_clk = sys_clock;
assign ui_rst = rst_count[RST_CYCLES-1];

// -----------------------------------------------------------------------------
//  Aquila processor core.
//

assign other_flushing[0] = self_flushing[1];
assign other_flushing[1] = self_flushing[0];

genvar i;
generate
    for (i = 0; i < `CORE_NUMS; i = i + 1) begin: cores
        aquila_top #(.HART_ID(i), .XLEN(XLEN), .CLSIZE(CLSIZE)) 
        Aquila_SoC
        (
            .clk_i(clk),
            .rst_i(rst),          // level-sensitive reset signal.
            .base_addr_i(32'b0),  // initial program counter.

            // External instruction memory ports.
            .M_IMEM_strobe_o(IMEM_strobe[i]),
            .M_IMEM_addr_o(IMEM_addr[i]),
            .M_IMEM_done_i(IMEM_done[i]),
            .M_IMEM_data_i(IMEM_data[i]),

            .Other_flushing_i(other_flushing[i]),

            // External data memory ports.
            .M_DMEM_strobe_o(DMEM_strobe[i]),
            .M_DMEM_addr_o(DMEM_addr[i]),
            .M_DMEM_rw_o(DMEM_rw[i]),
            .M_DMEM_data_o(DMEM_wt_data[i]),
            .M_DMEM_done_i(DMEM_done[i]),
            .M_DMEM_data_i(DMEM_rd_data[i]),

            .M_DMEM_same_wt_o(DMEM_same_wt[i]),
            .D_flushing_o(self_flushing[i]),

            // I/O device ports.
            .M_DEVICE_strobe_o(dev_strobe[i]),
            .M_DEVICE_addr_o(dev_addr[i]),
            .M_DEVICE_rw_o(dev_we[i]),
            .M_DEVICE_byte_enable_o(dev_be[i]),
            .M_DEVICE_data_o(dev_din[i]),
            .M_DEVICE_data_ready_i(dev_ready[i]),
            .M_DEVICE_data_i(dev_dout[i]),

            // Atomic instructions ports 
`ifdef ENABLE_ATOMIC_UNIT
            .C2AMO_strobe_o(C2AMO_strobe[i]),
            .C2AMO_rw_o(C2AMO_rw[i]),
            .C2AMO_addr_o(C2AMO_addr[i]),
            .C2AMO_data_o(C2AMO_wt_data[i]),
            .C2AMO_data_ready_i(C2AMO_done[i]),
            .C2AMO_data_i(C2AMO_rd_data[i]),
            .C2AMO_is_amo_o(C2AMO_is_amo[i]),
            .C2AMO_amo_type_o(C2AMO_amo_type[i]),

            .AMO2C_amo_id_i(AMO2C_amo_id),
            .AMO2C_strobe_i(AMO2C_strobe[i]),
            .AMO2C_rw_i(AMO2C_rw[i]),
            .AMO2C_addr_i(AMO2C_addr[i]),
            .AMO2C_data_i(AMO2C_wt_data[i]),
            .AMO2C_data_ready_o(AMO2C_done[i]),
            .AMO2C_data_o(AMO2C_rd_data[i]),
`endif
            // Cache coherence ports 
            .probe_strobe_i(probe_strobe[i]),
            .probe_rw_i(probe_rw[i]),        
            .probe_addr_i(probe_addr[i]),   
            .probe_data_rd_i(probe_data_rd[i]),
            .probe_same_wt_i(probe_same_wt[i]),
            .probe_ready_i(probe_ready[i]),  
`ifdef ENABLE_ATOMIC_UNIT
            .probe_is_amo_i(probe_is_amo[i]),   
`endif
            .probe_hit_i(probe_hit[i]),   
            .probe_shared_i(probe_shared[i]),
            .probe_shared_ready_i(probe_shared_ready[i]),

            .broadcast_strobe_o(broadcast_strobe[i]),
            .broadcast_rw_o(broadcast_rw[i]),         
            .broadcast_addr_o(broadcast_addr[i]), 
            .broadcast_ready_o(broadcast_ready[i]),   
            .broadcast_data_rd_o(broadcast_data_rd[i]),
`ifdef ENABLE_ATOMIC_UNIT
            .broadcast_is_amo_o(broadcast_is_amo[i]),   
`endif
            .broadcast_RdfromOther_o(broadcast_RdfromOther[i]),
            .broadcast_wait_o(broadcast_wait[i]),
            .broadcast_hit_o(broadcast_hit[i]),
            .broadcast_shared_o(broadcast_shared[i]),
            .broadcast_shared_ready_o(broadcast_shared_ready[i])          
        );
    end
endgenerate

// -----------------------------------------------------------------------------
//  Atomic unit arbiter.
//
`ifdef ENABLE_ATOMIC_UNIT      
amo_arbiter #(.N(`CORE_NUMS), .XLEN(XLEN), .CLSIZE(CLSIZE))
Amo_arbiter
(   //===================== System signals =====================//
    .clk_i(clk),
    .rst_i(rst),

    // Aquila core 0 device interface
    .P0_strobe_i(C2AMO_strobe[0]),
    .P0_addr_i(C2AMO_addr[0]),
    .P0_rw_i(C2AMO_rw[0]),
    .P0_data_i(C2AMO_wt_data[0]),
    .P0_data_ready_o(C2AMO_done[0]),
    .P0_data_o(C2AMO_rd_data[0]),
    .P0_is_amo_i(C2AMO_is_amo[0]),
    .P0_amo_type_i(C2AMO_amo_type[0]),

    // Aquila core 1 device interface
    .P1_strobe_i(C2AMO_strobe[1]),
    .P1_addr_i(C2AMO_addr[1]),
    .P1_rw_i(C2AMO_rw[1]),
    .P1_data_i(C2AMO_wt_data[1]),
    .P1_data_ready_o(C2AMO_done[1]),
    .P1_data_o(C2AMO_rd_data[1]),
    .P1_is_amo_i(C2AMO_is_amo[1]),
    .P1_amo_type_i(C2AMO_amo_type[1]),

    // Aquila device slave interface
    .AMO_id_o(AMO_id),
    .AMO_strobe_o(AMO_strobe),
    .AMO_addr_o(AMO_addr),
    .AMO_rw_o(AMO_rw),
    .AMO_data_o(AMO_wt_data),
    .AMO_data_ready_i(AMO_data_done),
    .AMO_data_i(AMO_rd_data),
    .AMO_is_amo_o(AMO_is_amo),
    .AMO_amo_type_o(AMO_amo_type)
);

// ----------------------------------------------------------------------------
//  The Atomic Unit (Overseer of RISCV atomic instructions).
//
// processor to atomic unit

atomic_unit #(.N(`CORE_NUMS), .XLEN(XLEN), .CLSIZE(CLSIZE))
ATOM_U(
    .clk_i(clk),
    .rst_i(rst),

    .core_id_i(AMO_id), // number of RISCV cores (# of core_top modules)
    .core_strobe_i(AMO_strobe),
    .core_rw_i(AMO_rw),
    .core_addr_i(AMO_addr),
    .core_data_i(AMO_wt_data),
    .core_done_o(AMO_data_done),
    .core_data_o(AMO_rd_data),

    .core_is_amo_i(AMO_is_amo),
    .core_amo_type_i(AMO_amo_type),

    .M_DMEM_strobe_o(AMO_DMEM_strobe),
    .M_DMEM_rw_o(AMO_DMEM_rw),
    .M_DMEM_addr_o(AMO_DMEM_addr),
    .M_DMEM_data_o(AMO_DMEM_wt_data),
    .M_DMEM_done_i(AMO_DMEM_done),
    .M_DMEM_data_i(AMO_DMEM_rd_data)
);

assign AMO2C_amo_id      = AMO_id;//;(AMO_strobe) ? AMO_id : 'b0;

assign AMO2C_strobe[0]   = (AMO_id == 'b01) ? AMO_DMEM_strobe : 'b0;
assign AMO2C_rw[0]       = (AMO_id == 'b01) ? AMO_DMEM_rw : 'b0;
assign AMO2C_addr[0]     = (AMO_id == 'b01) ? AMO_DMEM_addr : 'b0;
assign AMO2C_wt_data[0]  = (AMO_id == 'b01) ? AMO_DMEM_wt_data : 'b0;

assign AMO2C_strobe[1]   = (AMO_id == 'b10) ? AMO_DMEM_strobe : 'b0;
assign AMO2C_rw[1]       = (AMO_id == 'b10) ? AMO_DMEM_rw : 'b0;
assign AMO2C_addr[1]     = (AMO_id == 'b10) ? AMO_DMEM_addr : 'b0;
assign AMO2C_wt_data[1]  = (AMO_id == 'b10) ? AMO_DMEM_wt_data : 'b0;

assign AMO_DMEM_done     = (AMO_id == 'b01) ? AMO2C_done[0] : AMO2C_done[1];
assign AMO_DMEM_rd_data  = (AMO_id == 'b01) ? AMO2C_rd_data[0] : AMO2C_rd_data[1];
`endif

// -----------------------------------------------------------------------------
//  L1 Cache Coherence.
//

coherence_unit #(.XLEN(XLEN), .CLSIZE(CLSIZE)) 
Coherence_unit 
(   //===================== System signals =====================//
    .clk_i(clk),
    .rst_i(rst),

    //==================== L1 cache signals ====================//
`ifdef ENABLE_ATOMIC_UNIT
    .AMO_core_id(AMO2C_amo_id),
    
    .P0_broadcast_is_amo_i(broadcast_is_amo[0]),
    .P1_broadcast_is_amo_i(broadcast_is_amo[1]),

    .P0_probe_is_amo_o(probe_is_amo[0]),
    .P1_probe_is_amo_o(probe_is_amo[1]),
`endif
    .P0_broadcast_strobe_i(broadcast_strobe[0]),
    .P0_broadcast_rw_i(broadcast_rw[0]),    
    .P0_broadcast_addr_i(broadcast_addr[0]),
    .P0_broadcast_data_rd_i(broadcast_data_rd[0]),
    .P0_broadcast_ready_i(broadcast_ready[0]),  
    .P0_broadcast_hit_i(broadcast_hit[0]),      
    .P0_broadcast_shared_i(broadcast_shared[0]),
    .P0_broadcast_shared_ready_i(broadcast_shared_ready[0]),

    .P1_broadcast_strobe_i(broadcast_strobe[1]),
    .P1_broadcast_rw_i(broadcast_rw[1]),    
    .P1_broadcast_addr_i(broadcast_addr[1]), 
    .P1_broadcast_data_rd_i(broadcast_data_rd[1]),
    .P1_broadcast_ready_i(broadcast_ready[1]),   
    .P1_broadcast_hit_i(broadcast_hit[1]),      
    .P1_broadcast_shared_i(broadcast_shared[1]),
    .P1_broadcast_shared_ready_i(broadcast_shared_ready[1]),

    .P0_probe_strobe_o(probe_strobe[0]),
    .P0_probe_rw_o(probe_rw[0]),      
    .P0_probe_addr_o(probe_addr[0]),    
    .P0_probe_data_rd_o(probe_data_rd[0]), 
    .P0_probe_same_wt_o(probe_same_wt[0]),
    .P0_probe_ready_o(probe_ready[0]),    
    .P0_probe_hit_o(probe_hit[0]),    
    .P0_probe_shared_o(probe_shared[0]),
    .P0_probe_shared_ready_o(probe_shared_ready[0]),

    .P1_probe_strobe_o(probe_strobe[1]),
    .P1_probe_rw_o(probe_rw[1]),      
    .P1_probe_addr_o(probe_addr[1]),      
    .P1_probe_data_rd_o(probe_data_rd[1]),
    .P1_probe_same_wt_o(probe_same_wt[1]),
    .P1_probe_ready_o(probe_ready[1]),  
    .P1_probe_hit_o(probe_hit[1]),
    .P1_probe_shared_o(probe_shared[1]),
    .P1_probe_shared_ready_o(probe_shared_ready[1])
);
// -----------------------------------------------------------------------------
//  L2 Cache .
//
generate
    for (i = 0; i < `CORE_NUMS; i = i + 1)
    begin
        L2cache_arbiter #(.XLEN(XLEN), .CLSIZE(CLSIZE)) 
        L2cache_Arbiter
        (
            .clk_i(clk),
            .rst_i(rst),

            //I-Cache
            .S_IMEM_strobe_i(IMEM_strobe[i]),
            .S_IMEM_addr_i(IMEM_addr[i]),
            .S_IMEM_done_o(IMEM_done[i]),
            .S_IMEM_data_o(IMEM_data[i]),

            //D-Cache
            .S_DMEM_strobe_i(DMEM_strobe[i]),
            .S_DMEM_addr_i(DMEM_addr[i]),
            .S_DMEM_rw_i(DMEM_rw[i]),
            .S_DMEM_data_i(DMEM_wt_data[i]),
            .S_DMEM_done_o(DMEM_done[i]),
            .S_DMEM_data_o(DMEM_rd_data[i]),
            .S_DMEM_same_wt_i(DMEM_same_wt[i]),
            .S_DMEM_RdfromOther_i(broadcast_RdfromOther[i]),

            //L2-Cache
            .L2_strobe_o(L1_L2_strobe[i]),    
            .L2_addr_o(L1_L2_addr[i]),      
            .L2_rw_o(L1_L2_rw[i]),        
            .L2_data_o(L1_L2_wt_data[i]),      
            .L2_data_i(L1_L2_rd_data[i]),      
            .L2_ready_i(L1_L2_done[i]),
            .L2_same_wt_o(L1_L2_same_wt[i])
        );
    end
endgenerate

L2cache #(.XLEN(XLEN), .CACHE_SIZE(`L2CACHE_SIZE), .CLSIZE(CLSIZE))
L2_Cache(
    
    .clk_i(clk),
    .rst_i(rst), 

    // From L1 cache 
    .P0_L1_strobe_i(L1_L2_strobe[0]),  
    .P0_L1_addr_i(L1_L2_addr[0]),    
    .P0_L1_rw_i(L1_L2_rw[0]),      
    .P0_L1_data_o(L1_L2_rd_data[0]),    
    .P0_L1_data_i(L1_L2_wt_data[0]),    
    .P0_L1_ready_o(L1_L2_done[0]),  
    .P0_L1_same_wt_i(L1_L2_same_wt[0]),   

    .P1_L1_strobe_i(L1_L2_strobe[1]),  
    .P1_L1_addr_i(L1_L2_addr[1]),    
    .P1_L1_rw_i(L1_L2_rw[1]),      
    .P1_L1_data_o(L1_L2_rd_data[1]),    
    .P1_L1_data_i(L1_L2_wt_data[1]),    
    .P1_L1_ready_o(L1_L2_done[1]),   
    .P1_L1_same_wt_i(L1_L2_same_wt[1]),   

    // To memory
    .P0_m_strobe_o(L2_MEM_strobe[0]),   
    .P0_m_addr_o(L2_MEM_addr[0]),     
    .P0_m_rw_o(L2_MEM_rw[0]),       
    .P0_m_data_i(L2_MEM_rd_data[0]),     
    .P0_m_data_o(L2_MEM_wt_data[0]),     
    .P0_m_ready_i(L2_MEM_done[0]),    

    .P1_m_strobe_o(L2_MEM_strobe[1]),   
    .P1_m_addr_o(L2_MEM_addr[1]),     
    .P1_m_rw_o(L2_MEM_rw[1]),       
    .P1_m_data_i(L2_MEM_rd_data[1]),     
    .P1_m_data_o(L2_MEM_wt_data[1]),     
    .P1_m_ready_i(L2_MEM_done[1])      
);

// -----------------------------------------------------------------------------
//  Device Arbiter.
device_arbiter #(.XLEN(XLEN))
Device_arbiter(
    .clk_i(clk),
    .rst_i(rst), 

    .P0_DEVICE_strobe_i(dev_strobe[0]),
    .P0_DEVICE_addr_i(dev_addr[0]),
    .P0_DEVICE_rw_i(dev_we[0]),
    .P0_DEVICE_byte_enable_i(dev_be[0]),
    .P0_DEVICE_data_i(dev_din[0]),
    .P0_DEVICE_data_ready_o(dev_ready[0]),
    .P0_DEVICE_data_o(dev_dout[0]),

    .P1_DEVICE_strobe_i(dev_strobe[1]),
    .P1_DEVICE_addr_i(dev_addr[1]),
    .P1_DEVICE_rw_i(dev_we[1]),
    .P1_DEVICE_byte_enable_i(dev_be[1]),
    .P1_DEVICE_data_i(dev_din[1]),
    .P1_DEVICE_data_ready_o(dev_ready[1]),
    .P1_DEVICE_data_o(dev_dout[1]),

    .DEVICE_strobe_o(M_dev_strobe),
    .DEVICE_addr_o(M_dev_addr),
    .DEVICE_rw_o(M_dev_we),
    .DEVICE_byte_enable_o(M_dev_be),
    .DEVICE_data_o(M_dev_din),
    .DEVICE_data_ready_i(M_dev_ready),
    .DEVICE_data_i(M_dev_dout)
);

// -----------------------------------------------------------------------------
//  Device address decoder.
//
//       [0] 0xC000_0000 - 0xC0FF_FFFF : UART device
//       [1] 0xC200_0000 - 0xC2FF_FFFF : DCA device
assign uart_sel  = (M_dev_addr[XLEN-1:XLEN-8] == 8'hC0);
assign M_dev_dout  = (uart_sel)? uart_dout : {XLEN{1'b0}};
assign M_dev_ready = (uart_sel)? uart_ready : {XLEN{1'b0}};

// ----------------------------------------------------------------------------
//  UART Controller with a simple memory-mapped I/O interface.
//
`define BAUD_RATE	115200

wire simulation_finished;
uart #(.BAUD(`SIM_CLK_RATE/`BAUD_RATE))
UART(
    .clk(clk),
    .rst(rst),

    .EN(M_dev_strobe & uart_sel),
    .ADDR(M_dev_addr[3:2]),
    .WR(M_dev_we),
    .BE(M_dev_be),
    .DATAI(M_dev_din),
    .DATAO(uart_dout),
    .READY(uart_ready),

    .RXD(uart_rx),
    .TXD(uart_tx),

    .simulation_done(simulation_finished)
);


// ----------------------------------------------------------------------------
//  Print simulation termination message.
//
always @(posedge clk)
begin
    if (simulation_finished) begin
        $display();
        $display("Simulation finished.");
        $finish();
    end
end

`ifdef ENABLE_CACHE

// ----------------------------------------------------------------------------
//  In the real system, the memory controller 'MIG' operates across two clock
//  domains, namely, 'clk' and 'ui_clk'.  For simulation, we do not have two
//  clock domains. However, we still use two clock names (of the same system
//  clcok) such that we may actually simulate two clock domains in the future.
//

// Processor1 Memory Control Signals.
assign P0_MEM_strobe_ui_clk  = L2_MEM_strobe[0];
assign P0_MEM_addr_ui_clk    = L2_MEM_addr[0];
assign P0_MEM_rw_ui_clk      = L2_MEM_rw[0];
assign P0_MEM_wt_data_ui_clk = L2_MEM_wt_data[0];
assign L2_MEM_done[0]        = P0_MEM_done_ui_clk;
assign L2_MEM_rd_data[0]     = P0_MEM_rd_data_ui_clk;

// Processor2 Memory Control Signals.
assign P1_MEM_strobe_ui_clk  = L2_MEM_strobe[1];
assign P1_MEM_addr_ui_clk    = L2_MEM_addr[1];
assign P1_MEM_rw_ui_clk      = L2_MEM_rw[1];
assign P1_MEM_wt_data_ui_clk = L2_MEM_wt_data[1];
assign L2_MEM_done[1]        = P1_MEM_done_ui_clk;
assign L2_MEM_rd_data[1]     = P1_MEM_rd_data_ui_clk;

// ----------------------------------------------------------------------------
//  mem_arbiter.
//
mem_arbiter Memory_Arbiter
(
    // System signals
    .clk_i(ui_clk),
    .rst_i(rst),

    // Aquila M_P0_CACHE master port interface signals
    .P0_MEM_strobe_i(P0_MEM_strobe_ui_clk),
    .P0_MEM_addr_i(P0_MEM_addr_ui_clk),
    .P0_MEM_rw_i(P0_MEM_rw_ui_clk),
    .P0_MEM_data_i(P0_MEM_wt_data_ui_clk),
    .P0_MEM_done_o(P0_MEM_done_ui_clk),
    .P0_MEM_data_o(P0_MEM_rd_data_ui_clk),

    // Aquila M_P1_DCACHE master port interface signals
    .P1_MEM_strobe_i(P1_MEM_strobe_ui_clk),
    .P1_MEM_addr_i(P1_MEM_addr_ui_clk),
    .P1_MEM_rw_i(P1_MEM_rw_ui_clk),
    .P1_MEM_data_i(P1_MEM_wt_data_ui_clk),
    .P1_MEM_done_o(P1_MEM_done_ui_clk),
    .P1_MEM_data_o(P1_MEM_rd_data_ui_clk),
    
    // memory user interface signals
    .M_MEM_addr_o(MEM_addr),
    .M_MEM_cmd_o(MEM_cmd),
    .M_MEM_en_o(MEM_en),
    .M_MEM_wdf_data_o(MEM_wdf_data),
    .M_MEM_wdf_end_o(MEM_wdf_end),
    .M_MEM_wdf_mask_o(MEM_wdf_mask),
    .M_MEM_wdf_wren_o(MEM_wdf_wren),
    .M_MEM_rd_data_i(MEM_rd_data),
    .M_MEM_rd_data_valid_i(MEM_rd_data_valid),
    .M_MEM_rdy_i(MEM_rdy),
    .M_MEM_wdf_rdy_i(MEM_wdf_rdy),
    .M_MEM_sr_req_o(MEM_sr_req),
    .M_MEM_ref_req_o(MEM_ref_req),
    .M_MEM_zq_req_o(MEM_zq_req)
);

// ----------------------------------------------------------------------------
//  A simple MIG simulation model.
//
//  Simple DRAM memory controller simulation.
//  0x8000_0000 ~ 0x8010_0000
localparam DRAM_NLINES = 32*(1024*1024*8*4)/`WDFP; // 1 MB DRAM
localparam DRAM_ADDR_WIDTH = $clog2(DRAM_NLINES);

mig_7series_sim #(.DATA_WIDTH(`WDFP), .N_ENTRIES(DRAM_NLINES))
MIG(
    .clk_i(clk),
    .rst_i(rst),

    // Application interface ports
    .app_addr(MEM_addr),                    // input [27:0]        app_addr
    .app_cmd(MEM_cmd),                      // input [2:0]         app_cmd
    .app_en(MEM_en),                        // input               app_en
    .app_wdf_data(MEM_wdf_data),            // input [`WDFP-1:0]   app_wdf_data
    .app_wdf_end(MEM_wdf_end),              // input               app_wdf_end
    .app_wdf_mask(MEM_wdf_mask),            // input [`WDFP/8-1:0] app_wdf_mask
    .app_wdf_wren(MEM_wdf_wren),            // input               app_wdf_wren
    .app_rd_data(MEM_rd_data),              // output [`WDFP-1:0]  app_rd_data
    .app_rd_data_end(MEM_rd_data_end),      // output              app_rd_data_end
    .app_rd_data_valid(MEM_rd_data_valid),  // output              app_rd_data_valid
    .app_rdy(MEM_rdy),                      // output              app_rdy
    .app_wdf_rdy(MEM_wdf_rdy),              // output              app_wdf_rdy
    .app_sr_req(MEM_sr_req),                // input               app_sr_req
    .app_ref_req(MEM_ref_req),              // input               app_ref_req
    .app_zq_req(MEM_zq_req),                // input               app_zq_req
    .app_sr_active(MEM_sr_active),          // output              app_sr_active
    .app_ref_ack(MEM_ref_ack),              // output              app_ref_ack
    .app_zq_ack(MEM_zq_ack)                 // output              app_zq_ack
);

`endif  // ENABLE_CACHE

// ----------------------------------------------------------------------------
//  Reset logic simulation.
//
reg reset_trigger;

initial begin
  forever begin
    @ (posedge reset_trigger);
    sys_reset = 1;
    @ (posedge clk);
    @ (posedge clk);
    sys_reset = 0;
  end
end

initial
begin: TEST_CASE
  #10 reset_trigger = 1;
  @(negedge sys_reset)
  reset_trigger = 0;
end


endmodule
