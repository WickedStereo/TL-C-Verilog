`include "tl_pkg.vh"

// ------------------------------------------------------------
// TileLink UL (Uncached Lightweight) interconnect
// Four masters (m0-m3) ↔ one slave (s0) • Channels: A & D only
// Implements round-robin arbitration between masters
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
    
    // ---------------- Master Port 1 (m1) ----------------
    // Channel-A (master → interconnect)
    input  [2:0]                       m1_a_opcode ,
    input  [2:0]                       m1_a_param  ,
    input  [`TL_SIZE_BITS-1:0]         m1_a_size   ,
    input  [`TL_SOURCE_BITS-1:0]       m1_a_source ,
    input  [`TL_ADDR_BITS-1:0]         m1_a_address,
    input  [`TL_DATA_BYTES-1:0]        m1_a_mask   ,
    input  [`TL_DATA_BYTES*8-1:0]      m1_a_data   ,
    input                              m1_a_valid  ,
    output                             m1_a_ready  ,

    // Channel-D (interconnect → master)
    output [3:0]                       m1_d_opcode ,
    output [1:0]                       m1_d_param  ,
    output [`TL_SIZE_BITS-1:0]         m1_d_size   ,
    output [`TL_SOURCE_BITS-1:0]       m1_d_source ,
    output [`TL_SINK_BITS-1:0]         m1_d_sink   ,
    output                             m1_d_denied ,
    output [`TL_DATA_BYTES*8-1:0]      m1_d_data   ,
    output                             m1_d_valid  ,
    input                              m1_d_ready  ,
    
    // ---------------- Master Port 2 (m2) ----------------
    // Channel-A (master → interconnect)
    input  [2:0]                       m2_a_opcode ,
    input  [2:0]                       m2_a_param  ,
    input  [`TL_SIZE_BITS-1:0]         m2_a_size   ,
    input  [`TL_SOURCE_BITS-1:0]       m2_a_source ,
    input  [`TL_ADDR_BITS-1:0]         m2_a_address,
    input  [`TL_DATA_BYTES-1:0]        m2_a_mask   ,
    input  [`TL_DATA_BYTES*8-1:0]      m2_a_data   ,
    input                              m2_a_valid  ,
    output                             m2_a_ready  ,

    // Channel-D (interconnect → master)
    output [3:0]                       m2_d_opcode ,
    output [1:0]                       m2_d_param  ,
    output [`TL_SIZE_BITS-1:0]         m2_d_size   ,
    output [`TL_SOURCE_BITS-1:0]       m2_d_source ,
    output [`TL_SINK_BITS-1:0]         m2_d_sink   ,
    output                             m2_d_denied ,
    output [`TL_DATA_BYTES*8-1:0]      m2_d_data   ,
    output                             m2_d_valid  ,
    input                              m2_d_ready  ,
    
    // ---------------- Master Port 3 (m3) ----------------
    // Channel-A (master → interconnect)
    input  [2:0]                       m3_a_opcode ,
    input  [2:0]                       m3_a_param  ,
    input  [`TL_SIZE_BITS-1:0]         m3_a_size   ,
    input  [`TL_SOURCE_BITS-1:0]       m3_a_source ,
    input  [`TL_ADDR_BITS-1:0]         m3_a_address,
    input  [`TL_DATA_BYTES-1:0]        m3_a_mask   ,
    input  [`TL_DATA_BYTES*8-1:0]      m3_a_data   ,
    input                              m3_a_valid  ,
    output                             m3_a_ready  ,

    // Channel-D (interconnect → master)
    output [3:0]                       m3_d_opcode ,
    output [1:0]                       m3_d_param  ,
    output [`TL_SIZE_BITS-1:0]         m3_d_size   ,
    output [`TL_SOURCE_BITS-1:0]       m3_d_source ,
    output [`TL_SINK_BITS-1:0]         m3_d_sink   ,
    output                             m3_d_denied ,
    output [`TL_DATA_BYTES*8-1:0]      m3_d_data   ,
    output                             m3_d_valid  ,
    input                              m3_d_ready  ,

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

    // Define master IDs for tracking
    localparam M0_ID = 2'b00;
    localparam M1_ID = 2'b01;
    localparam M2_ID = 2'b10;
    localparam M3_ID = 2'b11;
    
    // ----------------------- Round-Robin Arbiter Logic -----------------------
    
    // Arbitration state register - stores which master gets priority next
    reg [1:0] rr_priority;
    
    // Transaction tracking registers
    reg [3:0] outstanding_req_valid;  // One bit per master
    reg [1:0] outstanding_req_master [0:3]; // Master ID for each outstanding request
    reg [2:0] outstanding_req_count;  // Count of outstanding requests
    
    // ID of currently selected master
    reg [1:0] selected_master;
    reg selected_valid;
    
    // Select the next master based on round-robin priority
    always @(*) begin
        selected_valid = 1'b0;
        selected_master = 2'b00; // Default assignment
        
        // Round-robin selection logic
        case (rr_priority)
            M0_ID: begin
                if (m0_a_valid)      { selected_valid, selected_master } = { 1'b1, M0_ID };
                else if (m1_a_valid) { selected_valid, selected_master } = { 1'b1, M1_ID };
                else if (m2_a_valid) { selected_valid, selected_master } = { 1'b1, M2_ID };
                else if (m3_a_valid) { selected_valid, selected_master } = { 1'b1, M3_ID };
            end
            
            M1_ID: begin
                if (m1_a_valid)      { selected_valid, selected_master } = { 1'b1, M1_ID };
                else if (m2_a_valid) { selected_valid, selected_master } = { 1'b1, M2_ID };
                else if (m3_a_valid) { selected_valid, selected_master } = { 1'b1, M3_ID };
                else if (m0_a_valid) { selected_valid, selected_master } = { 1'b1, M0_ID };
            end
            
            M2_ID: begin
                if (m2_a_valid)      { selected_valid, selected_master } = { 1'b1, M2_ID };
                else if (m3_a_valid) { selected_valid, selected_master } = { 1'b1, M3_ID };
                else if (m0_a_valid) { selected_valid, selected_master } = { 1'b1, M0_ID };
                else if (m1_a_valid) { selected_valid, selected_master } = { 1'b1, M1_ID };
            end
            
            M3_ID: begin
                if (m3_a_valid)      { selected_valid, selected_master } = { 1'b1, M3_ID };
                else if (m0_a_valid) { selected_valid, selected_master } = { 1'b1, M0_ID };
                else if (m1_a_valid) { selected_valid, selected_master } = { 1'b1, M1_ID };
                else if (m2_a_valid) { selected_valid, selected_master } = { 1'b1, M2_ID };
            end
        endcase
    end
    
    // Update the round-robin priority register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_priority <= M0_ID;
            outstanding_req_count <= 3'd0;
            outstanding_req_valid <= 4'b0000;
        end else begin
            // On successful A channel transfer, update round-robin priority
            if (s0_a_valid && s0_a_ready) begin
                // Move to next master in round-robin order
                rr_priority <= (selected_master == M3_ID) ? M0_ID : selected_master + 1'b1;
                
                // Track outstanding request
                if (outstanding_req_count < 4) begin
                    outstanding_req_valid[outstanding_req_count] <= 1'b1;
                    outstanding_req_master[outstanding_req_count] <= selected_master;
                    outstanding_req_count <= outstanding_req_count + 1'b1;
                end
            end
            
            // On D channel response completion, update outstanding request tracking
            if (s0_d_valid && s0_d_ready) begin
                if (outstanding_req_count > 0) begin
                    // Shift the outstanding request queue
                    outstanding_req_valid[0] <= outstanding_req_valid[1];
                    outstanding_req_valid[1] <= outstanding_req_valid[2];
                    outstanding_req_valid[2] <= outstanding_req_valid[3];
                    outstanding_req_valid[3] <= 1'b0;
                    
                    outstanding_req_master[0] <= outstanding_req_master[1];
                    outstanding_req_master[1] <= outstanding_req_master[2];
                    outstanding_req_master[2] <= outstanding_req_master[3];
                    
                    outstanding_req_count <= outstanding_req_count - 1'b1;
                end
            end
            
            // Handle simultaneous A and D transfers
            if (s0_a_valid && s0_a_ready && s0_d_valid && s0_d_ready) begin
                // Net change is zero to outstanding_req_count, so no additional change needed
            end
        end
    end
    
    // ------------------------- A Channel Muxing Logic -------------------------
    
    // Mux the selected master to the slave port based on selected_master
    assign s0_a_valid   = selected_valid;
    assign s0_a_opcode  = (selected_master == M0_ID) ? m0_a_opcode  :
                          (selected_master == M1_ID) ? m1_a_opcode  :
                          (selected_master == M2_ID) ? m2_a_opcode  : m3_a_opcode;
    assign s0_a_param   = (selected_master == M0_ID) ? m0_a_param   :
                          (selected_master == M1_ID) ? m1_a_param   :
                          (selected_master == M2_ID) ? m2_a_param   : m3_a_param;
    assign s0_a_size    = (selected_master == M0_ID) ? m0_a_size    :
                          (selected_master == M1_ID) ? m1_a_size    :
                          (selected_master == M2_ID) ? m2_a_size    : m3_a_size;
    assign s0_a_source  = (selected_master == M0_ID) ? m0_a_source  :
                          (selected_master == M1_ID) ? m1_a_source  :
                          (selected_master == M2_ID) ? m2_a_source  : m3_a_source;
    assign s0_a_address = (selected_master == M0_ID) ? m0_a_address :
                          (selected_master == M1_ID) ? m1_a_address :
                          (selected_master == M2_ID) ? m2_a_address : m3_a_address;
    assign s0_a_mask    = (selected_master == M0_ID) ? m0_a_mask    :
                          (selected_master == M1_ID) ? m1_a_mask    :
                          (selected_master == M2_ID) ? m2_a_mask    : m3_a_mask;
    assign s0_a_data    = (selected_master == M0_ID) ? m0_a_data    :
                          (selected_master == M1_ID) ? m1_a_data    :
                          (selected_master == M2_ID) ? m2_a_data    : m3_a_data;
    
    // Ready signal needs to go back to the selected master only
    assign m0_a_ready = (selected_master == M0_ID) ? s0_a_ready : 1'b0;
    assign m1_a_ready = (selected_master == M1_ID) ? s0_a_ready : 1'b0;
    assign m2_a_ready = (selected_master == M2_ID) ? s0_a_ready : 1'b0;
    assign m3_a_ready = (selected_master == M3_ID) ? s0_a_ready : 1'b0;

    // ------------------------- D Channel Routing Logic -------------------------
    // Response goes back to the master that sent the request

    // Get the master ID for the current response
    wire [1:0] responding_master = (outstanding_req_count > 0) ? outstanding_req_master[0] : 2'b00;
    
    // Route D channel response to the proper master
    assign m0_d_valid   = (responding_master == M0_ID) ? s0_d_valid : 1'b0;
    assign m0_d_opcode  = s0_d_opcode;
    assign m0_d_param   = s0_d_param;
    assign m0_d_size    = s0_d_size;
    assign m0_d_source  = s0_d_source;
    assign m0_d_sink    = s0_d_sink;
    assign m0_d_denied  = s0_d_denied;
    assign m0_d_data    = s0_d_data;
    
    assign m1_d_valid   = (responding_master == M1_ID) ? s0_d_valid : 1'b0;
    assign m1_d_opcode  = s0_d_opcode;
    assign m1_d_param   = s0_d_param;
    assign m1_d_size    = s0_d_size;
    assign m1_d_source  = s0_d_source;
    assign m1_d_sink    = s0_d_sink;
    assign m1_d_denied  = s0_d_denied;
    assign m1_d_data    = s0_d_data;
    
    assign m2_d_valid   = (responding_master == M2_ID) ? s0_d_valid : 1'b0;
    assign m2_d_opcode  = s0_d_opcode;
    assign m2_d_param   = s0_d_param;
    assign m2_d_size    = s0_d_size;
    assign m2_d_source  = s0_d_source;
    assign m2_d_sink    = s0_d_sink;
    assign m2_d_denied  = s0_d_denied;
    assign m2_d_data    = s0_d_data;
    
    assign m3_d_valid   = (responding_master == M3_ID) ? s0_d_valid : 1'b0;
    assign m3_d_opcode  = s0_d_opcode;
    assign m3_d_param   = s0_d_param;
    assign m3_d_size    = s0_d_size;
    assign m3_d_source  = s0_d_source;
    assign m3_d_sink    = s0_d_sink;
    assign m3_d_denied  = s0_d_denied;
    assign m3_d_data    = s0_d_data;
    
    // D channel ready from the responding master to the slave
    assign s0_d_ready   = (responding_master == M0_ID) ? m0_d_ready :
                          (responding_master == M1_ID) ? m1_d_ready :
                          (responding_master == M2_ID) ? m2_d_ready : m3_d_ready;

endmodule