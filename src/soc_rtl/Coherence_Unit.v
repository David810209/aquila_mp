`timescale 1ns / 1ps
`include "aquila_config.vh"

module coherence_unit #(parameter XLEN = 32, parameter CLSIZE = 128, parameter CORE_NUMS =`CORE_NUMS, parameter CORE_NUMS_BITS = 2)(
    //===================== System signals =====================//
    input                     clk_i,
    input                     rst_i,
    //===================== CORE 0-3 =====================//
    // request Data
    input                     broadcast_strobe[0 : CORE_NUMS-1],
    input                     read_write[0 : CORE_NUMS-1],
    input  [XLEN-1 : 0]       data_address[0 : CORE_NUMS-1],
    input                     share_modify[0 : CORE_NUMS-1],
    output reg [CLSIZE-1 :0]  Data[0 : CORE_NUMS-1],
    output reg                request_data_ready[0 : CORE_NUMS-1],
    input                     replacement[0 : CORE_NUMS-1],
    input                     L1_is_instr_fetch[0 : CORE_NUMS-1],
    // response Data
    output reg                probe_strobe[0 : CORE_NUMS-1],
    output reg [XLEN-1 : 0]   probe_data_address[0 : CORE_NUMS-1],
    output reg                invalidate[0 : CORE_NUMS-1],
    input  [CLSIZE-1 : 0]     response_data[0 : CORE_NUMS-1],
    input  [CLSIZE-1 : 0]     write_back_data[0 : CORE_NUMS-1],
    input                     response_data_ready[0 : CORE_NUMS-1],
    output reg                make_exclusive_L1[0 : CORE_NUMS-1],
    //===================== L2 cache =====================//
    //write back to L2
    output reg                write_to_L2,
    output reg [CLSIZE-1 : 0] data_to_L2,
    output reg                replacement_L2,
    //request L2 Data
    output reg                probe_strobe_L2,
    output reg [XLEN-1 : 0]   address_to_L2,
    output reg                L1_iswrite_L2,
    input  [CLSIZE-1 : 0]     response_data_L2,
    input                     response_ready_L2,
    input                     make_L1_exclusive_L2,
    output reg                L1_is_instr_fetch_L2,
    // Invalidate L2 Data
    output reg                invalidate_L2,

    //L2 invalidate L1 signal
    output  reg               CU_L2_ready_o,             // CU is ready  
    input      [XLEN-1 : 0]   L2_invalidate_L1_addr_i,   // invalidate L1 address
    input                     L2_invalidate_L1_i,        // invalidate L1 signal
    // Atomic 
    input                     P_amo_strobe,
    input  [CORE_NUMS_BITS-1:0]              AMO_id,
    input                     other_amo_done[0 : CORE_NUMS-1],
    output                    CU_L1_other_amo_o[0 : CORE_NUMS-1]
    
);

reg [CORE_NUMS_BITS-1:0]    current_wb_core_id;
reg [CORE_NUMS_BITS-1:0]    current_invalidate_core_id;
reg [CORE_NUMS_BITS-1:0]    current_rw_core_id;

integer                     i;
genvar                      idx;
wire                        have_wb, have_invalidate, have_rw;
wire                        any_wb          [0 : CORE_NUMS-1];
wire                        any_invalidate  [0 : CORE_NUMS-1];
wire                        any_rw          [0 : CORE_NUMS-1];
wire                        any_response    [0 : CORE_NUMS-1];
wire                        L1_has_response;
wire [CORE_NUMS_BITS-1:0]   L1_response_core_id;
reg [XLEN-1 : 0]            wb_addr_r;
reg [CLSIZE - 1 :0]         wb_data_r;

reg [3:0]                   S, S_next;

localparam S_Idle              = 4'd0;
localparam S_Miss              = 4'd1; // rw miss
localparam S_Invalidate        = 4'd2; // write hit on Shared state
localparam S_Replacement       = 4'd3; // write back to L2
localparam S_WB_L2             = 4'd4; // write back to L2
localparam S_L2_Invalidate     = 4'd5; // invalidate L2
localparam S_Wait              = 4'd6; // wait for L1 to be ready
localparam S_Wait2             = 4'd7; // wait for L1 to be ready
localparam S_Replacement_Delay = 4'd8; // write back to L2

reg                         amo_S, amo_S_next;
localparam                  amo_S_idle = 0, amo_S_busy = 1;
reg [CORE_NUMS_BITS-1:0]    amo_core_id;

wire [CLSIZE-1 : 0]         response_data_mux;
reg [XLEN-1 : 0]            invalidate_address_L2;
reg [XLEN-1 : 0]            write_data_address_L2;
reg [XLEN-1 : 0 ]           probe_data_address_L2;

always @(posedge clk_i ) begin
    if(rst_i) amo_core_id <= 0;
    else if(P_amo_strobe && amo_S == amo_S_idle) begin
        amo_core_id <= AMO_id;
    end
    else if(amo_S == amo_S_idle) begin
        amo_core_id <= 0;
    end
end

always @(posedge clk_i)
begin
    if(rst_i) amo_S <= amo_S_idle;
    else  amo_S <= amo_S_next;
end

always @(*) begin
    case (amo_S)
        amo_S_idle: amo_S_next = (P_amo_strobe) ? amo_S_busy : amo_S_idle;
        amo_S_busy: amo_S_next = (other_amo_done[amo_core_id]) ? amo_S_idle : amo_S_busy;
        default:  amo_S_next = amo_S_idle;
    endcase
end

generate
    for(idx = 0; idx < CORE_NUMS; idx = idx + 1) begin
        assign CU_L1_other_amo_o[idx] = (amo_S != amo_S_idle && idx != amo_core_id);
        assign any_wb[idx]         = (replacement[idx] && !CU_L1_other_amo_o[idx]);
        assign any_invalidate[idx] = (share_modify[idx] && !CU_L1_other_amo_o[idx]);
        assign any_rw[idx]         = (broadcast_strobe[idx] && !CU_L1_other_amo_o[idx]);
        assign any_response[idx]   = response_data_ready[idx];
    end
endgenerate

`ifdef CORE_NUMS_2
always @(posedge clk_i) begin
    if(rst_i) current_wb_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_wb[0]) current_wb_core_id <= 0;
        else if(any_wb[1]) current_wb_core_id <= 1;
        else current_wb_core_id <= 0;
    end
    else current_wb_core_id <= current_wb_core_id;
end
always @(posedge clk_i) begin
    if(rst_i) current_invalidate_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_invalidate[0]) current_invalidate_core_id <= 0;
        else if(any_invalidate[1]) current_invalidate_core_id <= 1;
        else current_invalidate_core_id <= 0;
    end
    else current_invalidate_core_id <= current_invalidate_core_id;
end
always @(posedge clk_i) begin
    if(rst_i) current_rw_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_rw[0]) current_rw_core_id <= 0;
        else if(any_rw[1]) current_rw_core_id <= 1;
        else current_rw_core_id <= 0;
    end
    else current_rw_core_id <= current_rw_core_id;
end

assign have_wb = any_wb[0] | any_wb[1];
assign have_invalidate = any_invalidate[0] | any_invalidate[1];
assign have_rw =    any_rw[0] | any_rw[1];
assign L1_has_response = any_response[0] | any_response[1];
assign L1_response_core_id = (response_data_ready[0]) ? 0 :
                             (response_data_ready[1]) ? 1 : 0;
`elsif CORE_NUMS_4
always @(posedge clk_i) begin
    if(rst_i) current_wb_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_wb[0]) current_wb_core_id <= 0;
        else if(any_wb[1]) current_wb_core_id <= 1;
        else if(any_wb[2]) current_wb_core_id <= 2;
        else if(any_wb[3]) current_wb_core_id <= 3;
        else current_wb_core_id <= 0;
    end
    else current_wb_core_id <= current_wb_core_id;
end

always @(posedge clk_i) begin
    if(rst_i) current_invalidate_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_invalidate[0]) current_invalidate_core_id <= 0;
        else if(any_invalidate[1]) current_invalidate_core_id <= 1;
        else if(any_invalidate[2]) current_invalidate_core_id <= 2;
        else if(any_invalidate[3]) current_invalidate_core_id <= 3;
        else current_invalidate_core_id <= 0;
    end
    else current_invalidate_core_id <= current_invalidate_core_id;
end

always @(posedge clk_i) begin
    if(rst_i) current_rw_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_rw[0]) current_rw_core_id <= 0;
        else if(any_rw[1]) current_rw_core_id <= 1;
        else if(any_rw[2]) current_rw_core_id <= 2;
        else if(any_rw[3]) current_rw_core_id <= 3;
        else current_rw_core_id <= 0;
    end
    else current_rw_core_id <= current_rw_core_id;
end

assign have_wb = any_wb[0] | any_wb[1] | any_wb[2] | any_wb[3];
assign have_invalidate = any_invalidate[0] | any_invalidate[1] | any_invalidate[2] | any_invalidate[3];
assign have_rw =    any_rw[0] | any_rw[1] | any_rw[2] | any_rw[3];

assign L1_has_response = any_response[0] | any_response[1] | any_response[2] | any_response[3];

assign L1_response_core_id = (response_data_ready[0]) ? 0 :
                             (response_data_ready[1]) ? 1 :
                             (response_data_ready[2]) ? 2 :
                             (response_data_ready[3]) ? 3 : 0;

`else // CORE_NUMS_8
always @(posedge clk_i) begin
    if(rst_i) current_wb_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_wb[0]) current_wb_core_id <= 0;
        else if(any_wb[1]) current_wb_core_id <= 1;
        else if(any_wb[2]) current_wb_core_id <= 2;
        else if(any_wb[3]) current_wb_core_id <= 3;
        else if(any_wb[4]) current_wb_core_id <= 4;
        else if(any_wb[5]) current_wb_core_id <= 5;
        else if(any_wb[6]) current_wb_core_id <= 6;
        else if(any_wb[7]) current_wb_core_id <= 7;
        else current_wb_core_id <= 0;
    end
    else current_wb_core_id <= current_wb_core_id;
end
always @(posedge clk_i) begin
    if(rst_i) current_invalidate_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_invalidate[0]) current_invalidate_core_id <= 0;
        else if(any_invalidate[1]) current_invalidate_core_id <= 1;
        else if(any_invalidate[2]) current_invalidate_core_id <= 2;
        else if(any_invalidate[3]) current_invalidate_core_id <= 3;
        else if(any_invalidate[4]) current_invalidate_core_id <= 4;
        else if(any_invalidate[5]) current_invalidate_core_id <= 5;
        else if(any_invalidate[6]) current_invalidate_core_id <= 6;
        else if(any_invalidate[7]) current_invalidate_core_id <= 7;
        else current_invalidate_core_id <= 0;
    end
    else current_invalidate_core_id <= current_invalidate_core_id;
end
always @(posedge clk_i) begin
    if(rst_i) current_rw_core_id <= 0;
    else if(S == S_Idle) begin
        if(any_rw[0]) current_rw_core_id <= 0;
        else if(any_rw[1]) current_rw_core_id <= 1;
        else if(any_rw[2]) current_rw_core_id <= 2;
        else if(any_rw[3]) current_rw_core_id <= 3;
        else if(any_rw[4]) current_rw_core_id <= 4;
        else if(any_rw[5]) current_rw_core_id <= 5;
        else if(any_rw[6]) current_rw_core_id <= 6;
        else if(any_rw[7]) current_rw_core_id <= 7;
        else current_rw_core_id <= 0;
    end
    else current_rw_core_id <= current_rw_core_id;
end
assign have_wb = any_wb[0] | any_wb[1] | any_wb[2] | any_wb[3] | any_wb[4] | any_wb[5] | any_wb[6] | any_wb[7];
assign have_invalidate = any_invalidate[0] | any_invalidate[1] | any_invalidate[2] | any_invalidate[3] |
                         any_invalidate[4] | any_invalidate[5] | any_invalidate[6] | any_invalidate[7];
assign have_rw =    any_rw[0] | any_rw[1] | any_rw[2] | any_rw[3] | 
                    any_rw[4] | any_rw[5] | any_rw[6] | any_rw[7];
assign L1_has_response = any_response[0] | any_response[1] | any_response[2] | any_response[3] |
                         any_response[4] | any_response[5] | any_response[6] | any_response[7];
assign L1_response_core_id = (response_data_ready[0]) ? 0 :
                             (response_data_ready[1]) ? 1 :
                             (response_data_ready[2]) ? 2 :
                             (response_data_ready[3]) ? 3 :
                             (response_data_ready[4]) ? 4 :
                             (response_data_ready[5]) ? 5 :
                             (response_data_ready[6]) ? 6 :
                             (response_data_ready[7]) ? 7 : 0;
`endif
                        
always @(posedge clk_i)
begin
    if(rst_i) S <= S_Idle;
    else  S <= S_next;
end

always @(*)
begin
    case(S)
        S_Idle: begin
            if(L2_invalidate_L1_i) begin
                S_next = S_L2_Invalidate;
            end
            // write back event
            else  if(have_wb) begin
                S_next = S_Replacement_Delay;
            end
            // invalidate event
            else if(have_invalidate) begin
                S_next = S_Invalidate;
            end
            // memory request event
            else if(have_rw) begin
                S_next = S_Miss;
            end
            else begin
                S_next = S_Idle;
            end
        end
        S_Miss: S_next = S_Wait;
        S_Wait: S_next = S_Wait2;
        S_Wait2:  begin
            if(L1_has_response) begin
                if(read_write[current_rw_core_id]) begin
                    S_next = S_Idle;
                end
                else begin
                    S_next = S_WB_L2;
                end
            end
            else if(response_ready_L2) S_next = S_Idle;
            else S_next = S_Wait2;
        end
        S_Invalidate: S_next = S_Idle;
        S_Replacement_Delay: S_next = S_Replacement;
        S_Replacement: S_next = (response_ready_L2) ? S_Idle : S_Replacement;
        S_WB_L2: S_next = (response_ready_L2) ? S_Idle : S_WB_L2;
        S_L2_Invalidate: S_next = S_Idle;
        default: S_next = S_Idle;
    endcase
end
`ifdef CORE_NUMS_2
assign response_data_mux =  (response_data_ready[0]) ? response_data[0] :
                            (response_data_ready[1]) ? response_data[1] : 0;
`elsif CORE_NUMS_4
assign response_data_mux =  (response_data_ready[0]) ? response_data[0] :
                            (response_data_ready[1]) ? response_data[1] :
                            (response_data_ready[2]) ? response_data[2] :
                            (response_data_ready[3]) ? response_data[3] : 0;
`else
assign response_data_mux =  (response_data_ready[0]) ? response_data[0] :
                            (response_data_ready[1]) ? response_data[1] :
                            (response_data_ready[2]) ? response_data[2] :
                            (response_data_ready[3]) ? response_data[3] : 
                            (response_data_ready[4]) ? response_data[4] :
                            (response_data_ready[5]) ? response_data[5] :
                            (response_data_ready[6]) ? response_data[6] :
                            (response_data_ready[7]) ? response_data[7] : 0;
`endif

always @(posedge clk_i) begin
    if(rst_i) begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            Data[i] <= 0;
            request_data_ready[i] <= 0;
            make_exclusive_L1[i] <= 0;
        end
    end
    else if(S == S_Wait2) begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            if(i == current_rw_core_id) begin
                if(L1_has_response) begin
                    Data[i] <= response_data_mux;
                    request_data_ready[i] <= 1;
                    make_exclusive_L1[i] <= 0;
                end
                else if(response_ready_L2)begin
                    Data[i] <= response_data_L2;
                    request_data_ready[i] <= 1;
                    make_exclusive_L1[i] <= make_L1_exclusive_L2;
                end
                else begin
                    Data[i] <= 0;
                    request_data_ready[i] <= 0;
                    make_exclusive_L1[i] <= 0;
                end
            end
            else begin
                Data[i] <= 0;
                request_data_ready[i] <= 0;
                make_exclusive_L1[i] <= 0;
            end
        end
    end
    else if(S == S_Replacement && response_ready_L2) begin
        for(i = 0;i < CORE_NUMS; i = i + 1) begin
            if(i == current_wb_core_id) begin
                Data[i] <= 0;
                request_data_ready[i] <= 1;
                make_exclusive_L1[i] <= 0;
            end
            else begin
                Data[i] <= 0;
                request_data_ready[i] <= 0;
                make_exclusive_L1[i] <= 0;
            end
        end
    end
    else if(S == S_Invalidate) begin
        for(i = 0;i < CORE_NUMS; i = i + 1) begin
            if(i == current_invalidate_core_id) begin
                Data[i] <= 0;
                request_data_ready[i] <= 1;
                make_exclusive_L1[i] <= 0;
            end
            else begin
                Data[i] <= 0;
                request_data_ready[i] <= 0;
                make_exclusive_L1[i] <= 0;
            end
        end
    end
    else begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            Data[i] <= 0;
            request_data_ready[i] <= 0;
            make_exclusive_L1[i] <= 0;
        end
    end
end

always @(posedge clk_i) begin
    if(rst_i) begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            probe_strobe[i] <= 0;
            probe_data_address[i] <= 0;
            invalidate[i] <= 0;
        end
    end
    else if(S == S_Invalidate) begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            probe_strobe[i] <= i != current_invalidate_core_id;
            probe_data_address[i] <= data_address[current_invalidate_core_id];
            invalidate[i] <= i != current_invalidate_core_id;
        end
    end
    else if(S == S_L2_Invalidate) begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            probe_strobe[i] <= 1;
            probe_data_address[i] <= L2_invalidate_L1_addr_i;
            invalidate[i] <= 1;
        end
    end
    else if(S == S_Miss) begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            probe_strobe[i] <= i != current_rw_core_id;
            probe_data_address[i] <= data_address[current_rw_core_id];
            invalidate[i] <= read_write[current_rw_core_id];
        end
    end
    else begin
        for(i = 0; i < CORE_NUMS; i = i + 1) begin
            probe_strobe[i] <= 0;
            probe_data_address[i] <= 0;
            invalidate[i] <= 0;
        end
    end
end

always@(posedge clk_i) begin
    if(rst_i) begin
        wb_addr_r <= 0;
        wb_data_r <= 0;
    end
    else if(response_ready_L2) begin
        wb_addr_r <= 0;
        wb_data_r <= 0;
    end
    else if(S == S_Wait2 && S_next == S_WB_L2) begin
        wb_addr_r <= data_address[current_rw_core_id];
        wb_data_r <= response_data_mux;
    end
    else if(S == S_Replacement_Delay) begin
        wb_addr_r <= data_address[current_wb_core_id];
        wb_data_r <= write_back_data[current_wb_core_id];
    end
    else begin
        wb_addr_r <= wb_addr_r;
        wb_data_r <= wb_data_r;
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
    else if(S == S_WB_L2 && !response_ready_L2)begin
        write_to_L2 <= 1;
        write_data_address_L2 <= wb_addr_r;
        data_to_L2 <= wb_data_r;
        replacement_L2 <= 0;
    end
    else if(S == S_Replacement && !response_ready_L2)begin
        write_to_L2 <= 1;
        write_data_address_L2 <= wb_addr_r;
        data_to_L2 <= wb_data_r;
        replacement_L2 <= 1;
    end
    else begin
        write_to_L2 <= 0;
        write_data_address_L2 <= 0;
        data_to_L2 <= 0;
        replacement_L2 <= 0;
    end
end
// probe_strobe_L2, probe_data_address_L2, L1_iswrite_L2
always@(posedge clk_i)begin
    if(rst_i)begin
        probe_strobe_L2 <= 0;
        probe_data_address_L2 <= 0;
        L1_iswrite_L2 <= 0; 
        L1_is_instr_fetch_L2 <= 0;
    end
    else if(S == S_Wait2 && !L1_has_response && !response_ready_L2) begin
        probe_strobe_L2 <= 1;
        probe_data_address_L2 <= data_address[current_rw_core_id];
        L1_iswrite_L2 <= read_write[current_rw_core_id];
        L1_is_instr_fetch_L2 <= L1_is_instr_fetch[current_rw_core_id];
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
    else if(S == S_Invalidate)begin
        invalidate_address_L2 <= data_address[current_invalidate_core_id];
        invalidate_L2 <= 1;
    end
    else begin
        invalidate_address_L2 <= 0;
        invalidate_L2 <= 0;
    end
end

// address to L2 multiplexer
always@(*)begin
    if(invalidate_L2)address_to_L2 = invalidate_address_L2;
    else if(probe_strobe_L2) address_to_L2 = probe_data_address_L2;
    else if(write_to_L2) address_to_L2 = write_data_address_L2;
    else  address_to_L2 = 0;
end

assign CU_L2_ready_o = S == S_L2_Invalidate;

endmodule
