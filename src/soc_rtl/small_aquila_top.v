`timescale 1 ns / 1 ps
`include "aquila_config.vh"

module small_aquila_top #(parameter integer HART_ID = 0,parameter integer XLEN = 32,parameter integer CLSIZE = 128)
(
    //system signals
    input clk_i,
    input rst_i,
    // coherence unit signals
    input CU_L1_probe_strobe_i,
    input [31:0] CU_L1_probe_addr_i,
    input CU_L1_invalidate_i,
    input [127:0] CU_L1_data_i,
    input        CU_L1_make_exclusive_i,
    input        CU_L1_response_ready_i,

    output [127:0] L1_CU_data_o,
    output [31:0] L1_CU_addr_o,
    output L1_CU_strobe_o,
    output L1_CU_rw_o,
    output L1_CU_share_modify_o,
    output L1_CU_response_ready_o,
    output L1_CU_replacement_o,

    // testing signals
    //core top signals simulation
    input p_strobe_i,
    input p_rw_i,
    input [3:0] p_byte_enable_i,
    input [31:0] p_addr_i,
    input [31:0] p_data_i,
    output [31:0] p_data_o,
    output p_ready_o,
    input p_flush_i,
    output busy_flushing_o,
    // L1 D cache signals
    output D_test_init_done_o,
    output D_test_valid_o,
    output D_test_dirty_o,
    output D_test_share_o
);

    dcache #(.XLEN(32), .CACHE_SIZE(`DCACHE_SIZE), .CLSIZE(`CLP))
    D_Cache(
        //system signals
        .clk_i(clk_i),
        .rst_i(rst_i),
        // Processor signals
        .p_strobe_i(p_strobe_i),
        .p_rw_i(p_rw_i),
        .p_byte_enable_i(p_byte_enable_i),
        .p_addr_i(p_addr_i),
        .p_data_i(p_data_i),
        .p_data_o(p_data_o),
        .p_ready_o(p_ready_o),
        .p_flush_i(p_flush_i),
        .busy_flushing_o(busy_flushing_o),
        //Cache coherence signals 
        .probe_strobe_i(CU_L1_probe_strobe_i),
        .invalidate_i(CU_L1_invalidate_i),
        .probe_addr_i(CU_L1_probe_addr_i),
        .coherence_data_i(CU_L1_data_i),
        .coherence_done_i(CU_L1_response_ready_i),
        .make_exclusive_i(CU_L1_make_exclusive_i),

        .coherence_data_o(L1_CU_data_o),
        .coherence_addr_o(L1_CU_addr_o),
        .coherence_strobe_o(L1_CU_strobe_o),
        .coherence_replacement_o(L1_CU_replacement_o),
        .coherence_rw_o(L1_CU_rw_o),
        .share_modify_o(L1_CU_share_modify_o),
        .response_ready_o(L1_CU_response_ready_o),
        //Test signals 
        .init_done_o(D_test_init_done),
        .test_valid_o(D_test_valid_o),
        .test_dirty_o(D_test_dirty_o),
        .test_share_o(D_test_share_o)
    );
    
endmodule