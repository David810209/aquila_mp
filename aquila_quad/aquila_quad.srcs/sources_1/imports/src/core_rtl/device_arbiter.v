// =============================================================================
//  Program : device_arbiter_new.v
// =============================================================================
`include "aquila_config.vh"

module device_arbiter #(parameter XLEN = 32, parameter CORE_NUMS_BITS =3)
(
    // System signals
    input                       clk_i, rst_i,
    //===================== CORE 0-3 =====================//
    input                       P_DEVICE_strobe_i[0 : 3],
    input [XLEN-1 : 0]          P_DEVICE_addr_i[0 : 3],
    input                       P_DEVICE_rw_i[0 : 3],
    input [XLEN/8-1 : 0]        P_DEVICE_byte_enable_i[0 : 3],
    input [XLEN-1 : 0]          P_DEVICE_data_i[0 : 3],
    output                      P_DEVICE_data_ready_o[0 : 3],
    output [XLEN-1 : 0]         P_DEVICE_data_o[0 : 3],

    // Aquila device slave interface
    output                      DEVICE_strobe_o,
    output [XLEN-1 : 0]         DEVICE_addr_o,
    output                      DEVICE_rw_o,
    output [XLEN/8-1 : 0]       DEVICE_byte_enable_o,
    output [XLEN-1 : 0]         DEVICE_data_o,
    input                       DEVICE_data_ready_i,
    input [XLEN-1 : 0]          DEVICE_data_i,

    output reg [1:0]            uart_core_sel_o
);

    // Strobe source, have two strobe sources (P0-MEM, P1-MEM) 
    localparam P0_STROBE = 0,
               P1_STROBE = 1,
               P2_STROBE = 2,
               P3_STROBE = 3;

    localparam M_IDLE   = 0, // wait for strobe
               M_CHOOSE = 1, // choose 
               M_WAIT   = 2; // wait for device ready for request

    // input selection signals
    wire                     concurrent_strobe;
    reg  [1:0]               sel_current;
    reg                      sel_previous;
 
    reg                      DEVICE_strobe_r;
    reg  [XLEN-1 : 0]        DEVICE_addr_r;
    reg                      DEVICE_rw_r;
    reg  [XLEN/8-1 : 0]      DEVICE_byte_enable_r;
    reg  [XLEN-1 : 0]        DEVICE_data_r;

    // Keep the strobe
    reg                      P_DEVICE_strobe_r[0 : 3];
    reg  [XLEN-1 : 0]        P_DEVICE_addr_r[0 : 3];
    reg                      P_DEVICE_rw_r[0 : 3];
    reg  [XLEN/8-1 : 0]      P_DEVICE_byte_enable_r[0 : 3];
    reg  [XLEN-1 : 0]        P_DEVICE_data_r[0 : 3];

    
    // FSM signals
    reg  [2 : 0]             c_state;
    reg  [1 : 0]             n_state;
    wire                     have_strobe;
    
    //=======================================================
    //  Keep the strobe (in case we miss strobe)
    //=======================================================
    // P0-DEVICE slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_DEVICE_strobe_r[0] <= 0;
        else if (P_DEVICE_strobe_i[0])
            P_DEVICE_strobe_r[0] <= 1;
        else if (P_DEVICE_data_ready_o[0])
            P_DEVICE_strobe_r[0] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_DEVICE_addr_r[0] <= 0;
            P_DEVICE_rw_r[0] <= 0;
            P_DEVICE_byte_enable_r[0] <= 0;
            P_DEVICE_data_r[0] <= 0;
        end 
        else if (P_DEVICE_strobe_i[0]) begin
            P_DEVICE_addr_r[0] <= P_DEVICE_addr_i[0];
            P_DEVICE_rw_r[0] <= P_DEVICE_rw_i[0];
            P_DEVICE_byte_enable_r[0] <= P_DEVICE_byte_enable_i[0];
            P_DEVICE_data_r[0] <= P_DEVICE_data_i[0];
        end
    end


    // P1-DEVICE slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_DEVICE_strobe_r[1] <= 0;
        else if (P_DEVICE_strobe_i[1])
            P_DEVICE_strobe_r[1] <= 1;
        else if (P_DEVICE_data_ready_o[1])
            P_DEVICE_strobe_r[1] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_DEVICE_addr_r[1] <= 0;
            P_DEVICE_rw_r[1] <= 0;
            P_DEVICE_byte_enable_r[1] <= 0;
            P_DEVICE_data_r[1] <= 0;
        end else if (P_DEVICE_strobe_i[1]) begin
            P_DEVICE_addr_r[1] <= P_DEVICE_addr_i[1];
            P_DEVICE_rw_r[1] <= P_DEVICE_rw_i[1];
            P_DEVICE_byte_enable_r[1] <= P_DEVICE_byte_enable_i[1];
            P_DEVICE_data_r[1] <= P_DEVICE_data_i[1];
        end
    end


    // P2-DEVICE slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_DEVICE_strobe_r[2] <= 0;
        else if (P_DEVICE_strobe_i[2])
            P_DEVICE_strobe_r[2] <= 1;
        else if (P_DEVICE_data_ready_o[2])
            P_DEVICE_strobe_r[2] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_DEVICE_addr_r[2] <= 0;
            P_DEVICE_rw_r[2] <= 0;
            P_DEVICE_byte_enable_r[2] <= 0;
            P_DEVICE_data_r[2] <= 0;
        end else if (P_DEVICE_strobe_i[2]) begin
            P_DEVICE_addr_r[2] <= P_DEVICE_addr_i[2];
            P_DEVICE_rw_r[2] <= P_DEVICE_rw_i[2];
            P_DEVICE_byte_enable_r[2] <= P_DEVICE_byte_enable_i[2];
            P_DEVICE_data_r[2] <= P_DEVICE_data_i[2];
        end
    end


    // P3-DEVICE slave interface
    always @(posedge clk_i) begin
        if (rst_i)
            P_DEVICE_strobe_r[3] <= 0;
        else if (P_DEVICE_strobe_i[3])
            P_DEVICE_strobe_r[3] <= 1;
        else if (P_DEVICE_data_ready_o[3])
            P_DEVICE_strobe_r[3] <= 0; // Clear the strobe
    end

    always @(posedge clk_i) begin
        if (rst_i) begin
            P_DEVICE_addr_r[3] <= 0;
            P_DEVICE_rw_r[3] <= 0;
            P_DEVICE_byte_enable_r[3] <= 0;
            P_DEVICE_data_r[3] <= 0;
        end else if (P_DEVICE_strobe_i[3]) begin
            P_DEVICE_addr_r[3] <= P_DEVICE_addr_i[3];
            P_DEVICE_rw_r[3] <= P_DEVICE_rw_i[3];
            P_DEVICE_byte_enable_r[3] <= P_DEVICE_byte_enable_i[3];
            P_DEVICE_data_r[3] <= P_DEVICE_data_i[3];
        end
    end


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

    always @(posedge clk_i) begin
        if (rst_i)  begin
            sel_current <= 0;
            uart_core_sel_o <= 0;
        end
        else if(c_state == M_IDLE)begin
            if(P_DEVICE_strobe_r[0]) begin
                sel_current <= P0_STROBE;
                if(P_DEVICE_addr_r[0][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 2'b00;
            end
            else if(P_DEVICE_strobe_r[1]) begin
                sel_current <= P1_STROBE;
                if(P_DEVICE_addr_r[1][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 2'b01;
            end
            else if(P_DEVICE_strobe_r[2]) begin
                sel_current <= P2_STROBE;
                if(P_DEVICE_addr_r[2][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 2'b10;
            end
            else if(P_DEVICE_strobe_r[3]) begin
                sel_current <= P3_STROBE;
                if(P_DEVICE_addr_r[3][XLEN-1:XLEN-8] == 8'hC0)
                    uart_core_sel_o <= 2'b11;
            end
        end
    end

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
            if (sel_current == P0_STROBE) begin
                DEVICE_addr_r <= P_DEVICE_addr_r[0];
                DEVICE_rw_r <= P_DEVICE_rw_r[0];
                DEVICE_byte_enable_r <= P_DEVICE_byte_enable_r[0];
                DEVICE_data_r <= P_DEVICE_data_r[0];
            end 
            else if (sel_current == P1_STROBE) begin
                DEVICE_addr_r <= P_DEVICE_addr_r[1];
                DEVICE_rw_r <= P_DEVICE_rw_r[1];
                DEVICE_byte_enable_r <= P_DEVICE_byte_enable_r[1];
                DEVICE_data_r <= P_DEVICE_data_r[1];
            end
            else if (sel_current == P2_STROBE) begin
                DEVICE_addr_r <= P_DEVICE_addr_r[2];
                DEVICE_rw_r <= P_DEVICE_rw_r[2];
                DEVICE_byte_enable_r <= P_DEVICE_byte_enable_r[2];
                DEVICE_data_r <= P_DEVICE_data_r[2];
            end
            else if (sel_current == P3_STROBE) begin
                DEVICE_addr_r <= P_DEVICE_addr_r[3];
                DEVICE_rw_r <= P_DEVICE_rw_r[3];
                DEVICE_byte_enable_r <= P_DEVICE_byte_enable_r[3];
                DEVICE_data_r <= P_DEVICE_data_r[3];
            end
        end
    end


    //=======================================================
    //  Output logic
    //=======================================================
    assign P_DEVICE_data_ready_o[0] = (sel_current == P0_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    assign P_DEVICE_data_o[0]       = DEVICE_data_i;

    assign P_DEVICE_data_ready_o[1] = (sel_current == P1_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    assign P_DEVICE_data_o[1]       = DEVICE_data_i;

    assign P_DEVICE_data_ready_o[2] = (sel_current == P2_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    assign P_DEVICE_data_o[2]       = DEVICE_data_i;

    assign P_DEVICE_data_ready_o[3] = (sel_current == P3_STROBE && c_state == M_WAIT) ? DEVICE_data_ready_i : 'b0;
    assign P_DEVICE_data_o[3]       = DEVICE_data_i;
    
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

    assign have_strobe = P_DEVICE_strobe_r[0] | P_DEVICE_strobe_r[1] | P_DEVICE_strobe_r[2] | P_DEVICE_strobe_r[3];
    
endmodule
