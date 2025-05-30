`timescale 1ns / 1ps
`include "tl_pkg.vh"

module tl_top (
    input clk,
    input rst_n,
    
    // Control signals
    input        start_transaction,  // Pulse to start a new transaction
    input [1:0]  transaction_type,   // 0: GET, 1: PUTFULL, 2: PUTPARTIAL, 3: reserved
    output       transaction_done,   // Pulses when transaction is complete
    
    // Transaction parameters as inputs
    input [`TL_ADDR_BITS-1:0]     address,    // Address for any operation
    input [`TL_SIZE_BITS-1:0]     size,       // Size for any operation
    input [`TL_SOURCE_BITS-1:0]   source,     // Source for any operation
    input [`TL_DATA_BYTES*8-1:0]  write_data, // Data for PUT operations
    input [`TL_DATA_BYTES-1:0]    write_mask, // Mask for PUTPARTIAL operation
    output [`TL_DATA_BYTES*8-1:0] read_data,  // Data returned from GET operation
    
    // Memory monitoring outputs from L2 adapter
    output                              mem_write_valid,
    output [`TL_ADDR_BITS-1:0]          mem_write_addr,
    output [`TL_DATA_BYTES*8-1:0]       mem_write_data,
    output [`TL_DATA_BYTES-1:0]         mem_write_mask,
    
    output                              mem_read_valid,
    output [`TL_ADDR_BITS-1:0]          mem_read_addr,
    output [`TL_DATA_BYTES*8-1:0]       mem_read_data,
    
    // Response monitoring outputs
    output                              resp_valid,
    output [3:0]                        resp_opcode,
    output [`TL_SOURCE_BITS-1:0]        resp_source,
    output [`TL_DATA_BYTES*8-1:0]       resp_data
);

    // --- Wires connecting L1 adapter to Interconnect Master Port 0 (m0) ---
    // Channel A (L1 -> Interconnect)
    wire  [2:0]                       l1_a_opcode ;
    wire  [2:0]                       l1_a_param  ;
    wire  [`TL_SIZE_BITS-1:0]         l1_a_size   ;
    wire  [`TL_SOURCE_BITS-1:0]       l1_a_source ;
    wire  [`TL_ADDR_BITS-1:0]         l1_a_address;
    wire  [`TL_DATA_BYTES-1:0]        l1_a_mask   ;
    wire  [`TL_DATA_BYTES*8-1:0]      l1_a_data   ;
    wire                              l1_a_valid  ;
    wire                              l1_a_ready  ;
    // Channel D (Interconnect -> L1)
    wire         l1_d_valid;
    wire         l1_d_ready;
    wire [3:0]   l1_d_opcode;
    wire [1:0]   l1_d_param;
    wire [`TL_SIZE_BITS-1:0]   l1_d_size;
    wire [`TL_SOURCE_BITS-1:0] l1_d_source;
    wire [`TL_SINK_BITS-1:0]   l1_d_sink;
    wire         l1_d_denied;
    wire [`TL_DATA_BYTES*8-1:0] l1_d_data;

    // --- Wires connecting Interconnect Slave Port 0 (s0) to L2 adapter ---
    // Channel A (Interconnect -> L2)
    wire         l2_a_valid;
    wire         l2_a_ready;
    wire [2:0]   l2_a_opcode;
    wire [2:0]   l2_a_param;
    wire [`TL_SIZE_BITS-1:0]   l2_a_size;
    wire [`TL_SOURCE_BITS-1:0] l2_a_source;
    wire [`TL_ADDR_BITS-1:0]   l2_a_address;
    wire [`TL_DATA_BYTES-1:0]  l2_a_mask;
    wire [`TL_DATA_BYTES*8-1:0] l2_a_data;
    // Channel D (L2 -> Interconnect)
    wire         l2_d_valid;
    wire         l2_d_ready;
    wire [3:0]   l2_d_opcode;
    wire [1:0]   l2_d_param;
    wire [`TL_SIZE_BITS-1:0]   l2_d_size;
    wire [`TL_SOURCE_BITS-1:0] l2_d_source;
    wire [`TL_SINK_BITS-1:0]   l2_d_sink;
    wire         l2_d_denied;
    wire [`TL_DATA_BYTES*8-1:0] l2_d_data;

    // --- Instantiations ---

    // Instantiate L1 Adapter (Master)
    tl_l1_adapter l1_adapter (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Control signals
        .start_transaction(start_transaction),
        .transaction_type(transaction_type),
        .transaction_done(transaction_done),
        
        // Transaction parameters
        .address    (address),
        .size       (size),
        .source     (source),
        .write_data (write_data),
        .write_mask (write_mask),
        .read_data  (read_data),
        
        // Channel A
        .a_valid    (l1_a_valid),
        .a_ready    (l1_a_ready),
        .a_opcode   (l1_a_opcode),
        .a_param    (l1_a_param),
        .a_size     (l1_a_size),
        .a_source   (l1_a_source),
        .a_address  (l1_a_address),
        .a_mask     (l1_a_mask),
        .a_data     (l1_a_data),
        // Channel D
        .d_valid    (l1_d_valid),
        .d_ready    (l1_d_ready),
        .d_opcode   (l1_d_opcode),
        .d_param    (l1_d_param),
        .d_size     (l1_d_size),
        .d_source   (l1_d_source),
        .d_sink     (l1_d_sink),
        .d_denied   (l1_d_denied),
        .d_data     (l1_d_data)
    );

    // Instantiate L2 Adapter (Slave)
    tl_l2_adapter l2_adapter (
        .clk        (clk),
        .rst_n      (rst_n),
        // Channel A
        .a_valid    (l2_a_valid),
        .a_ready    (l2_a_ready),
        .a_opcode   (l2_a_opcode),
        .a_param    (l2_a_param),
        .a_size     (l2_a_size),
        .a_source   (l2_a_source),
        .a_address  (l2_a_address),
        .a_mask     (l2_a_mask),
        .a_data     (l2_a_data),
        // Channel D
        .d_valid    (l2_d_valid),
        .d_ready    (l2_d_ready),
        .d_opcode   (l2_d_opcode),
        .d_param    (l2_d_param),
        .d_size     (l2_d_size),
        .d_source   (l2_d_source),
        .d_sink     (l2_d_sink),
        .d_denied   (l2_d_denied),
        .d_data     (l2_d_data),
        
        // Memory monitoring outputs
        .mem_write_valid(mem_write_valid),
        .mem_write_addr (mem_write_addr),
        .mem_write_data (mem_write_data),
        .mem_write_mask (mem_write_mask),
        
        .mem_read_valid (mem_read_valid),
        .mem_read_addr  (mem_read_addr),
        .mem_read_data  (mem_read_data),
        
        // Response monitoring outputs
        .resp_valid  (resp_valid),
        .resp_opcode (resp_opcode),
        .resp_source (resp_source),
        .resp_data   (resp_data)
    );

    // Instantiate TileLink Interconnect
    tl_interconnect interconnect_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        // Master Port 0 (Connects to L1)
        .m0_a_valid    (l1_a_valid),
        .m0_a_ready    (l1_a_ready),
        .m0_a_opcode   (l1_a_opcode),
        .m0_a_param    (l1_a_param),
        .m0_a_size     (l1_a_size),
        .m0_a_source   (l1_a_source),
        .m0_a_address  (l1_a_address),
        .m0_a_mask     (l1_a_mask),
        .m0_a_data     (l1_a_data),
        .m0_d_valid    (l1_d_valid),
        .m0_d_ready    (l1_d_ready),
        .m0_d_opcode   (l1_d_opcode),
        .m0_d_param    (l1_d_param),
        .m0_d_size     (l1_d_size),
        .m0_d_source   (l1_d_source),
        .m0_d_sink     (l1_d_sink),
        .m0_d_denied   (l1_d_denied),
        .m0_d_data     (l1_d_data),
        // Slave Port 0 (Connects to L2)
        .s0_a_valid    (l2_a_valid),
        .s0_a_ready    (l2_a_ready),
        .s0_a_opcode   (l2_a_opcode),
        .s0_a_param    (l2_a_param),
        .s0_a_size     (l2_a_size),
        .s0_a_source   (l2_a_source),
        .s0_a_address  (l2_a_address),
        .s0_a_mask     (l2_a_mask),
        .s0_a_data     (l2_a_data),
        .s0_d_valid    (l2_d_valid),
        .s0_d_ready    (l2_d_ready),
        .s0_d_opcode   (l2_d_opcode),
        .s0_d_param    (l2_d_param),
        .s0_d_size     (l2_d_size),
        .s0_d_source   (l2_d_source),
        .s0_d_sink     (l2_d_sink),
        .s0_d_denied   (l2_d_denied),
        .s0_d_data     (l2_d_data)
    );

endmodule