`timescale 1ns / 1ps
// =============================================================================
//  Program : device_arbiter_new.v
// =============================================================================
`include "aquila_config.vh"

module device_arbiter #(parameter XLEN = 32, parameter CORE_NUMS = `CORE_NUMS,parameter CORE_NUMS_BITS =2)
(
    // System signals
    input                       clk_i, rst_i,
    //===================== CORE 0-3 =====================//
    input                       P_DEVICE_strobe_i[0 : CORE_NUMS-1],
    input [XLEN-1 : 0]          P_DEVICE_addr_i[0 : CORE_NUMS-1],
    input                       P_DEVICE_rw_i[0 : CORE_NUMS-1],
    input [XLEN/8-1 : 0]        P_DEVICE_byte_enable_i[0 : CORE_NUMS-1],
    input [XLEN-1 : 0]          P_DEVICE_data_i[0 : CORE_NUMS-1],
    output reg                  P_DEVICE_data_ready_o[0 : CORE_NUMS-1],
    output reg [XLEN-1 : 0]     P_DEVICE_data_o[0 : CORE_NUMS-1],

    // Aquila device slave interface
    output                      DEVICE_strobe_o,
    output [XLEN-1 : 0]         DEVICE_addr_o,
    output                      DEVICE_rw_o,
    output [XLEN/8-1 : 0]       DEVICE_byte_enable_o,
    output [XLEN-1 : 0]         DEVICE_data_o,
    input                       DEVICE_data_ready_i,
    input [XLEN-1 : 0]          DEVICE_data_i,

    output reg [CORE_NUMS_BITS-1:0]            uart_core_sel_o
);

    // Strobe source, have two strobe sources (P0-MEM, P1-MEM) 
    localparam P0_STROBE = 0,
               P1_STROBE = 1,
               P2_STROBE = 2,
               P3_STROBE = 3,
                P4_STROBE = 4,
                P5_STROBE = 5,
                P6_STROBE = 6,
                P7_STROBE = 7,
                P8_STROBE = 8,
                P9_STROBE = 9,
                P10_STROBE = 10,
                P11_STROBE = 11,
                P12_STROBE = 12,
                P13_STROBE = 13,
                P14_STROBE = 14,
                P15_STROBE = 15;

    localparam M_IDLE   = 0, // wait for strobe
               M_CHOOSE = 1, // choose 
               M_WAIT   = 2; // wait for device ready for request

    // input selection signals
    wire                     concurrent_strobe;
    reg  [CORE_NUMS_BITS-1:0]               sel_current;
    reg                      sel_previous;
 
    reg                      DEVICE_strobe_r;
    reg  [XLEN-1 : 0]        DEVICE_addr_r;
    reg                      DEVICE_rw_r;
    reg  [XLEN/8-1 : 0]      DEVICE_byte_enable_r;
    reg  [XLEN-1 : 0]        DEVICE_data_r;

    // Keep the strobe
    reg                      P_DEVICE_strobe_r[0 : CORE_NUMS-1];
    reg  [XLEN-1 : 0]        P_DEVICE_addr_r[0 : CORE_NUMS-1];
    reg                      P_DEVICE_rw_r[0 : CORE_NUMS-1];
    reg  [XLEN/8-1 : 0]      P_DEVICE_byte_enable_r[0 : CORE_NUMS-1];
    reg  [XLEN-1 : 0]        P_DEVICE_data_r[0 : CORE_NUMS-1];

    
    // FSM signals
    reg  [2 : 0]             c_state;
    reg  [1 : 0]             n_state;
    wire                     have_strobe;
    integer i;
    //=======================================================
    //  Keep the strobe (in case we miss strobe)
    //=======================================================
    // P0-DEVICE slave interface
    always @(posedge clk_i) begin
        if (rst_i) begin
            for(i = 0; i < `CORE_NUMS; i = i + 1) begin
                P_DEVICE_strobe_r[i] <= 0;
            end
        end 
        else begin
             for(i = 0; i < `CORE_NUMS; i = i + 1) begin
                if(P_DEVICE_strobe_i[i]) begin
                    P_DEVICE_strobe_r[i] <= 1;
                end
                else if(P_DEVICE_data_ready_o[i]) begin
                    P_DEVICE_strobe_r[i] <= 0; // Clear the strobe
                end
            end
        end
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            for(i = 0; i < `CORE_NUMS; i = i + 1) begin
                P_DEVICE_addr_r[i] <= 0;
                P_DEVICE_rw_r[i] <= 0;
                P_DEVICE_byte_enable_r[i] <= 0;
                P_DEVICE_data_r[i] <= 0;
            end
        end 
        else begin
             for(i = 0; i < `CORE_NUMS; i = i + 1) begin
                if(P_DEVICE_strobe_i[i]) begin
                    P_DEVICE_addr_r[i] <= P_DEVICE_addr_i[i];
                    P_DEVICE_rw_r[i] <= P_DEVICE_rw_i[i];
                    P_DEVICE_byte_enable_r[i] <= P_DEVICE_byte_enable_i[i];
                    P_DEVICE_data_r[i] <= P_DEVICE_data_i[i];
                end
            end
        end
    end

    // // P1-DEVICE slave interface
    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_DEVICE_strobe_r[1] <= 0;
    //     else if (P_DEVICE_strobe_i[1])
    //         P_DEVICE_strobe_r[1] <= 1;
    //     else if (P_DEVICE_data_ready_o[1])
    //         P_DEVICE_strobe_r[1] <= 0; // Clear the strobe
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i) begin
    //         P_DEVICE_addr_r[1] <= 0;
    //         P_DEVICE_rw_r[1] <= 0;
    //         P_DEVICE_byte_enable_r[1] <= 0;
    //         P_DEVICE_data_r[1] <= 0;
    //     end else if (P_DEVICE_strobe_i[1]) begin
    //         P_DEVICE_addr_r[1] <= P_DEVICE_addr_i[1];
    //         P_DEVICE_rw_r[1] <= P_DEVICE_rw_i[1];
    //         P_DEVICE_byte_enable_r[1] <= P_DEVICE_byte_enable_i[1];
    //         P_DEVICE_data_r[1] <= P_DEVICE_data_i[1];
    //     end
    // end


    // // P2-DEVICE slave interface
    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_DEVICE_strobe_r[2] <= 0;
    //     else if (P_DEVICE_strobe_i[2])
    //         P_DEVICE_strobe_r[2] <= 1;
    //     else if (P_DEVICE_data_ready_o[2])
    //         P_DEVICE_strobe_r[2] <= 0; // Clear the strobe
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i) begin
    //         P_DEVICE_addr_r[2] <= 0;
    //         P_DEVICE_rw_r[2] <= 0;
    //         P_DEVICE_byte_enable_r[2] <= 0;
    //         P_DEVICE_data_r[2] <= 0;
    //     end else if (P_DEVICE_strobe_i[2]) begin
    //         P_DEVICE_addr_r[2] <= P_DEVICE_addr_i[2];
    //         P_DEVICE_rw_r[2] <= P_DEVICE_rw_i[2];
    //         P_DEVICE_byte_enable_r[2] <= P_DEVICE_byte_enable_i[2];
    //         P_DEVICE_data_r[2] <= P_DEVICE_data_i[2];
    //     end
    // end


    // // P3-DEVICE slave interface
    // always @(posedge clk_i) begin
    //     if (rst_i)
    //         P_DEVICE_strobe_r[3] <= 0;
    //     else if (P_DEVICE_strobe_i[3])
    //         P_DEVICE_strobe_r[3] <= 1;
    //     else if (P_DEVICE_data_ready_o[3])
    //         P_DEVICE_strobe_r[3] <= 0; // Clear the strobe
    // end

    // always @(posedge clk_i) begin
    //     if (rst_i) begin
    //         P_DEVICE_addr_r[3] <= 0;
    //         P_DEVICE_rw_r[3] <= 0;
    //         P_DEVICE_byte_enable_r[3] <= 0;
    //         P_DEVICE_data_r[3] <= 0;
    //     end else if (P_DEVICE_strobe_i[3]) begin
    //         P_DEVICE_addr_r[3] <= P_DEVICE_addr_i[3];
    //         P_DEVICE_rw_r[3] <= P_DEVICE_rw_i[3];
    //         P_DEVICE_byte_enable_r[3] <= P_DEVICE_byte_enable_i[3];
    //         P_DEVICE_data_r[3] <= P_DEVICE_data_i[3];
    //     end
    // end


    //=======================================================
    //  Strobe signals selection (Round Robin) 
    //=======================================================

    // assign concurrent_strobe = P_DEVICE_strobe_r[0] & P_DEVICE_strobe_r[1] & P_DEVICE_strobe_r[2] & P_DEVICE_strobe_r[3];

    // always @(posedge clk_i) begin
    //     if (rst_i) 
    //         sel_previous <= 0;
    //     else if (c_state == M_CHOOSE)
    //         sel_previous <= sel_current;
    // end
`ifdef CORE_NUMS_2
    always @(posedge clk_i) begin
        if (rst_i) 
            sel_current <= 0;
        else if(c_state == M_IDLE)begin
            if(P_DEVICE_strobe_r[0]) begin
                sel_current <= P0_STROBE;
                if(P_DEVICE_addr_r[0][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 0;
            end
            else if(P_DEVICE_strobe_r[1]) begin
                sel_current <= P1_STROBE;
                if(P_DEVICE_addr_r[1][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 1;
            end
        end
    end
`elsif CORE_NUMS_4
    always @(posedge clk_i) begin
        if (rst_i)  begin
            sel_current <= 0;
            uart_core_sel_o <= 0;
        end
        else if(c_state == M_IDLE)begin
            if(P_DEVICE_strobe_r[0]) begin
                sel_current <= P0_STROBE;
                if(P_DEVICE_addr_r[0][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 0;
            end
            else if(P_DEVICE_strobe_r[1]) begin
                sel_current <= P1_STROBE;
                if(P_DEVICE_addr_r[1][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 1;
            end
            else if(P_DEVICE_strobe_r[2]) begin
                sel_current <= P2_STROBE;
                if(P_DEVICE_addr_r[2][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 2;
            end
            else if(P_DEVICE_strobe_r[3]) begin
                sel_current <= P3_STROBE;
                if(P_DEVICE_addr_r[3][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 3;
            end
        end
    end
`elsif CORE_NUMS_8 // CORE_NUMS_8
    always @(posedge clk_i) begin
        if (rst_i)  begin
            sel_current <= 0;
            uart_core_sel_o <= 0;
        end
        else if(c_state == M_IDLE)begin
            if(P_DEVICE_strobe_r[0]) begin
                sel_current <= P0_STROBE;
                if(P_DEVICE_addr_r[0][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 0;
            end
            else if(P_DEVICE_strobe_r[1]) begin
                sel_current <= P1_STROBE;
                if(P_DEVICE_addr_r[1][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 1;
            end
            else if(P_DEVICE_strobe_r[2]) begin
                sel_current <= P2_STROBE;
                if(P_DEVICE_addr_r[2][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 2;
            end
            else if(P_DEVICE_strobe_r[3]) begin
                sel_current <= P3_STROBE;
                if(P_DEVICE_addr_r[3][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 3;
            end
            else if(P_DEVICE_strobe_r[4]) begin
                sel_current <= P4_STROBE;
                if(P_DEVICE_addr_r[4][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 4;
            end
            else if(P_DEVICE_strobe_r[5]) begin
                sel_current <= P5_STROBE;
                if(P_DEVICE_addr_r[5][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 5;
            end
            else if(P_DEVICE_strobe_r[6]) begin
                sel_current <= P6_STROBE;
                if(P_DEVICE_addr_r[6][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 6;
            end
            else if(P_DEVICE_strobe_r[7]) begin
                sel_current <= P7_STROBE;
                if(P_DEVICE_addr_r[7][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 7;
            end
        end
    end
`else
    always @(posedge clk_i) begin
        if (rst_i)  begin
            sel_current <= 0;
            uart_core_sel_o <= 0;
        end
        else if(c_state == M_IDLE)begin
            if(P_DEVICE_strobe_r[0]) begin
                sel_current <= P0_STROBE;
                if(P_DEVICE_addr_r[0][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 0;
            end
            else if(P_DEVICE_strobe_r[1]) begin
                sel_current <= P1_STROBE;
                if(P_DEVICE_addr_r[1][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 1;
            end
            else if(P_DEVICE_strobe_r[2]) begin
                sel_current <= P2_STROBE;
                if(P_DEVICE_addr_r[2][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 2;
            end
            else if(P_DEVICE_strobe_r[3]) begin
                sel_current <= P3_STROBE;
                if(P_DEVICE_addr_r[3][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 3;
            end
            else if(P_DEVICE_strobe_r[4]) begin
                sel_current <= P4_STROBE;
                if(P_DEVICE_addr_r[4][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 4;
            end
            else if(P_DEVICE_strobe_r[5]) begin
                sel_current <= P5_STROBE;
                if(P_DEVICE_addr_r[5][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 5;
            end
            else if(P_DEVICE_strobe_r[6]) begin
                sel_current <= P6_STROBE;
                if(P_DEVICE_addr_r[6][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 6;
            end
            else if(P_DEVICE_strobe_r[7]) begin
                sel_current <= P7_STROBE;
                if(P_DEVICE_addr_r[7][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 7;
            end
            else if(P_DEVICE_strobe_r[8]) begin
                sel_current <= P8_STROBE;
                if(P_DEVICE_addr_r[8][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 8;
            end
            else if(P_DEVICE_strobe_r[9]) begin
                sel_current <= P9_STROBE;
                if(P_DEVICE_addr_r[9][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 9;
            end
            else if(P_DEVICE_strobe_r[10]) begin
                sel_current <= P10_STROBE;
                if(P_DEVICE_addr_r[10][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 10;
            end
            else if(P_DEVICE_strobe_r[11]) begin
                sel_current <= P11_STROBE;
                if(P_DEVICE_addr_r[11][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 11;
            end
            else if(P_DEVICE_strobe_r[12]) begin
                sel_current <= P12_STROBE;
                if(P_DEVICE_addr_r[12][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 12;
            end
            else if(P_DEVICE_strobe_r[13]) begin
                sel_current <= P13_STROBE;
                if(P_DEVICE_addr_r[13][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 13;
            end
            else if(P_DEVICE_strobe_r[14]) begin
                sel_current <= P14_STROBE;
                if(P_DEVICE_addr_r[14][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 14;
            end
            else if(P_DEVICE_strobe_r[15]) begin
                sel_current <= P15_STROBE;
                if(P_DEVICE_addr_r[15][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 15;
            end
        end
    end
`endif
    /* Record selected singnals*/
    always @(posedge clk_i) begin
        if (rst_i) 
            DEVICE_strobe_r <= 0;
        else if(c_state == M_CHOOSE) 
            DEVICE_strobe_r <= 1;
        else    
            DEVICE_strobe_r <= 0;
    end
    
    always @(posedge clk_i) begin
        if (rst_i) begin
            DEVICE_addr_r <= 0;
            DEVICE_rw_r <= 0;
            DEVICE_byte_enable_r <= 0;
            DEVICE_data_r <= 0;
        end 
        else begin
            DEVICE_addr_r <= P_DEVICE_addr_r[sel_current];
            DEVICE_rw_r <= P_DEVICE_rw_r[sel_current];
            DEVICE_byte_enable_r <= P_DEVICE_byte_enable_r[sel_current];
            DEVICE_data_r <= P_DEVICE_data_r[sel_current];
        end
    end


    //=======================================================
    //  Output logic
    //=======================================================
    always @(*) begin
        for(i = 0; i < `CORE_NUMS; i = i + 1) begin
            P_DEVICE_data_ready_o[i] = (sel_current == i && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
            P_DEVICE_data_o[i] = DEVICE_data_i;
        end
    end
    // assign P_DEVICE_data_ready_o[0] = (sel_current == P0_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    // assign P_DEVICE_data_o[0]       = DEVICE_data_i;

    // assign P_DEVICE_data_ready_o[1] = (sel_current == P1_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    // assign P_DEVICE_data_o[1]       = DEVICE_data_i;

    // assign P_DEVICE_data_ready_o[2] = (sel_current == P2_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    // assign P_DEVICE_data_o[2]       = DEVICE_data_i;

    // assign P_DEVICE_data_ready_o[3] = (sel_current == P3_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    // assign P_DEVICE_data_o[3]       = DEVICE_data_i;
    
    assign DEVICE_strobe_o        = DEVICE_strobe_r;
    assign DEVICE_addr_o          = DEVICE_addr_r;
    assign DEVICE_rw_o            = DEVICE_rw_r;
    assign DEVICE_byte_enable_o   = DEVICE_byte_enable_r;
    assign DEVICE_data_o          = DEVICE_data_r;


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
                    n_state = M_CHOOSE;
                else 
                    n_state = M_IDLE;
            M_CHOOSE:
                n_state = M_WAIT;
            M_WAIT:
                if(DEVICE_data_ready_i)
                    n_state = M_IDLE;
                else
                    n_state = M_WAIT;
        endcase
    end
`ifdef CORE_NUMS_2
    assign have_strobe = P_DEVICE_strobe_r[0] | P_DEVICE_strobe_r[1];
`elsif CORE_NUMS_4
    assign have_strobe = P_DEVICE_strobe_r[0] | P_DEVICE_strobe_r[1] | P_DEVICE_strobe_r[2] | P_DEVICE_strobe_r[3];
`elsif CORE_NUMS_8 // CORE_NUMS_8
    assign have_strobe = P_DEVICE_strobe_r[0] | P_DEVICE_strobe_r[1] | P_DEVICE_strobe_r[2] | P_DEVICE_strobe_r[3] |
                         P_DEVICE_strobe_r[4] | P_DEVICE_strobe_r[5] | P_DEVICE_strobe_r[6] | P_DEVICE_strobe_r[7];
`else
    assign have_strobe = P_DEVICE_strobe_r[0] | P_DEVICE_strobe_r[1] | P_DEVICE_strobe_r[2] | P_DEVICE_strobe_r[3] |
                         P_DEVICE_strobe_r[4] | P_DEVICE_strobe_r[5] | P_DEVICE_strobe_r[6] | P_DEVICE_strobe_r[7] |
                         P_DEVICE_strobe_r[8] | P_DEVICE_strobe_r[9] | P_DEVICE_strobe_r[10] | P_DEVICE_strobe_r[11] |
                         P_DEVICE_strobe_r[12] | P_DEVICE_strobe_r[13] | P_DEVICE_strobe_r[14] | P_DEVICE_strobe_r[15];
`endif
endmodule
