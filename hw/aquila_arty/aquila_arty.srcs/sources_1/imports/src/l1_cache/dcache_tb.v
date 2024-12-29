`timescale 1ns / 1ps
`include "aquila_config.vh"

module dcache_tb;
    reg clk_i;
    reg rst_i;

    reg p_strobe_i;
    reg p_rw_i;
    reg [3:0] p_byte_enable_i;
    reg [31:0] p_addr_i;
    reg [31:0] p_data_i;
    wire [31:0] p_data_o;
    wire p_ready_o;
    reg p_flush_i;
    wire busy_flushing_o;

    reg probe_strobe_i;
    reg invalidate_i;
    reg [31:0] probe_addr_i;
    reg [127:0] coherence_data_i;
    reg coherence_done_i;
    reg make_exclusive_i;

    wire [127:0] coherence_data_o;
    wire [31:0] coherence_addr_o;
    wire coherence_strobe_o;
    wire coherence_rw_o;
    wire share_modify_o;
    wire response_ready_o;
    
    wire coherence_replacement_o;

    wire init_done_o;
    wire test_valid_o;
    wire test_dirty_o;
    wire test_share_o;

    dcache_new #(.XLEN(32), .CACHE_SIZE(`DCACHE_SIZE), .CLSIZE(`CLP))
    D_Cache_new(
        .clk_i(clk_i),
        .rst_i(rst_i),

        .p_strobe_i(p_strobe_i),
        .p_rw_i(p_rw_i),
        .p_byte_enable_i(p_byte_enable_i),
        .p_addr_i(p_addr_i),
        .p_data_i(p_data_i),
        .p_data_o(p_data_o),
        .p_ready_o(p_ready_o),
        .p_flush_i(p_flush_i),
        .busy_flushing_o(busy_flushing_o),
        
        .probe_strobe_i(probe_strobe_i),
        .invalidate_i(invalidate_i),
        .probe_addr_i(probe_addr_i),
        .coherence_data_i(coherence_data_i),
        .coherence_done_i(coherence_done_i),
        .make_exclusive_i(make_exclusive_i),

        .coherence_data_o(coherence_data_o),
        .coherence_addr_o(coherence_addr_o),
        .coherence_strobe_o(coherence_strobe_o),
        .coherence_replacement_o(coherence_replacement_o),
        .coherence_rw_o(coherence_rw_o),
        .share_modify_o(share_modify_o),
        .response_ready_o(response_ready_o),
        .init_done_o(init_done_o),
        .test_valid_o(test_valid_o),
        .test_dirty_o(test_dirty_o),
        .test_share_o(test_share_o)
    );

    reg init_done;
    always @(posedge init_done_o) begin
        init_done <= 1;
    end

    initial clk_i = 0;
    always #10 clk_i = ~clk_i;

    initial begin
        //initialization
        rst_i = 1;
        p_strobe_i = 0;
        p_rw_i = 0;
        p_byte_enable_i = 4'b1111;
        p_addr_i = 32'h0;
        p_data_i = 32'h0;
        p_flush_i = 0;
        probe_strobe_i = 0;
        invalidate_i = 0;
        probe_addr_i = 32'h0;
        coherence_data_i = 128'h0;
        coherence_done_i = 0;
        make_exclusive_i = 0;

        #20 rst_i = 0;
        @(posedge init_done);
        //*******fence.i***********************************************
        @(posedge clk_i);
        p_flush_i = 1;
        @(negedge busy_flushing_o);
        p_flush_i = 0;
        //************************************************************


        //****write miss (get M)***************************************
        $display("Test write miss: get M");
        write_miss_test(.addr(32'h80051000),
         .write_data(32'h12345678),
         .data_fromMem(128'h00000000_87654321_12345678_87654321));
        
        read_hit_test(.addr(32'h80051000),  .expected_valid(1), .expected_dirty(1), .expected_share(0));
        $display();

        $display("Test write miss: get M");
        write_miss_test(.addr(32'h80051070),
         .write_data(32'h12345678),
         .data_fromMem(128'h00000000_87654321_12345678_87654321));
        
        read_hit_test(.addr(32'h80051070),  .expected_valid(1), .expected_dirty(1), .expected_share(0));
        $display();
        //************************************************************

        //**** read miss get S (Exclusive)******************************
        $display("Test read miss: get S (I->E)");
        read_miss_test(.addr(32'h80051010),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(1));

        read_hit_test(.addr(32'h80051010),  .expected_valid(1), .expected_dirty(0), .expected_share(0));
        $display();

        $display("Test read miss: get S (I->E)");
        read_miss_test(.addr(32'h80051040),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(1));

        read_hit_test(.addr(32'h80051040),  .expected_valid(1), .expected_dirty(0), .expected_share(0));
        $display();
        //************************************************************
        
        //** read miss get S (Share) *********************************
        $display("Test read miss: get S (I -> S)");
        read_miss_test(.addr(32'h80051030),
         .data(128'h49685743_25148964_36524189_65842351), 
         .make_exclusive(0));
         
        read_hit_test(.addr(32'h80051030),  .expected_valid(1), .expected_dirty(0), .expected_share(1));
        $display();
        //************************************************************

        //** probe hit (other get S on M line)**********************************
        $display("Test other get S on M line:");
        //expected: send data to requestor
        other_get_test(.addr(32'h80051000), .invalidate(0), .response_en(1));
        //check if the line turn to S (M -> S)
        read_hit_test(.addr(32'h80051000),  .expected_valid(1), .expected_dirty(0), .expected_share(1));
        $display();
        //************************************************************

        //** probe hit (other get S on E line)**********************************
        $display("Test other get S on E line:");
        //expected: send data to requestor
        other_get_test(.addr(32'h80051010), .invalidate(0), .response_en(1));
        //check if the line turn to S (E->S)
        read_hit_test(.addr(32'h80051010),  .expected_valid(1), .expected_dirty(0), .expected_share(1));
        $display();
        //************************************************************

        //** probe hit (other get S on S line)**********************************
        $display("Test other get S on S line:");
        //expected: do nothing
        other_get_test(.addr(32'h80051030), .invalidate(0), .response_en(0));
        $display();
        //************************************************************

        //** probe hit (other get S on I line)**********************************
        $display("Test other get S on I line:");
        //expected: do nothing
        other_get_test(.addr(32'h80051050), .invalidate(0), .response_en(0));
        read_miss_test(.addr(32'h80051050),
         .data(128'h49685743_25148964_36524189_65842351), 
         .make_exclusive(0));

         read_hit_test(.addr(32'h80051050),  .expected_valid(1), .expected_dirty(0), .expected_share(1));
        $display();
        //************************************************************

        //** probe hit (other get M on M line) **********************************
        //expected: (1) send data to requestor (2) invalidate line
        $display("Test Other get M on M line:");
        other_get_test(.addr(32'h80051070), .invalidate(1), .response_en(1));
        //check if the line turn to I (E->I)
        read_miss_test(.addr(32'h80051070),
         .data(128'h00000000_87654321_12345678_87654321), 
         .make_exclusive(1));

         read_hit_test(.addr(32'h80051070),  .expected_valid(1), .expected_dirty(0), .expected_share(0));
        $display();
        //************************************************************

        //** probe hit (other get M on E line) **********************************
        $display("Test Other get M on E line:");
        other_get_test(.addr(32'h80051040), .invalidate(1), .response_en(1));
        read_miss_test(.addr(32'h80051040),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(0));

         read_hit_test(.addr(32'h80051040),  .expected_valid(1), .expected_dirty(0), .expected_share(1));
        $display();
        //************************************************************

        //** probe hit (other get M on S line) **********************************
        $display("Test Other get M on S line:");
        other_get_test(.addr(32'h80051010), .invalidate(1), .response_en(0));
        read_miss_test(.addr(32'h80051010),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(0));

         read_hit_test(.addr(32'h80051010),  .expected_valid(1), .expected_dirty(0), .expected_share(1));
        $display();
        //************************************************************

        //** probe hit (other get M on I line) **********************************
        $display("Test Other get M on I line:");
        other_get_test(.addr(32'h80051060), .invalidate(1), .response_en(0));
        read_miss_test(.addr(32'h80051060),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(1));

         read_hit_test(.addr(32'h80051060),  .expected_valid(1), .expected_dirty(0), .expected_share(0));
        $display();
        //************************************************************

        //** test replacement ******************************************
        $display("Test read miss: get S (I->E)");
        read_miss_test(.addr(32'h80051080),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(1));

        read_hit_test(.addr(32'h80051080),  .expected_valid(1), .expected_dirty(0), .expected_share(0));

        $display("Test read miss: get S (I->E)");
        read_miss_test(.addr(32'h80052080),
         .data(128'h46588474_12345678_87654321_12345678), 
         .make_exclusive(1));
         read_hit_test(.addr(32'h80052080),  .expected_valid(1), .expected_dirty(0), .expected_share(0));

        $display("Test read miss: get S (I->E)");
        read_miss_test(.addr(32'h80053080),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(1));
         read_hit_test(.addr(32'h80053080),  .expected_valid(1), .expected_dirty(0), .expected_share(0));

        $display("Test read miss: get S (I->E)");
        read_miss_test(.addr(32'h80054080),
         .data(128'h46588474_12345678_87654321_12345678), 
         .make_exclusive(1));
         read_hit_test(.addr(32'h80054080),  .expected_valid(1), .expected_dirty(0), .expected_share(0));

        $display("Test read miss: get S (I->E)");
        read_miss_test(.addr(32'h80055080),
         .data(128'h12385678_87654321_12345678_87654321), 
         .make_exclusive(1));
         read_hit_test(.addr(32'h80055080),  .expected_valid(1), .expected_dirty(0), .expected_share(0));
        $display();
        //************************************************************

        //** test write hit on S line **********************************
        $display("Test write hit on S line:");
        @(posedge clk_i);
        @(posedge clk_i);
        read_hit_test(.addr(32'h80051010),  .expected_valid(1), .expected_dirty(0), .expected_share(1));
        p_strobe_i = 1;
        p_rw_i = 1; // Write operation
        p_addr_i = 32'h80051010;
        p_data_i = 32'h87654321;
        @(posedge clk_i);
        @(posedge clk_i);
        @(posedge clk_i);
        $display("share_modify_o = %d",share_modify_o);
        $display("coherence_data_o = %x",coherence_data_o);
        if(share_modify_o != 1) begin
            $fatal("Write hit on S line Test Failed: addr=0x%x, expected share_modify_o=1, got share_modify_o=%d", 32'h80051010, share_modify_o);
        end
        @(posedge clk_i);
        @(posedge clk_i);
        coherence_done_i = 1;
        @(posedge clk_i);
        coherence_done_i = 0;
        p_strobe_i = 0;
        p_addr_i = 0;
        p_rw_i = 0;
        @(posedge clk_i);
        @(posedge clk_i);
        read_hit_test(.addr(32'h80051010),  .expected_valid(1), .expected_dirty(1), .expected_share(0));
        $display();
        //************************************************************

        #100 $finish();
    end

task read_hit_test;
    input [31:0] addr;
    input    expected_valid;
    input    expected_dirty;
    input    expected_share;

    begin
        $display("-Test read hit: Reading from addr 0x%x", addr);
        @(posedge clk_i);
        @(posedge clk_i);
        p_strobe_i = 1;
        p_rw_i = 0; // Read operation
        p_addr_i = addr;
        @(posedge clk_i);
        @(posedge clk_i);
    
        if(p_ready_o != 1) begin
            $fatal("Read hit Test Failed: addr=0x%x, expected hit, got miss", addr);
        end 
        if (test_valid_o != expected_valid || test_dirty_o != expected_dirty || test_share_o != expected_share) begin
            $fatal("Read Test Failed: addr 0x%x, expected valid=%d, dirty=%d, share=%d, got valid=%d, dirty=%d, share=%d",
                        addr, expected_valid, expected_dirty, expected_share, test_valid_o, test_dirty_o, test_share_o);
        end else begin
            $display("Read Test Passed: addr 0x%x contains 0x%x, valid=%d, dirty=%d, share=%d",
                        addr, p_data_o, test_valid_o, test_dirty_o, test_share_o);
        end
        p_addr_i = 0;
        p_strobe_i = 0;
        @(posedge clk_i);
        @(posedge clk_i);
       end
endtask

task read_miss_test;
    input [31:0] addr;
    input [127:0] data;
    input    make_exclusive;

    begin
        $display("-Test read miss: Reading from addr 0x%x", addr);
        @(posedge clk_i);
        @(posedge clk_i);
        p_strobe_i = 1;
        p_rw_i = 0; // Read operation
        p_addr_i = addr;
        @(posedge clk_i);
        @(posedge clk_i);
    
        if(p_ready_o) begin
            $fatal("Read miss Test Failed: addr=0x%x, expected miss, got hit", addr);
        end 
    
        p_strobe_i = 1;
        p_rw_i = 0;
        p_addr_i = addr;
        @(posedge clk_i);
        @(posedge clk_i);
        if(coherence_replacement_o)begin
            $display("Replacement happened at addr:0x%x",addr);
            $display("Replacement data: 0x%x",coherence_data_o);
            @(posedge clk_i);
            // replacement done
            coherence_done_i = 1;
            @(posedge clk_i);
            coherence_done_i = 0;
            @(posedge clk_i);
            @(posedge clk_i);
        end
        @(posedge clk_i);
        // get data from L2 cache
        coherence_done_i = 1;
        coherence_data_i = data;
        make_exclusive_i = make_exclusive;
        @(posedge clk_i);
        coherence_done_i = 0;
        coherence_data_i = 128'h0;
        make_exclusive_i = 0;
        p_addr_i = 0;
        p_strobe_i = 0;
        @(posedge clk_i);
        @(posedge clk_i);
       end
endtask

task write_miss_test;
    input [31:0] addr;
    input [31:0] write_data;
    input [127:0] data_fromMem;
    
    begin
    $display("-Test write miss: Writing to addr 0x%x", addr);
        p_strobe_i = 1;
        p_rw_i = 1;
        p_addr_i = addr;
        p_data_i = write_data;
        @(posedge clk_i);
        @(posedge clk_i);
        if(p_ready_o) begin
            $fatal("Write miss Test Failed: addr=0x%x, expected miss, got hit", addr);
        end 
        @(posedge clk_i);
        @(posedge clk_i);
        @(posedge clk_i);
        // get data from L2 cache
        coherence_done_i = 1;
        coherence_data_i = data_fromMem;
        @(posedge clk_i);
        coherence_done_i = 0;
        coherence_data_i = 128'h0;
        p_strobe_i = 0;
        p_addr_i = 0;
        @(posedge clk_i);
        @(posedge clk_i);
    end
endtask

task other_get_test;
    input [31:0] addr;
    input    invalidate;
    input    response_en;
    begin
        probe_strobe_i = 1;
        invalidate_i = invalidate;
        probe_addr_i = addr;
        @(posedge clk_i);
        @(posedge clk_i);
        if(response_ready_o != 1) begin
            if(response_en) begin
                $fatal("Simulation failed: response_ready_o=%d (expected 1)",response_ready_o);
            end
            else begin
                $display("do nothing, addr:0x%x, response_ready_o = %d",probe_addr_i, response_ready_o);
            end
        end
        else begin
            if(response_en) begin
                $display("send data to requestor on addr:0x%x, response_ready_o = %d,coherence_data_o = %x",probe_addr_i, response_ready_o,coherence_data_o);
            end
            else begin
                $fatal("Simulation failed: response_ready_o=%d (expected 0)",response_ready_o);
            end
        end
        @(posedge clk_i);
        probe_strobe_i = 0;
        invalidate_i = 0;
        probe_addr_i = 0;
        @(posedge clk_i);
        @(posedge clk_i);
       end
endtask 
endmodule
