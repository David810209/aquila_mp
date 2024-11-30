`timescale 1ns / 1ps
// =============================================================================
//  Program : soc_top.v
//  Author  : Chun-Jen Tsai
//  Date    : Feb/16/2020
// -----------------------------------------------------------------------------
//  Description:
//  This is the top-level Aquila IP wrapper for an AXI-based processor SoC.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  This module is based on the soc_top.v module written by Jin-you Wu
//  on Feb/28/2019. The original module was a stand-alone top-level module
//  for an SoC. This rework makes it a module embedded inside an AXI IP.
//
//  Jan/12/2020, by Chun-Jen Tsai:
//    Added a on-chip Tightly-Coupled Memory (TCM) to the aquila SoC.
//
//  Sep/12/2022, by Chun-Jen Tsai:
//    Fix an issue of missing reset signal across clock domains.
//    Use the clock wizard to generate the Aquila clock on Arty.
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

module soc_top #( parameter XLEN = 32, parameter CLSIZE = `CLP )
(
`ifdef ARTY
    input                 clk_i,
    input                 resetn_i,
`else // KC705
    input                 sys_clk_p,
    input                 sys_clk_n,
    input                 reset_i,
`endif

    // ddr3
    output [13 : 0]       ddr3_addr,
    output [2 : 0]        ddr3_ba,
    output                ddr3_cas_n,
    output [0 : 0]        ddr3_ck_n,
    output [0 : 0]        ddr3_ck_p,
    output [0 : 0]        ddr3_cke,
    output                ddr3_ras_n,
    output                ddr3_reset_n,
    output                ddr3_we_n,
    inout  [`DRAMP-1 : 0] ddr3_dq,
    inout  [`DQSP-1 : 0]  ddr3_dqs_n,
    inout  [`DQSP-1 : 0]  ddr3_dqs_p,
    output [0 : 0]        ddr3_cs_n,
    output [`DQSP-1 : 0]  ddr3_dm,
    output [0 : 0]        ddr3_odt,

    // sdcard
    output                spi_mosi,
    input                 spi_miso,
    output                spi_sck,
    output [0:0]          spi_ss,

    // uart
    input                 uart_rx,
    output                uart_tx,

    // buttons & leds
    input  [0 : `USRP-1]  usr_btn,
    output [0 : `USRP-1]  usr_led
);

`ifdef ARTY
wire clk_166M, clk_200M;
`endif

wire usr_reset;
wire ui_clk, ui_rst;
wire clk, rst;

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
wire                 re_gen_;
//****** remote ******//
wire                 probe_strobe[0 : CORE_NUMS_BITS];
wire                 probe_rw[0 : CORE_NUMS_BITS]; 
wire [XLEN-1 : 0]    probe_addr[0 : CORE_NUMS_BITS];  
wire [CLSIZE-1 : 0]  probe_data_rd[0 : CORE_NUMS_BITS];
wire                 probe_same_wt[0 : CORE_NUMS_BITS];
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
(* mark_debug = "true" *) wire                L2_MEM_rw[0 : CORE_NUMS_BITS];
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
wire                MEM_strobe_ui_clk[0 : CORE_NUMS_BITS];
wire [XLEN-1 : 0]   MEM_addr_ui_clk[0 : CORE_NUMS_BITS];
wire                MEM_rw_ui_clk[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] MEM_wt_data_ui_clk[0 : CORE_NUMS_BITS];
wire                MEM_done_ui_clk[0 : CORE_NUMS_BITS];
wire [CLSIZE-1 : 0] MEM_rd_data_ui_clk[0 : CORE_NUMS_BITS];

// --------- Memory Controller Interface ---------------------------------------
// Xilinx MIG memory controller user-logic interface signals
wire [27:0]         MEM_addr;
wire [2:0]          MEM_cmd;
wire                MEM_en;
wire [`WDFP-1:0]    MEM_wdf_data;
wire                MEM_wdf_end;
wire [`WDFP/8-1:0]  MEM_wdf_mask;
wire                MEM_wdf_wren;
wire [`WDFP-1:0]    MEM_rd_data;
wire                MEM_rd_data_end;
wire                MEM_rd_data_valid;
wire                MEM_rdy;
wire                MEM_wdf_rdy;
wire                MEM_sr_req;
wire                MEM_ref_req;
wire                MEM_zq_req;
wire                MEM_sr_active;
wire                MEM_ref_ack;
wire                MEM_zq_ack;
wire                MEM_calib;

// SPI for SD Card
wire                spi_sel;
wire [XLEN-1 : 0]   spi_dout;
wire                spi_ready;

// Uart
wire                uart_sel;
wire [XLEN-1 : 0]   uart_dout;
wire                uart_ready;

// --------- System Clock Generator --------------------------------------------
`ifdef ARTY
assign usr_reset = ~resetn_i;

clk_wiz_0 Clock_Generator(
    .clk_in1(clk_i),  // System input clock
    .clk_out1(clk),      // System clock for the Aquila SoC
    .clk_out2(clk_166M), // Clock input to the MIG Memory controller
    .clk_out3(clk_200M)  // DRAM Reference clock for MIG
);
`else // KC705
assign usr_reset = reset_i;

clk_wiz_0 Clock_Generator(
    .clk_in1(ui_clk),  // Clock input from the MIG Memory controller
    .clk_out1(clk)     // System clock for the Aquila SoC
);
`endif

// -----------------------------------------------------------------------------
// Synchronize the system reset signal (usr_reset) across the clock domains
//   to the Aquila SoC domains (rst).
//
// For the Aquila Core, the reset (rst) should lasts for at least 5 cycles
//   to initialize all the pipeline registers.
//
localparam SR_N = 8;
reg [SR_N-1:0] sync_reset = {SR_N{1'b1}};
assign rst = sync_reset[SR_N-1];

always @(posedge clk) begin
    if (usr_reset)
        sync_reset <= {SR_N{1'b1}};
    else
        sync_reset <= {sync_reset[SR_N-2 : 0], 1'b0};
end

// -----------------------------------------------------------------------------
//  Aquila processor core.
//


assign other_flushing[0] = self_flushing[1];
assign other_flushing[1] = self_flushing[0];

genvar i;
generate
    for (i = 0; i < `CORE_NUMS; i = i + 1)
    begin
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
//       [1] 0xC200_0000 - 0xC2FF_FFFF : SPI device
assign uart_sel  = (M_dev_addr[XLEN-1:XLEN-8] == 8'hC0);
assign spi_sel   = (M_dev_addr[XLEN-1:XLEN-8] == 8'hC2);
assign M_dev_dout  = (uart_sel)? uart_dout : (spi_sel)? spi_dout : {XLEN{1'b0}};
assign M_dev_ready = (uart_sel)? uart_ready : (spi_sel)? spi_ready : {XLEN{1'b0}};

// ----------------------------------------------------------------------------
//  UART Controller with a simple memory-mapped I/O interface.
//
`define BAUD_RATE	115200

uart #(.BAUD(`SOC_CLK/`BAUD_RATE))
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
    .TXD(uart_tx)
);

// -----------------------------------------------------------------------------
//  SD Card SPI Controller with AXI bus interface.
//
wire                axi_arvalid, axi_awvalid;
wire [6 : 0]        axi_awaddr, axi_araddr;
wire                axi_arready, axi_awready;
wire [XLEN/8-1 : 0] axi_wstrb;
wire                axi_wready;
wire                axi_rready;
wire                axi_wvalid;
wire                axi_rvalid;
wire [1 : 0]        axi_bresp, axi_rresp;
wire                axi_bvalid;
wire                axi_bready;
wire [XLEN-1 : 0]   axi_rdata;
wire [XLEN-1 : 0]   axi_wdata;

// The following signals are unused output signals from the Xilinx AXI SPI IP:
wire              io0_t_dummy, io1_t_dummy, sck_t_dummy, ss_t_dummy;
wire              io1_o_dummy, irpt_dummy;

// ---------------------------------------
//  Aquila local bus to AXI bus interface
// ---------------------------------------
core2axi_if #(.XLEN(32), .AXI_ADDR_LEN(7))
Core2AXI_0 (
    .clk_i(clk),
    .rst_i(rst),

    // Aquila M_DEVICE master interface signals.
    .S_DEVICE_strobe_i(M_dev_strobe),
    .S_DEVICE_addr_i(M_dev_addr),
    .S_DEVICE_rw_i(M_dev_we),
    .S_DEVICE_byte_enable_i(M_dev_be),
    .S_DEVICE_data_i(M_dev_din),
    .S_DEVICE_data_ready_o(spi_ready),
    .S_DEVICE_data_o(spi_dout),

    // Converted AXI master interface signals.
    .m_axi_awaddr(axi_awaddr),   // Master write address signals.
    .m_axi_awvalid(axi_awvalid), // Master write addr/ctrl is valid.
    .m_axi_awready(axi_awready), // Slave ready to receive write command.
    .m_axi_wdata(axi_wdata),     // Master write data signals.
    .m_axi_wstrb(axi_wstrb),     // Master byte select signals.
    .m_axi_wvalid(axi_wvalid),   // Master write data is valid.
    .m_axi_wready(axi_wready),   // Slave ready to receive write data.
    .m_axi_bresp(axi_bresp),     // Slave write-op response signal.
    .m_axi_bvalid(axi_bvalid),   // Slave write-op response is valid.
    .m_axi_bready(axi_bready),   // Master ready to receive write response.
    .m_axi_araddr(axi_araddr),   // Master read address signals.
    .m_axi_arvalid(axi_arvalid), // Master read addr/ctrl is valid.
    .m_axi_arready(axi_arready), // Slave is ready to receive read command.
    .m_axi_rdata(axi_rdata),     // Slave read data signals.
    .m_axi_rresp(axi_rresp),     // Slave read-op response signal
    .m_axi_rvalid(axi_rvalid),   // Slave read response is valid.
    .m_axi_rready(axi_rready)    // Master ready to receive read response.
);

// ----------------------------------
//  SPI controller
// ----------------------------------
axi_quad_spi_0 SD_Card_Controller(

    // Interface ports to the Aquila SoC.
    .s_axi_aclk(clk),
    .s_axi_aresetn(~rst),
    .s_axi_awaddr(axi_awaddr),
    .s_axi_awvalid(axi_awvalid),        // master signals write addr/ctrl valid.
    .s_axi_awready(axi_awready),        // slave ready to fetch write address.
    .s_axi_wdata(axi_wdata),            // write data to the slave.
    .s_axi_wstrb(axi_wstrb),            // byte select signal for write operation.
    .s_axi_wvalid(axi_wvalid),          // master signals write data is valid.
    .s_axi_wready(axi_wready),          // slave ready to accept the write data.
    .s_axi_araddr(axi_araddr),
    .s_axi_arready(axi_arready),        // slave ready to fetch read address.
    .s_axi_arvalid(axi_arvalid),        // master signals read addr/ctrl valid.
    .s_axi_bready(axi_bready),          // master is ready to accept the response.
    .s_axi_bresp(axi_bresp),            // reponse code from the slave.
    .s_axi_bvalid(axi_bvalid),          // slave has sent the respond signal.
    .s_axi_rdata(axi_rdata),            // read data from the slave.
    .s_axi_rready(axi_rready),          // master is ready to accept the read data.
    .s_axi_rresp(axi_rresp),            // slave sent read response.
    .s_axi_rvalid(axi_rvalid),          // slave signals read data ready.

    // Interface ports to the SD Card.
    .ext_spi_clk(clk),
    .io0_i(1'b0),
    .io0_o(spi_mosi),
    .io0_t(io0_t_dummy),                // tag signal for mosi (ignore it)
    .io1_i(spi_miso),
    .io1_o(io1_o_dummy),                // output signal for io1 (ignore it)
    .io1_t(io1_t_dummy),                // tag signal for miso (ignore it)
    .sck_i(1'b0),
    .sck_o(spi_sck),
    .sck_t(sck_t_dummy),                // tag signal for sck (ignore it)
    .ss_i(1'b0),
    .ss_o(spi_ss),
    .ss_t(ss_t_dummy),                  // tag signal for ss (ignore it)
    .ip2intc_irpt(irpt_dummy)           // interrupt from SPI controller (ignore it)
);

// ----------------------------------------------------------------------------
//  cdc_sync.
//
generate
    for (i = 0; i < `CORE_NUMS; i = i + 1)
    begin
        cdc_sync synchronizer
        (
            .clk_core(clk),
            .clk_memc(ui_clk),
            .rst_i(rst),
            // .rst_core_i(rst),
            // .rst_memc_i(ui_rst),

            .P_strobe_i(L2_MEM_strobe[i]),
            .P_addr_i(L2_MEM_addr[i]),
            .P_rw_i(L2_MEM_rw[i]),
            .P_wt_data_i(L2_MEM_wt_data[i]),
            .P_done_o(L2_MEM_done[i]),
            .P_rd_data_o(L2_MEM_rd_data[i]),

            .P_strobe_o(MEM_strobe_ui_clk[i]),
            .P_addr_o(MEM_addr_ui_clk[i]),
            .P_rw_o(MEM_rw_ui_clk[i]),
            .P_wt_data_o(MEM_wt_data_ui_clk[i]),
            .P_done_i(MEM_done_ui_clk[i]),
            .P_rd_data_i(MEM_rd_data_ui_clk[i])
        );
    end
endgenerate
// ----------------------------------------------------------------------------
//  mem_arbiter.
//
mem_arbiter Memory_Arbiter
(
    // System signals
    .clk_i(ui_clk),
    .rst_i(rst),
    // .rst_i(ui_rst),

    // Aquila M_P0_CACHE master port interface signals
    .P0_MEM_strobe_i(MEM_strobe_ui_clk[0]),
    .P0_MEM_addr_i(MEM_addr_ui_clk[0]),
    .P0_MEM_rw_i(MEM_rw_ui_clk[0]),
    .P0_MEM_data_i(MEM_wt_data_ui_clk[0]),
    .P0_MEM_done_o(MEM_done_ui_clk[0]),
    .P0_MEM_data_o(MEM_rd_data_ui_clk[0]),

    // Aquila M_P1_DCACHE master port interface signals
    .P1_MEM_strobe_i(MEM_strobe_ui_clk[1]),
    .P1_MEM_addr_i(MEM_addr_ui_clk[1]),
    .P1_MEM_rw_i(MEM_rw_ui_clk[1]),
    .P1_MEM_data_i(MEM_wt_data_ui_clk[1]),
    .P1_MEM_done_o(MEM_done_ui_clk[1]),
    .P1_MEM_data_o(MEM_rd_data_ui_clk[1]),
    
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
//  MIG.
//
mig_7series_0 MIG(

    // Memory interface ports
    .ddr3_addr(ddr3_addr),                  // output [13:0]  ddr3_addr
    .ddr3_ba(ddr3_ba),                      // output [2:0]   ddr3_ba
    .ddr3_cas_n(ddr3_cas_n),                // output         ddr3_cas_n
    .ddr3_ck_n(ddr3_ck_n),                  // output [0:0]   ddr3_ck_n
    .ddr3_ck_p(ddr3_ck_p),                  // output [0:0]   ddr3_ck_p
    .ddr3_cke(ddr3_cke),                    // output [0:0]   ddr3_cke
    .ddr3_ras_n(ddr3_ras_n),                // output         ddr3_ras_n
    .ddr3_reset_n(ddr3_reset_n),            // output         ddr3_reset_n
    .ddr3_we_n(ddr3_we_n),                  // output         ddr3_we_n
    .ddr3_dq(ddr3_dq),                      // inout [15:0]   ddr3_dq
    .ddr3_dqs_n(ddr3_dqs_n),                // inout [1:0]    ddr3_dqs_n
    .ddr3_dqs_p(ddr3_dqs_p),                // inout [1:0]    ddr3_dqs_p
    .init_calib_complete(MEM_calib),        // output         init_calib_complete

    .ddr3_cs_n(ddr3_cs_n),                  // output [0:0]   ddr3_cs_n
    .ddr3_dm(ddr3_dm),                      // output [1:0]   ddr3_dm
    .ddr3_odt(ddr3_odt),                    // output [0:0]   ddr3_odt

    // Application interface ports
    .app_addr(MEM_addr),                    // input [27:0]   app_addr
    .app_cmd(MEM_cmd),                      // input [2:0]    app_cmd
    .app_en(MEM_en),                        // input          app_en
    .app_wdf_data(MEM_wdf_data),            // input [127:0]  app_wdf_data
    .app_wdf_end(MEM_wdf_end),              // input          app_wdf_end
    .app_wdf_mask(MEM_wdf_mask),            // input [15:0]   app_wdf_mask
    .app_wdf_wren(MEM_wdf_wren),            // input          app_wdf_wren
    .app_rd_data(MEM_rd_data),              // output [127:0] app_rd_data
    .app_rd_data_end(MEM_rd_data_end),      // output         app_rd_data_end
    .app_rd_data_valid(MEM_rd_data_valid),  // output         app_rd_data_valid
    .app_rdy(MEM_rdy),                      // output         app_rdy
    .app_wdf_rdy(MEM_wdf_rdy),              // output         app_wdf_rdy
    .app_sr_req(MEM_sr_req),                // input          app_sr_req
    .app_ref_req(MEM_ref_req),              // input          app_ref_req
    .app_zq_req(MEM_zq_req),                // input          app_zq_req
    .app_sr_active(MEM_sr_active),          // output         app_sr_active
    .app_ref_ack(MEM_ref_ack),              // output         app_ref_ack
    .app_zq_ack(MEM_zq_ack),                // output         app_zq_ack

    // System Clock & Reset Ports
`ifdef ARTY
    .sys_clk_i(clk_166M),                   // input          memory controller ref. clock
    .sys_rst(resetn_i),                     // input          sys_rst

    // 200MHz Reference Clock Ports (only needed when the ui_clk is not 200MHz)
    .clk_ref_i(clk_200M),
`else // KC705
    .sys_clk_n(sys_clk_n),                  // input          memory controller ref. clock
    .sys_clk_p(sys_clk_p),
    .sys_rst(reset_i),                      // input          sys_rst

    // 200MHz Reference Clock Ports (only needed when the ui_clk is not 200MHz)
    // .clk_ref_i(clk_200M),
`endif
    .ui_clk(ui_clk),                        // output         ui_clk
    .ui_clk_sync_rst(ui_rst)                // output         ui_clk_sync_rst
);

endmodule
