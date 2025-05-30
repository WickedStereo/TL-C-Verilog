`timescale 1ns / 1ps

`include "tl_pkg.vh"

// ------------------------------------------------------------
// TileLink UL (Uncached Lightweight) interconnect
// One master (m0) ↔ one slave (s0) • Channels: A & D only
// ------------------------------------------------------------
module tl_interconnect (
    input clk,
    input rst_n,

    // ---------------- Master Port 0 (m0) ----------------
    // Channel-A (master → interconnect)
    input  [2:0]                       m0_a_opcode ,
    input  [2:0]                       m0_a_param  ,
    input  [`TL_SIZE_BITS-1:0]         m0_a_size   ,
    input  [`TL_SOURCE_BITS-1:0]       m0_a_source ,
    input  [`TL_ADDR_BITS-1:0]         m0_a_address,
    input  [`TL_DATA_BYTES-1:0]        m0_a_mask   ,
    input  [`TL_DATA_BYTES*8-1:0]      m0_a_data   ,
    input                              m0_a_valid  ,
    output                             m0_a_ready  ,

    // Channel-D (interconnect → master)
    output [3:0]                       m0_d_opcode ,
    output [1:0]                       m0_d_param  ,
    output [`TL_SIZE_BITS-1:0]         m0_d_size   ,
    output [`TL_SOURCE_BITS-1:0]       m0_d_source ,
    output [`TL_SINK_BITS-1:0]         m0_d_sink   ,
    output                             m0_d_denied ,
    output [`TL_DATA_BYTES*8-1:0]      m0_d_data   ,
    output                             m0_d_valid  ,
    input                              m0_d_ready  ,

    // ---------------- Slave Port 0 (s0) -----------------
    // Channel-A (interconnect → slave)
    output [2:0]                       s0_a_opcode ,
    output [2:0]                       s0_a_param  ,
    output [`TL_SIZE_BITS-1:0]         s0_a_size   ,
    output [`TL_SOURCE_BITS-1:0]       s0_a_source ,
    output [`TL_ADDR_BITS-1:0]         s0_a_address,
    output [`TL_DATA_BYTES-1:0]        s0_a_mask   ,
    output [`TL_DATA_BYTES*8-1:0]      s0_a_data   ,
    output                             s0_a_valid  ,
    input                              s0_a_ready  ,

    // Channel-D (slave → interconnect)
    input  [3:0]                       s0_d_opcode ,
    input  [1:0]                       s0_d_param  ,
    input  [`TL_SIZE_BITS-1:0]         s0_d_size   ,
    input  [`TL_SOURCE_BITS-1:0]       s0_d_source ,
    input  [`TL_SINK_BITS-1:0]         s0_d_sink   ,
    input                              s0_d_denied ,
    input  [`TL_DATA_BYTES*8-1:0]      s0_d_data   ,
    input                              s0_d_valid  ,
    output                             s0_d_ready
);

    // Count of outstanding requests (sent on A, not yet responded on D)
    reg [`TL_SOURCE_BITS:0] outstanding_req_count;  // Extra bit to prevent overflow
    
    // Track if we are processing a valid transaction
    reg transaction_in_progress;
    
    // Track A channel transactions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outstanding_req_count <= 0;
            transaction_in_progress <= 0;
        end 
        else begin
            // Count A requests sent (m0_a_valid && m0_a_ready means successful transfer)
            // Count D responses received (m0_d_valid && m0_d_ready means successful transfer)
            if ((m0_a_valid && m0_a_ready) && !(m0_d_valid && m0_d_ready)) begin
                // A request sent but no D response
                outstanding_req_count <= outstanding_req_count + 1;
                transaction_in_progress <= 1;
            end 
            else if (!(m0_a_valid && m0_a_ready) && (m0_d_valid && m0_d_ready)) begin
                // D response received but no A request
                outstanding_req_count <= outstanding_req_count - 1;
                transaction_in_progress <= (outstanding_req_count > 1);
            end
            // Both or neither - count stays the same
        end
    end

    //------------------------------------------------------------------
    // A-channel - combinational pass-through obeying ready/valid rules
    //------------------------------------------------------------------
    assign s0_a_opcode  = m0_a_opcode ;
    assign s0_a_param   = m0_a_param  ;
    assign s0_a_size    = m0_a_size   ;
    assign s0_a_source  = m0_a_source ;
    assign s0_a_address = m0_a_address;
    assign s0_a_mask    = m0_a_mask   ;
    assign s0_a_data    = m0_a_data   ;
    assign s0_a_valid   = m0_a_valid  ;
    assign m0_a_ready   = s0_a_ready  ;

    //------------------------------------------------------------------
    // D-channel - combinational pass-through obeying ready/valid rules
    //------------------------------------------------------------------
    assign m0_d_opcode  = s0_d_opcode ;
    assign m0_d_param   = s0_d_param  ;
    assign m0_d_size    = s0_d_size   ;
    assign m0_d_source  = s0_d_source ;
    assign m0_d_sink    = s0_d_sink   ;
    assign m0_d_denied  = s0_d_denied ;
    assign m0_d_data    = s0_d_data   ;
    assign m0_d_valid   = s0_d_valid  ;
    assign s0_d_ready   = m0_d_ready  ;

endmodule