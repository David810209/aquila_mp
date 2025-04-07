`timescale 1ns / 1ps
`include "aquila_config.vh"

module coherence_unit #(parameter XLEN = 32, parameter CLSIZE = 128, parameter CORE_NUMS_BITS =3)(
    //===================== System signals =====================//
    input                     clk_i,
    input                     rst_i,
    //===================== CORE 0-3 =====================//
    // request data
    input                     broadcast_strobe[0 : 3],
    input                     read_write[0 : 3],
    input  [XLEN-1 : 0]       data_address[0 : 3],
    input                     share_modify[0 : 3],
    output reg [CLSIZE-1 :0]  Data[0 : 3],
    output reg                request_data_ready[0 : 3],
    input                     replacement[0 : 3],
    input                     L1_is_instr_fetch[0 : 3],
    // response data
    output reg                probe_strobe[0 : 3],
    output reg [XLEN-1 : 0]   probe_data_address[0 : 3],
    output reg                invalidate[0 : 3],
    input  [CLSIZE-1 : 0]     response_data[0 : 3],
    input  [CLSIZE-1 : 0]       write_back_data[0 : 3],
    input                     response_data_ready[0 : 3],
    output reg                make_exclusive_L1[0 : 3],
    //===================== L2 cache =====================//
    //write back to L2
    output reg                write_to_L2,
    output reg [CLSIZE-1 : 0] data_to_L2,
    output reg                replacement_L2,
    //request L2 data
    output reg                probe_strobe_L2,
    output reg [XLEN-1 : 0]   address_to_L2,
    output reg                L1_iswrite_L2,
    input  [CLSIZE-1 : 0]     response_data_L2,
    input                     response_ready_L2,
    input                     make_L1_exclusive_L2,
    output reg                L1_is_instr_fetch_L2,
    // Invalidate L2 data
    output reg                invalidate_L2,

    //L2 invalidate L1 signal
    output  reg               CU_L2_ready_o,             // CU is ready  
    input      [XLEN-1 : 0]   L2_invalidate_L1_addr_i,   // invalidate L1 address
    input                     L2_invalidate_L1_i,        // invalidate L1 signal
    // Atomic 
    input                     P_amo_strobe,
    input  [1:0]              AMO_id,
    input                     other_amo_done[0 : 3],
    output                    CU_L1_other_amo_o[0 : 3]
    
);

reg [4:0] S, S_next;
localparam S_IDLE             = 0;
localparam S_read_miss_P0     = 1; // read miss
localparam S_write_miss_P0    = 2; // write miss
localparam S_invalidate_P0    = 3; // write hit on Shared state
localparam S_replacement_P0   = 4; // replacement

localparam S_read_miss_P1     = 5; // read miss
localparam S_write_miss_P1    = 6; // write miss
localparam S_invalidate_P1    = 7; // write hit on Shared state
localparam S_replacement_P1   = 8; // replacement

localparam S_read_miss_P2     = 9; // read miss
localparam S_write_miss_P2    = 10; // write miss
localparam S_invalidate_P2    = 11; // write hit on Shared state
localparam S_replacement_P2   = 12; // replacement

localparam S_read_miss_P3     = 13; // read miss
localparam S_write_miss_P3    = 14; // write miss
localparam S_invalidate_P3    = 15; // write hit on Shared state
localparam S_replacement_P3   = 16; // replacement

localparam S_WB_L2            = 17; // write back to L2
localparam S_invalidate_L2    = 18; // invalidate L2

reg [2:0] amo_S, amo_S_next;
localparam amo_S_idle = 0, amo_S_p0 = 1, amo_S_p1 = 2, amo_S_p2 = 3, amo_S_p3 = 4;

wire request_to_L2;
reg [XLEN-1 : 0]   invalidate_address_L2;
reg [XLEN-1 : 0] invalidate_address_r;
reg [XLEN-1 : 0] wb_addr_r;
reg [CLSIZE - 1 :0] wb_data_r;
reg [XLEN-1 : 0]   write_data_address_L2;
reg [1:0] request_L2_decision;

always @(posedge clk_i)
begin
    if(rst_i) amo_S <= amo_S_idle;
    else  amo_S <= amo_S_next;
end

always @(*) begin
    case (amo_S)
        amo_S_idle: begin
            if(P_amo_strobe) begin
                if     (AMO_id == 2'b00) amo_S_next <= amo_S_p0;
                else if(AMO_id == 2'b01) amo_S_next <= amo_S_p1;
                else if(AMO_id == 2'b10) amo_S_next <= amo_S_p2;
                else if(AMO_id == 2'b11) amo_S_next <= amo_S_p3;
            end
            else begin
                amo_S_next <= amo_S_idle;
            end
        end
        amo_S_p0: begin
            if(other_amo_done[0]) amo_S_next <= amo_S_idle;
        end
        amo_S_p1: begin
            if(other_amo_done[1]) amo_S_next <= amo_S_idle;
        end
        amo_S_p2: begin
            if(other_amo_done[2])  amo_S_next <= amo_S_idle;
        end
        amo_S_p3: begin
            if(other_amo_done[3])  amo_S_next <= amo_S_idle;
        end
        default: 
            amo_S_next <= amo_S_idle;
    endcase
end


assign CU_L1_other_amo_o[0] = amo_S != amo_S_idle && amo_S != amo_S_p0;
assign CU_L1_other_amo_o[1] = amo_S != amo_S_idle && amo_S != amo_S_p1;
assign CU_L1_other_amo_o[2] = amo_S != amo_S_idle && amo_S != amo_S_p2;
assign CU_L1_other_amo_o[3] = amo_S != amo_S_idle && amo_S != amo_S_p3;

always @(posedge clk_i)
begin
    if(rst_i) S <= S_IDLE;
    else  S <= S_next;
end

always @(*)
begin
    S_next = S;
    case(S)
        S_IDLE: begin
            if(L2_invalidate_L1_i) begin
                S_next = S_invalidate_L2;
            end
            // write back event
            else if(replacement[0] && !CU_L1_other_amo_o[0]) begin
                S_next = S_replacement_P0;
            end
            else if(replacement[1] && !CU_L1_other_amo_o[1]) begin
                S_next = S_replacement_P1;
            end
            else if(replacement[2] && !CU_L1_other_amo_o[2]) begin
                S_next = S_replacement_P2;
            end
            else if(replacement[3]  && !CU_L1_other_amo_o[3]) begin
                S_next = S_replacement_P3;
            end
            // invalidate event
            else if(share_modify[0] && !CU_L1_other_amo_o[0]) begin
                S_next = S_invalidate_P0;
            end
            else if(share_modify[1] && !CU_L1_other_amo_o[1]) begin
                S_next = S_invalidate_P1;
            end
            else if(share_modify[2] && !CU_L1_other_amo_o[2]) begin
                S_next = S_invalidate_P2;
            end
            else if(share_modify[3] && !CU_L1_other_amo_o[3]) begin
                S_next = S_invalidate_P3;
            end
            // memory request event
            else if(broadcast_strobe[0] && !CU_L1_other_amo_o[0])begin
                if(read_write[0]) begin
                    S_next = S_write_miss_P0;
                end
                else begin
                    S_next = S_read_miss_P0;
                end
            end
            else if(broadcast_strobe[1] && !CU_L1_other_amo_o[1])begin
                if(read_write[1]) begin
                    S_next = S_write_miss_P1;
                end
                else begin
                    S_next = S_read_miss_P1;
                end
            end
            else if(broadcast_strobe[2] && !CU_L1_other_amo_o[2])begin
                if(read_write[2]) begin
                    S_next = S_write_miss_P2;
                end
                else begin
                    S_next = S_read_miss_P2;
                end
            end
            else if(broadcast_strobe[3] && !CU_L1_other_amo_o[3])begin
                if(read_write[3]) begin
                    S_next = S_write_miss_P3;
                end
                else begin
                    S_next = S_read_miss_P3;
                end
            end
        end
        
        S_read_miss_P0: begin
            if(response_data_ready[1] || response_data_ready[2] || response_data_ready[3]) begin
                S_next = S_WB_L2;
            end
            else if(response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_write_miss_P0: begin
            if(response_data_ready[1] || response_data_ready[2] || response_data_ready[3] || response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_invalidate_P0: begin
            S_next = S_IDLE;
        end
        S_replacement_P0: begin
            if(response_ready_L2) S_next = S_IDLE;
        end
        S_read_miss_P1: begin
            if(response_data_ready[0] || response_data_ready[2] || response_data_ready[3]) begin
                S_next = S_WB_L2;
            end
            else if(response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_write_miss_P1: begin
            if(response_data_ready[0] || response_data_ready[2] || response_data_ready[3] || response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_invalidate_P1: begin
            S_next = S_IDLE;
        end
        S_replacement_P1: begin
            if(response_ready_L2) S_next = S_IDLE;
        end
        S_read_miss_P2: begin
            if(response_data_ready[0] || response_data_ready[1] || response_data_ready[3]) begin
                S_next = S_WB_L2;
            end
            else if(response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_write_miss_P2: begin
            if(response_data_ready[0] || response_data_ready[1] || response_data_ready[3] || response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_invalidate_P2: begin
            S_next = S_IDLE;
        end
        S_replacement_P2: begin
            if(response_ready_L2) S_next = S_IDLE;
        end
        S_read_miss_P3: begin
            if(response_data_ready[0] || response_data_ready[1] || response_data_ready[2]) begin
                S_next = S_WB_L2;
            end
            else if(response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_write_miss_P3: begin
            if(response_data_ready[0] || response_data_ready[1] || response_data_ready[2] || response_ready_L2) begin
                S_next = S_IDLE;
            end
        end
        S_invalidate_P3: begin
                S_next = S_IDLE;
        end
        S_replacement_P3: begin
            if(response_ready_L2)  S_next = S_IDLE;
        end
        S_WB_L2: begin
            if(response_ready_L2)  S_next = S_IDLE;
        end
        S_invalidate_L2: begin
            S_next = S_IDLE;
        end
    endcase
end

//registered invalidate address
always@(posedge clk_i)begin
    if(rst_i)begin
        invalidate_address_r <= 0;
    end
    else if(L2_invalidate_L1_i)begin
        invalidate_address_r <= L2_invalidate_L1_addr_i;
    end
    else if(share_modify[0])begin
        invalidate_address_r <= data_address[0];
    end
    else if(share_modify[1])begin
        invalidate_address_r <= data_address[1];
    end
    else if(share_modify[2])begin
        invalidate_address_r <= data_address[2];
    end
    else if(share_modify[3])begin
        invalidate_address_r <= data_address[3];
    end
    else if(S_next == S_IDLE)begin
        invalidate_address_r <= 0;
    end
end

always@(posedge clk_i) begin
    if(rst_i) begin
        wb_addr_r <= 0;
        wb_data_r <= 0;
    end
    else if(S == S_invalidate_P0 || S == S_invalidate_P1 || S == S_invalidate_P2 || S == S_invalidate_P3 || S == S_WB_L2) begin
        wb_addr_r <= wb_addr_r;
        wb_data_r <= wb_data_r;
    end
    else if(S == S_read_miss_P0) begin
        if(response_data_ready[1])begin
            wb_addr_r <= data_address[0];
            wb_data_r <= response_data[1];
        end
        else if(response_data_ready[2])begin
            wb_addr_r <= data_address[0];
            wb_data_r <= response_data[2];
        end
        else if(response_data_ready[3])begin
            wb_addr_r <= data_address[0];
            wb_data_r <= response_data[3];
        end
    end
    else if(S == S_read_miss_P1) begin
        if(response_data_ready[0])begin
            wb_addr_r <= data_address[1];
            wb_data_r <= response_data[0];
        end
        else if(response_data_ready[2])begin
            wb_addr_r <= data_address[1];
            wb_data_r <= response_data[2];
        end
        else if(response_data_ready[3])begin
            wb_addr_r <= data_address[1];
            wb_data_r <= response_data[3];
        end
    end
    else if(S == S_read_miss_P2) begin
        if(response_data_ready[0])begin
            wb_addr_r <= data_address[2];
            wb_data_r <= response_data[0];
        end
        else if(response_data_ready[1])begin
            wb_addr_r <= data_address[2];
            wb_data_r <= response_data[1];
        end
        else if(response_data_ready[3])begin
            wb_addr_r <= data_address[2];
            wb_data_r <= response_data[3];
        end
    end
    else if(S == S_read_miss_P3) begin
        if(response_data_ready[0])begin
            wb_addr_r <= data_address[3];
            wb_data_r <= response_data[0];
        end
        else if(response_data_ready[1])begin
            wb_addr_r <= data_address[3];
            wb_data_r <= response_data[1];
        end
        else if(response_data_ready[2])begin
            wb_addr_r <= data_address[3];
            wb_data_r <= response_data[2];
        end
    end
    else if(replacement[0] && S_next == S_replacement_P0)begin
        wb_addr_r <= data_address[0];
        wb_data_r <= write_back_data[0];
    end
    else if(replacement[1] && S_next == S_replacement_P1)begin
        wb_addr_r <= data_address[1];
        wb_data_r <= write_back_data[1];
    end
    else if(replacement[2] && S_next == S_replacement_P2)begin
        wb_addr_r <= data_address[2];
        wb_data_r <= write_back_data[2];
    end
    else if(replacement[3] && S_next == S_replacement_P3)begin
        wb_addr_r <= data_address[3];
        wb_data_r <= write_back_data[3];
    end
    else begin
        wb_addr_r <= wb_addr_r;
        wb_data_r <= wb_data_r;
    end
end

// Data[0] and request_data_ready[0]
always@(posedge clk_i)begin
    if(rst_i)begin
        Data[0] <= 0;
        make_exclusive_L1[0] <= 0;
        request_data_ready[0] <= 0;
    end
    else if(S == S_write_miss_P0 || S == S_read_miss_P0)begin
        if(response_data_ready[1]) begin
            Data[0] <= response_data[1];
            request_data_ready[0] <= 1;
        end
        else if(response_data_ready[2])begin
            Data[0] <= response_data[2];
            request_data_ready[0] <= 1;
        end
        else if(response_data_ready[3])begin
            Data[0] <= response_data[3];
            request_data_ready[0] <= 1;
        end
        else if(response_ready_L2) begin
            Data[0] <= response_data_L2;
            request_data_ready[0] <= 1;
            make_exclusive_L1[0] <= make_L1_exclusive_L2;
        end
    end
    else if(S == S_replacement_P0)begin
        if(response_ready_L2) begin
            request_data_ready[0] <= 1;
        end
        else begin
            request_data_ready[0] <= 0;
        end
    end
    else if(S_next == S_invalidate_P0) begin
        request_data_ready[0] <= 1;
    end
    else begin
        Data[0] <= 0;
        request_data_ready[0] <= 0;
        make_exclusive_L1[0] <= 0;
    end
end

//  probe_strobe[0], probe_data_address[0], invalidate[0], 
always@(posedge clk_i)begin
    if(rst_i)begin
        probe_strobe[0] <= 0;
        probe_data_address[0] <= 0;
        invalidate[0] <= 0;
    end
    else if(S == S_invalidate_P1 || S == S_invalidate_P2 || S == S_invalidate_P3 || S == S_invalidate_L2)begin
        probe_strobe[0] <= 1;
        probe_data_address[0] <= invalidate_address_r;
        invalidate[0] <= 1;
    end
    else if(request_to_L2) begin
        probe_strobe[0] <= 0;
        probe_data_address[0] <= 0;
        invalidate[0] <= 0;
    end
    else if(S == S_write_miss_P1 && S_next == S_write_miss_P1)begin
        probe_strobe[0] <= 1;
        probe_data_address[0] <= data_address[1];
        invalidate[0] <= 1;
    end
    else if(S == S_read_miss_P1 && S_next == S_read_miss_P1)begin
        probe_strobe[0] <= 1;
        probe_data_address[0] <= data_address[1];
        invalidate[0] <= 0;
    end
    else if(S == S_write_miss_P2 && S_next == S_write_miss_P2)begin
        probe_strobe[0] <= 1;
        probe_data_address[0] <= data_address[2];
        invalidate[0] <= 1;
    end
    else if(S == S_read_miss_P2 && S_next == S_read_miss_P2)begin
        probe_strobe[0] <= 1;
        probe_data_address[0] <= data_address[2];
        invalidate[0] <= 0;
    end
    else if(S == S_write_miss_P3 && S_next == S_write_miss_P3)begin
        probe_strobe[0] <= 1;
        probe_data_address[0] <= data_address[3];
        invalidate[0] <= 1;
    end
    else if(S == S_read_miss_P3 && S_next == S_read_miss_P3)begin
        probe_strobe[0] <= 1;
        probe_data_address[0] <= data_address[3];
        invalidate[0] <= 0;
    end
    else begin
        probe_strobe[0] <= 0;
        probe_data_address[0] <= 0;
        invalidate[0] <= 0;
    end
end

// Data[1] and request_data_ready[1]
always@(posedge clk_i)begin
    if(rst_i)begin
        Data[1] <= 0;
        request_data_ready[1] <= 0;
        make_exclusive_L1[1] <= 0;
    end
    else if(S == S_write_miss_P1 || S == S_read_miss_P1)begin
        if(response_data_ready[0]) begin
            Data[1] <= response_data[0];
            request_data_ready[1] <= 1;
        end
        else if(response_data_ready[2])begin
            Data[1] <= response_data[2];
            request_data_ready[1] <= 1;
        end
        else if(response_data_ready[3])begin
            Data[1] <= response_data[3];
            request_data_ready[1] <= 1;
        end
        else if(response_ready_L2) begin
            Data[1] <= response_data_L2;
            request_data_ready[1] <= 1;
            make_exclusive_L1[1] <= make_L1_exclusive_L2;
        end
    end
    else if(S == S_replacement_P1)begin
        if(response_ready_L2) begin
            request_data_ready[1] <= 1;
        end
        else begin
            request_data_ready[1] <= 0;
        end
    end
    else if(S_next == S_invalidate_P1) begin
        request_data_ready[1] <= 1;
    end
    else begin
        Data[1] <= 0;
        request_data_ready[1] <= 0;
        make_exclusive_L1[1] <= 0;
    end
end

//  probe_strobe[1], probe_data_address[1], invalidate[1], 
always@(posedge clk_i)begin
    if(rst_i)begin
        probe_strobe[1] <= 0;
        probe_data_address[1] <= 0;
        invalidate[1] <= 0;
    end
    else if(request_to_L2) begin
            probe_strobe[1] <= 0;
            probe_data_address[1] <= 0;
            invalidate[1] <= 0;
    end 
    else if(S == S_invalidate_P0 || S == S_invalidate_P2 || S == S_invalidate_P3 || S == S_invalidate_L2)begin
        probe_strobe[1] <= 1;
        probe_data_address[1] <= invalidate_address_r;
        invalidate[1] <= 1;
    end
    else if(S == S_write_miss_P0 && S_next == S_write_miss_P0)begin
        probe_strobe[1] <= 1;
        probe_data_address[1] <= data_address[0];
        invalidate[1] <= 1;
    end
    else if(S == S_read_miss_P0 && S_next == S_read_miss_P0)begin
        probe_strobe[1] <= 1;
        probe_data_address[1] <= data_address[0];
        invalidate[1] <= 0;
    end
    else if(S == S_write_miss_P2 && S_next == S_write_miss_P2)begin
        probe_strobe[1] <= 1;
        probe_data_address[1] <= data_address[2];
        invalidate[1] <= 1;
    end
    else if(S == S_read_miss_P2 && S_next == S_read_miss_P2)begin
        probe_strobe[1] <= 1;
        probe_data_address[1] <= data_address[2];
        invalidate[1] <= 0;
    end
    else if(S == S_write_miss_P3 && S_next == S_write_miss_P3)begin
        probe_strobe[1] <= 1;
        probe_data_address[1] <= data_address[3];
        invalidate[1] <= 1;
    end
    else if(S == S_read_miss_P3 && S_next == S_read_miss_P3)begin
        probe_strobe[1] <= 1;
        probe_data_address[1] <= data_address[3];
        invalidate[1] <= 0;
    end
    else begin
        probe_strobe[1] <= 0;
        probe_data_address[1] <= 0;
        invalidate[1] <= 0;
    end
end

// Data[2] and request_data_ready[2]
always@(posedge clk_i)begin
    if(rst_i)begin
        Data[2] <= 0;
        request_data_ready[2] <= 0;
        make_exclusive_L1[2] <= 0;
    end
    else if(S == S_write_miss_P2 || S == S_read_miss_P2)begin
        if(response_data_ready[0]) begin
            Data[2] <= response_data[0];
            request_data_ready[2] <= 1;
        end
        else if(response_data_ready[1])begin
            Data[2] <= response_data[1];
            request_data_ready[2] <= 1;
        end
        else if(response_data_ready[3])begin
            Data[2] <= response_data[3];
            request_data_ready[2] <= 1;
        end
        else if(response_ready_L2) begin
            Data[2] <= response_data_L2;
            request_data_ready[2] <= 1;
            make_exclusive_L1[2] <= make_L1_exclusive_L2;
        end
    end
    else if(S == S_replacement_P2)begin
        if(response_ready_L2) begin
            request_data_ready[2] <= 1;
        end
        else begin
            request_data_ready[2] <= 0;
        end
    end
    else if(S_next == S_invalidate_P2) begin
        request_data_ready[2] <= 1;
    end
    else begin
        Data[2] <= 0;
        request_data_ready[2] <= 0;
        make_exclusive_L1[2] <= 0;
    end
end

//  probe_strobe[2], probe_data_address[2], invalidate[2], 
always@(posedge clk_i)begin
    if(rst_i)begin
        probe_strobe[2] <= 0;
        probe_data_address[2] <= 0;
        invalidate[2] <= 0;
    end
    else if(S == S_invalidate_P0 || S == S_invalidate_P1 || S == S_invalidate_P3 || S == S_invalidate_L2)begin
        probe_strobe[2] <= 1;
        probe_data_address[2] <= invalidate_address_r;
        invalidate[2] <= 1;
    end
    else if(request_to_L2) begin
        probe_strobe[2] <= 0;
        probe_data_address[2] <= 0;
        invalidate[2] <= 0;
    end
    else if(S == S_write_miss_P0 && S_next == S_write_miss_P0)begin
        probe_strobe[2] <= 1;
        probe_data_address[2] <= data_address[0];
        invalidate[2] <= 1;
    end
    else if(S == S_read_miss_P0 && S_next == S_read_miss_P0)begin
        probe_strobe[2] <= 1;
        probe_data_address[2] <= data_address[0];
        invalidate[2] <= 0;
    end
    else if(S == S_write_miss_P1 && S_next == S_write_miss_P1)begin
        probe_strobe[2] <= 1;
        probe_data_address[2] <= data_address[1];
        invalidate[2] <= 1;
    end
    else if(S == S_read_miss_P1 && S_next == S_read_miss_P1)begin
        probe_strobe[2] <= 1;
        probe_data_address[2] <= data_address[1];
        invalidate[2] <= 0;
    end
    else if(S == S_write_miss_P3 && S_next == S_write_miss_P3)begin
        probe_strobe[2] <= 1;
        probe_data_address[2] <= data_address[3];
        invalidate[2] <= 1;
    end
    else if(S == S_read_miss_P3 && S_next == S_read_miss_P3)begin
        probe_strobe[2] <= 1;
        probe_data_address[2] <= data_address[3];
        invalidate[2] <= 0;
    end
    else begin
        probe_strobe[2] <= 0;
        probe_data_address[2] <= 0;
        invalidate[2] <= 0;
    end
end


// Data[3] and request_data_ready[3]
always@(posedge clk_i)begin
    if(rst_i)begin
        Data[3] <= 0;
        request_data_ready[3] <= 0;
        make_exclusive_L1[3] <= 0;
    end
    else if(S == S_write_miss_P3 || S == S_read_miss_P3)begin
        if(response_data_ready[0]) begin
            Data[3] <= response_data[0];
            request_data_ready[3] <= 1;
        end
        else if(response_data_ready[1])begin
            Data[3] <= response_data[1];
            request_data_ready[3] <= 1;
        end
        else if(response_data_ready[2])begin
            Data[3] <= response_data[2];
            request_data_ready[3] <= 1;
        end
        else if(response_ready_L2) begin
            Data[3] <= response_data_L2;
            request_data_ready[3] <= 1;
            make_exclusive_L1[3] <= make_L1_exclusive_L2;
        end
    end
    else if(S == S_replacement_P3)begin
        if(response_ready_L2) begin
            request_data_ready[3] <= 1;
        end
        else begin
            request_data_ready[3] <= 0;
        end
    end
    else if(S_next == S_invalidate_P3) begin
        request_data_ready[3] <= 1;
    end
    else begin
        Data[3] <= 0;
        request_data_ready[3] <= 0;
        make_exclusive_L1[3] <= 0;
    end
end

//  probe_strobe[3], probe_data_address[3], invalidate[3], 
always@(posedge clk_i)begin
    if(rst_i)begin
        probe_strobe[3] <= 0;
        probe_data_address[3] <= 0;
        invalidate[3] <= 0;
    end
    else if(S == S_invalidate_P0 || S == S_invalidate_P1 || S == S_invalidate_P2 || S == S_invalidate_L2)begin
        probe_strobe[3] <= 1;
        probe_data_address[3] <= invalidate_address_r;
        invalidate[3] <= 1;
    end
    else if(request_to_L2) begin
        probe_strobe[3] <= 0;
        probe_data_address[3] <= 0;
        invalidate[3] <= 0;
    end
    else if(S == S_write_miss_P0 && S_next == S_write_miss_P0)begin
        probe_strobe[3] <= 1;
        probe_data_address[3] <= data_address[0];
        invalidate[3] <= 1;
    end
    else if(S == S_read_miss_P0 && S_next == S_read_miss_P0)begin
        probe_strobe[3] <= 1;
        probe_data_address[3] <= data_address[0];
        invalidate[3] <= 0;
    end
    else if(S == S_write_miss_P1 && S_next == S_write_miss_P1)begin
        probe_strobe[3] <= 1;
        probe_data_address[3] <= data_address[1];
        invalidate[3] <= 1;
    end
    else if(S == S_read_miss_P1 && S_next == S_read_miss_P1)begin
        probe_strobe[3] <= 1;
        probe_data_address[3] <= data_address[1];
        invalidate[3] <= 0;
    end
    else if(S == S_write_miss_P2 && S_next == S_write_miss_P2)begin
        probe_strobe[3] <= 1;
        probe_data_address[3] <= data_address[2];
        invalidate[3] <= 1;
    end
    else if(S == S_read_miss_P2 && S_next == S_read_miss_P2)begin
        probe_strobe[3] <= 1;
        probe_data_address[3] <= data_address[2];
        invalidate[3] <= 0;
    end
    else begin
        probe_strobe[3] <= 0;
        probe_data_address[3] <= 0;
        invalidate[3] <= 0;
    end
end


// write_to_L2, data_to_L2, write_data_address_L2
always@(posedge clk_i)begin
    if(rst_i)begin
        write_to_L2 <= 0;
        data_to_L2 <= 0;
        replacement_L2 <= 0;
        write_data_address_L2 <= 0;
    end
    else if(!response_ready_L2 && (S == S_replacement_P0 || S == S_replacement_P1 || S == S_replacement_P2 || S == S_replacement_P3))begin
        write_to_L2 <= 1;
        write_data_address_L2 <= wb_addr_r;
        data_to_L2 <= wb_data_r;
        replacement_L2 <= 1;
    end
    else if(!response_ready_L2 &&S == S_WB_L2)begin
        write_to_L2 <= 1;
        write_data_address_L2 <= wb_addr_r;
        data_to_L2 <= wb_data_r;
        replacement_L2 <= 0;
    end
    else begin
        write_to_L2 <= 0;
        write_data_address_L2 <= 0;
        data_to_L2 <= 0;
        replacement_L2 <= 0;
    end
end


always @(posedge clk_i) begin
    if(rst_i) begin
        request_L2_decision <= 0;
    end
    else if(request_L2_decision == 2) begin
        if(S_next == S_WB_L2 || S_next == S_IDLE) request_L2_decision <= 0;
        else request_L2_decision <= request_L2_decision;
    end
    else if(S == S_read_miss_P0 || S == S_write_miss_P0
            || S == S_read_miss_P1 || S == S_write_miss_P1
            || S == S_read_miss_P2 || S == S_write_miss_P2
            || S == S_read_miss_P3 || S == S_write_miss_P3) begin
        request_L2_decision <= request_L2_decision + 1;
    end
    else begin
        request_L2_decision <= 0;
    end
end

assign request_to_L2 = (request_L2_decision == 2 && S_next != S_WB_L2 && S_next != S_IDLE && !response_ready_L2);

// probe_strobe_L2, probe_data_address_L2, L1_iswrite_L2,
reg [XLEN-1 : 0 ]  probe_data_address_L2;
always@(posedge clk_i)begin
    if(rst_i)begin
        probe_strobe_L2 <= 0;
        probe_data_address_L2 <= 0;
        L1_iswrite_L2 <= 0; 
        L1_is_instr_fetch_L2 <= 0;
    end
    else if(request_to_L2) begin
        if(S == S_read_miss_P0)begin
        probe_strobe_L2 <= 1;
        probe_data_address_L2 <= data_address[0];
        L1_iswrite_L2 <= 0; 
        L1_is_instr_fetch_L2 <= L1_is_instr_fetch[0];
        end
        else if(S == S_write_miss_P0)begin
            probe_strobe_L2 <= 1;
            probe_data_address_L2 <= data_address[0];
            L1_iswrite_L2 <= 1; 
            L1_is_instr_fetch_L2 <= 0;
        end

        else if(S == S_read_miss_P1)begin
            probe_strobe_L2 <= 1;
            probe_data_address_L2 <= data_address[1];
            L1_iswrite_L2 <= 0; 
            L1_is_instr_fetch_L2 <= L1_is_instr_fetch[1];
        end
        else if(S == S_write_miss_P1)begin
            probe_strobe_L2 <= 1;
            probe_data_address_L2 <= data_address[1];
            L1_iswrite_L2 <= 1; 
            L1_is_instr_fetch_L2 <= 0;
        end
        else if(S == S_read_miss_P2)begin
            probe_strobe_L2 <= 1;
            probe_data_address_L2 <= data_address[2];
            L1_iswrite_L2 <= 0;
            L1_is_instr_fetch_L2 <= L1_is_instr_fetch[2];
        end
        else if(S == S_write_miss_P2)begin
            probe_strobe_L2 <= 1;
            probe_data_address_L2 <= data_address[2];
            L1_iswrite_L2 <= 1;
            L1_is_instr_fetch_L2 <= 0;
        end
        else if(S == S_read_miss_P3)begin
            probe_strobe_L2 <= 1;
            probe_data_address_L2 <= data_address[3];
            L1_iswrite_L2 <= 0;
            L1_is_instr_fetch_L2 <= L1_is_instr_fetch[3];
        end
        else if(S == S_write_miss_P3)begin
            probe_strobe_L2 <= 1;
            probe_data_address_L2 <= data_address[3];
            L1_iswrite_L2 <= 1;
            L1_is_instr_fetch_L2 <= 0;
        end
    end
    else begin
        probe_strobe_L2 <= 0;
        probe_data_address_L2 <= 0;
        L1_iswrite_L2 <= 0;
        L1_is_instr_fetch_L2 <= 0;
    end
end

//invalidate_address_L2, invalidate_L2

always@(posedge clk_i)begin
    if(rst_i)begin
        invalidate_address_L2 <= 0;
        invalidate_L2 <= 0;
    end
    else if(S == S_invalidate_P0 || S == S_invalidate_P1 || S == S_invalidate_P2 || S == S_invalidate_P3)begin
        invalidate_address_L2 <= invalidate_address_r;
        invalidate_L2 <= 1;
    end
    else begin
        invalidate_address_L2 <= 0;
        invalidate_L2 <= 0;
    end
end

// address to L2 multiplexer
always@(*)begin
    if(invalidate_L2) begin
        address_to_L2 = invalidate_address_L2;
    end
    else if(probe_strobe_L2) begin
        address_to_L2 = probe_data_address_L2;
    end
    else if(write_to_L2) begin
        address_to_L2 = write_data_address_L2;
    end
    else begin
        address_to_L2 = 0;
    end
end

assign CU_L2_ready_o = S == S_invalidate_L2;

endmodule
