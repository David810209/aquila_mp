`timescale 1ns / 1ps
`include "aquila_config.vh"

module cache_tb#( parameter XLEN = 32, parameter CLSIZE = `CLP )();
    reg clk;
    reg rst;
    localparam CORE_NUMS_BITS = (`CORE_NUMS==1) ? 0 : `CORE_NUMS-1;

    // core top signals
    reg p_strobe_i[0 : CORE_NUMS_BITS];
    reg p_rw_i[0 : CORE_NUMS_BITS];
    reg [3:0] p_byte_enable_i[0 : CORE_NUMS_BITS];
    reg [31:0] p_addr_i[0 : CORE_NUMS_BITS];
    reg [31:0] p_data_i[0 : CORE_NUMS_BITS];
    wire [31:0] p_data_o[0 : CORE_NUMS_BITS];
    wire p_ready_o[0 : CORE_NUMS_BITS];
    reg p_flush_i[0 : CORE_NUMS_BITS];
    wire busy_flushing_o[0 : CORE_NUMS_BITS];

    // Test signals
    wire D_test_valid[0 : CORE_NUMS_BITS];
    wire D_test_dirty[0 : CORE_NUMS_BITS];
    wire D_test_share[0 : CORE_NUMS_BITS];
    // --------- coherence unit ----------------------------------------------------
    // to aquila top
    wire                CU_L1_probe_strobe[0 : CORE_NUMS_BITS];
    wire [XLEN-1 : 0]   CU_L1_probe_addr[0 : CORE_NUMS_BITS];
    wire                CU_L1_invalidate[0 : CORE_NUMS_BITS];
    wire [CLSIZE-1 : 0] CU_L1_data[0 : CORE_NUMS_BITS];
    wire                CU_L1_make_exclusive[0 : CORE_NUMS_BITS];
    wire                CU_L1_response_ready[0 : CORE_NUMS_BITS];
    reg [CLSIZE-1 : 0]  L1_CU_data[0 : CORE_NUMS_BITS];
    reg [XLEN-1 : 0]    L1_CU_addr[0 : CORE_NUMS_BITS];
    reg                 L1_CU_strobe[0 : CORE_NUMS_BITS];
    reg                 L1_CU_rw[0 : CORE_NUMS_BITS];
    reg                 L1_CU_share_modify[0 : CORE_NUMS_BITS];
    reg                 L1_CU_response_ready[0 : CORE_NUMS_BITS];
    reg                 L1_CU_replacement[0 : CORE_NUMS_BITS];
    // to L2 cache
    //write back to L2
    wire                CU_L2_wb;
    wire [CLSIZE-1 : 0] CU_L2_wb_data;
    wire                CU_L2_replacement;
    //request L2 data 
    wire                CU_L2_probe_strobe;
    wire [XLEN-1 : 0]   CU_L2_addr;
    wire                CU_L2_rw;
    reg                 L2_CU_ready;
    reg [CLSIZE-1:0]    L2_CU_data;
    reg                 L2_CU_make_exclusive;
    wire                CU_L2_invalidate;

    // L2 cache signals
    wire MEM_L2_ready = MEM_done_ui_clk;
    wire [127:0] MEM_L2_data = MEM_rd_data_ui_clk;
    wire L2_MEM_strobe;
    wire L2_MEM_rw;
    wire [XLEN-1:0] L2_MEM_addr;
    wire [CLSIZE-1:0] L2_MEM_data;
    wire L2_test_valid_o;
    wire L2_test_dirty_o;
    wire L2_test_share_o;
    // --------- cdc_sync ----------------------------------------------------------
    // Core 0 Memory Ports
    wire                MEM_strobe_ui_clk = L2_MEM_strobe;
    wire [XLEN-1 : 0]   MEM_addr_ui_clk = L2_MEM_addr;
    wire                MEM_rw_ui_clk = L2_MEM_rw;
    wire [CLSIZE-1 : 0] MEM_wt_data_ui_clk = L2_MEM_data;
    wire                MEM_done_ui_clk;
    wire [CLSIZE-1 : 0] MEM_rd_data_ui_clk;

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


    // quad core aquila top
    genvar i;
    generate
        for (i = 0; i < `CORE_NUMS; i = i + 1)
        begin
            small_aquila_top #(.HART_ID(i), .XLEN(XLEN), .CLSIZE(CLSIZE)) 
            small_aquila_top
            (
                //system signals
                .clk_i(clk),
                .rst_i(rst),
                // coherence unit signals
                .CU_L1_probe_strobe_i(CU_L1_probe_strobe[i]),
                .CU_L1_probe_addr_i(CU_L1_probe_addr[i]),
                .CU_L1_invalidate_i(CU_L1_invalidate[i]),
                .CU_L1_data_i(CU_L1_data[i]),
                .CU_L1_make_exclusive_i(CU_L1_make_exclusive[i]),
                .CU_L1_response_ready_i(CU_L1_response_ready[i]),
                .L1_CU_data_o(L1_CU_data[i]),
                .L1_CU_addr_o(L1_CU_addr[i]),
                .L1_CU_strobe_o(L1_CU_strobe[i]),
                .L1_CU_rw_o(L1_CU_rw[i]),
                .L1_CU_share_modify_o(L1_CU_share_modify[i]),
                .L1_CU_response_ready_o(L1_CU_response_ready[i]),
                .L1_CU_replacement_o(L1_CU_replacement[i]),
                
                // testing signals
                //core top signals simulation
                .p_strobe_i(p_strobe_i[i]),
                .p_rw_i(p_rw_i[i]),
                .p_byte_enable_i(p_byte_enable_i[i]),
                .p_addr_i(p_addr_i[i]),
                .p_data_i(p_data_i[i]),
                .p_data_o(p_data_o[i]),
                .p_ready_o(p_ready_o[i]),
                .p_flush_i(p_flush_i[i]),
                .busy_flushing_o(busy_flushing_o[i]),
                // L1 D cache signals
                .D_test_valid_o(D_test_valid[i]),
                .D_test_dirty_o(D_test_dirty[i]),
                .D_test_share_o(D_test_share[i])
            );
        end
    endgenerate 

// ----------------------------------
//  coherence unit
// ----------------------------------
coherence_unit #(.XLEN(32), .CLSIZE(128), .CORE_NUMS_BITS(CORE_NUMS_BITS)) 
    coherence_unit
    (
        //===================== System signals =====================//
        .clk_i(clk),
        .rst_i(rst),
        //===================== to aquila top =====================//
        // request data from L1 cache
        .broadcast_strobe(L1_CU_strobe),
        .read_write(L1_CU_rw),
        .data_address(L1_CU_addr),
        .share_modify(L1_CU_share_modify),
        .Data(CU_L1_data),
        .request_data_ready(CU_L1_response_ready),
        .replacement(L1_CU_replacement),

        // response data to L1 cache
        .probe_strobe(CU_L1_probe_strobe),
        .probe_data_address(CU_L1_probe_addr),
        .invalidate(CU_L1_invalidate),
        .make_exclusive_L1(CU_L1_make_exclusive),
        .response_data(L1_CU_data),
        .response_data_ready(L1_CU_response_ready),
        //===================== L2 cache =====================//
        //write back to L2
        .write_to_L2(CU_L2_wb),
        .data_to_L2(CU_L2_wb_data),
        .replacement_L2(CU_L2_replacement),
        //request L2 data
        .probe_strobe_L2(CU_L2_probe_strobe),
        .address_to_L2(CU_L2_addr),
        .L1_iswrite_L2(CU_L2_rw),
        .response_data_L2(L2_CU_data),
        .response_ready_L2(L2_CU_ready),
        .make_L1_exclusive_L2(L2_CU_make_exclusive),
        // Invalidate L2 data
        .invalidate_L2(CU_L2_invalidate)
    );


// ----------------------------------
//  L2 cache
// ----------------------------------
L2cache #(.XLEN(XLEN), .CLSIZE(CLSIZE), .CACHE_SIZE(`L2CACHE_SIZE))
    L2cache
    (
        //system signals
        .clk_i(clk),
        .rst_i(rst),
        //coherence unit signals
        .wb_i(CU_L2_wb),
        .wb_replacement_i(CU_L2_replacement),
        .wb_data_i(CU_L2_wb_data),
        .probe_strobe_i(CU_L2_probe_strobe),
        .probe_rw_i(CU_L2_rw),
        .CU_L2_addr_i(CU_L2_addr),
        .response_data_o(L2_CU_data),
        .response_ready_o(L2_CU_ready),
        .make_exclusive_o(L2_CU_make_exclusive),
        .invalidate_i(CU_L2_invalidate),
        // memory controller signals
        .m_ready_i(MEM_L2_ready),
        .m_data_i(MEM_L2_data),
        .m_strobe_o(L2_MEM_strobe),
        .m_rw_o(L2_MEM_rw),
        .m_addr_o(L2_MEM_addr),
        .m_data_o(L2_MEM_data),
        // test signals
        .test_valid_o(L2_test_valid_o),
        .test_dirty_o(L2_test_dirty_o),
        .test_share_o(L2_test_share_o)
    );
    // ----------------------------------------------------------------------------
//  mem_arbiter.
//
mem_arbiter Memory_Arbiter
(
    // System signals
    .clk_i(clk),
    .rst_i(rst),

    // Aquila M_P0_CACHE master port interface signals
    .P0_MEM_strobe_i(MEM_strobe_ui_clk),
    .P0_MEM_addr_i(MEM_addr_ui_clk),
    .P0_MEM_rw_i(MEM_rw_ui_clk),
    .P0_MEM_data_i(MEM_wt_data_ui_clk),
    .P0_MEM_done_o(MEM_done_ui_clk),
    .P0_MEM_data_o(MEM_rd_data_ui_clk),

    // Aquila M_P1_DCACHE master port interface signals
    .P1_MEM_strobe_i(0),
    .P1_MEM_addr_i(0),
    .P1_MEM_rw_i(0),
    .P1_MEM_data_i(0),
    .P1_MEM_done_o(),
    .P1_MEM_data_o(),
    
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
    initial clk = 0;
    always #10 clk = ~clk;
    
    initial begin
        rst = 1;
        p_strobe_i[0] = 0;
        p_rw_i[0] = 0;
        p_byte_enable_i[0] = 4'b1111;
        p_addr_i[0] = 0;
        p_data_i[0] = 0;
        p_flush_i[0] = 0;
        p_strobe_i[1] = 0;
        p_rw_i[1] = 0;
        p_byte_enable_i[1] = 4'b1111;
        p_addr_i[1] = 0;
        p_data_i[1] = 0;
        p_flush_i[1] = 0;
        p_strobe_i[2] = 0;
        p_rw_i[2] = 0;
        p_byte_enable_i[2] = 4'b1111;
        p_addr_i[2] = 0;
        p_data_i[2] = 0;
        p_flush_i[2] = 0;
        p_strobe_i[3] = 0;
        p_rw_i[3] = 0;
        p_byte_enable_i[3] = 4'b1111;
        p_addr_i[3] = 0;
        p_data_i[3] = 0;
        p_flush_i[3] = 0;
        @(posedge clk);
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        //****write miss (get M)***************************************
        $display("------------------------------------");
        // easy write miss test
        $display("easy write miss test");
        write_miss_test(.addr(32'h80051000), .hart_id(2'd0), .write_data(32'h12345678));
        read_hit_test(.addr(32'h80051000),.hart_id(2'd0), .expected_valid(1), .expected_dirty(1), .expected_share(0), .expected_data(32'h12345678));
        $display();

        write_hit_test(.addr(32'h80051004), .hart_id(2'd0), .write_data(32'h23456789));
        read_hit_test(.addr(32'h80051004),.hart_id(2'd0), .expected_valid(1), .expected_dirty(1), .expected_share(0), .expected_data(32'h23456789));
        $display();

        //**** relpacement -> write back to L2 -> getS again -> turn to E******************************
        $display("------------------------------------");
        $display("Test replacement: write back to L2 -> getS -> turn to E");
        write_miss_test(.addr(32'h80052000), .hart_id(2'd0), .write_data(32'h19687354));
        write_miss_test(.addr(32'h80053000), .hart_id(2'd0), .write_data(32'h97684351));
        write_miss_test(.addr(32'h80054000), .hart_id(2'd0), .write_data(32'h19684351));
        write_miss_test(.addr(32'h80055000), .hart_id(2'd0), .write_data(32'h19685473));
        
        //next test
        write_miss_test(.addr(32'h80057000), .hart_id(2'd0), .write_data(32'h19687354));
        //next test
        write_miss_test(.addr(32'h80059000), .hart_id(2'd0), .write_data(32'h96854735));
        //FIFO->replace 0x8005101x and write back to L2 cache
        read_miss_test(.addr(32'h80051000), .hart_id(2'd0));
        //expected get Exclusice state
        read_hit_test(.addr(32'h80051000), .hart_id(2'd0),  .expected_valid(1), .expected_dirty(0), .expected_share(0), .expected_data(32'h12345678));
         //FIFO->replace 0x8005201x and write back to L2 cache
        read_miss_test(.addr(32'h80052000), .hart_id(2'd0));
        // expected get Exclusive state
        read_hit_test(.addr(32'h80052000), .hart_id(2'd0),  .expected_valid(1), .expected_dirty(0), .expected_share(0), .expected_data(32'h19687354));

        read_miss_test(.addr(32'h80051000), .hart_id(2'd1));
        read_hit_test(.addr(32'h80051000), .hart_id(2'd0),  .expected_valid(1), .expected_dirty(0), .expected_share(1), .expected_data(32'h12345678));
        read_hit_test(.addr(32'h80051000), .hart_id(2'd1),  .expected_valid(1), .expected_dirty(0), .expected_share(1), .expected_data(32'h12345678));

        read_miss_test(.addr(32'h80053000), .hart_id(2'd1));
        read_hit_test(.addr(32'h80053000), .hart_id(2'd1),  .expected_valid(1), .expected_dirty(0), .expected_share(0), .expected_data(32'h97684351));
        read_miss_test(.addr(32'h80053000), .hart_id(2'd0));
        read_hit_test(.addr(32'h80053000), .hart_id(2'd0),  .expected_valid(1), .expected_dirty(0), .expected_share(1), .expected_data(32'h97684351));
        read_hit_test(.addr(32'h80053000), .hart_id(2'd1),  .expected_valid(1), .expected_dirty(0), .expected_share(1), .expected_data(32'h97684351));
        $display("------------------------------------");
        //************************************************************

    // //************************************************************

        #100 $finish();
    end

task read_hit_test;
    input [31:0] addr;
    input [1:0] hart_id;
    input    expected_valid;
    input    expected_dirty;
    input    expected_share;
    input  [XLEN-1:0] expected_data;

    begin
        $display("-Test read hit on core %d: Reading from addr 0x%x",hart_id, addr);
        @(posedge clk);
        @(posedge clk);
        p_strobe_i[hart_id]  = 1;
        p_rw_i[hart_id]  = 0; // Read operation
        p_addr_i[hart_id]  = addr;
        @(posedge p_ready_o[hart_id]);
        if (D_test_valid[hart_id] != expected_valid || 
            D_test_dirty[hart_id] != expected_dirty || 
            D_test_share[hart_id] != expected_share ||
            p_data_o[hart_id] != expected_data ) begin
            $display("<FAILED> Read Test: addr 0x%x, expected valid=%d, dirty=%d, share=%d, data = 0x%x;\n got valid=%d, dirty=%d, share=%d,data=0x%x",
                        addr, expected_valid, expected_dirty, expected_share,expected_data, D_test_valid[hart_id] , D_test_dirty[hart_id], D_test_share[hart_id],p_data_o[hart_id]);
        end else begin
            $display("<PASSED> Read Test: addr 0x%x , valid=%d, dirty=%d, share=%d,data =  0x%x",
                        addr,  D_test_valid[hart_id], D_test_dirty[hart_id],  D_test_share[hart_id], expected_data);
        end
        @(posedge clk);
        p_addr_i[hart_id]  = 0;
        p_strobe_i[hart_id]  = 0;
        @(posedge clk);
        @(posedge clk);
       end
endtask

task read_miss_test;
    input [31:0] addr;
    input [1:0] hart_id;

    begin
        $display("-Test read miss on core %d: Reading from addr 0x%x",hart_id, addr);
        @(posedge clk);
        @(posedge clk);
        p_strobe_i[hart_id]  = 1;
        p_rw_i[hart_id]  = 0; // Read operation
        p_addr_i[hart_id] = addr;
        @(posedge clk);
        @(posedge clk);
        if(p_ready_o[hart_id]) begin
            $display("<FAILED> Read miss Test: addr=0x%x, expected miss, got hit", addr);
        end 
        @(posedge p_ready_o[hart_id]);
        @(posedge clk);
        p_addr_i[hart_id] = 0;
        p_strobe_i[hart_id] = 0;
        $display();
        @(posedge clk);
        @(posedge clk);
       end
endtask

task write_hit_test;
    input [31:0] addr;
    input [31:0] write_data;
    input [1:0] hart_id;
    begin
        $display("-Test write hit on core %d: Writing (data=0x%x) to addr 0x%x", hart_id, write_data, addr);
        p_strobe_i[hart_id] = 1;
        p_rw_i[hart_id] = 1;
        p_addr_i[hart_id] = addr;
        p_data_i[hart_id] = write_data;
        @(posedge p_ready_o[hart_id]);
        @(posedge clk);
        p_strobe_i[hart_id] = 0;
        p_addr_i[hart_id] = 0;
        p_rw_i[hart_id] = 0;
        p_data_i[hart_id] = 0;
        @(posedge clk);
        @(posedge clk);
    end
endtask


task write_miss_test;
    input [31:0] addr;
    input [31:0] write_data;
    input [1:0] hart_id;
    
    begin
        $display("-Test write miss on core %d: Writing (data=0x%x) to addr 0x%x", hart_id, write_data, addr);
        p_strobe_i[hart_id] = 1;
        p_rw_i[hart_id] = 1;
        p_addr_i[hart_id] = addr;
        p_data_i[hart_id] = write_data;
        @(posedge clk);
        @(posedge clk);
        if(p_ready_o[hart_id]) begin
            $display("<FAILED> Write miss Test: addr=0x%x, expected miss, got hit", addr);
        end 
        @(posedge clk);
        @(posedge p_ready_o[hart_id]);
        @(posedge clk);
        p_strobe_i[hart_id] = 0;
        p_addr_i[hart_id] = 0;
        p_rw_i[hart_id] = 0;
        p_data_i[hart_id] = 0;
        $display();
        @(posedge clk);
        @(posedge clk);
    end
endtask

endmodule
