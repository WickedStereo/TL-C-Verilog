`include "tl_pkg.vh"

module tl_top (
    input clk,
    input rst_n,
    
    // Control signals for all 4 L1 adapters
    input [3:0]  start_transaction,  // Pulse to start a new transaction (one bit per L1)
    input [7:0]  transaction_type,   // 2 bits per L1 adapter (0: GET, 1: PUTFULL, 2: PUTPARTIAL, 3: reserved)
    output [3:0] transaction_done,   // Pulses when transaction is complete (one bit per L1)
    
    // Transaction parameters as inputs - individual arrays for each L1 adapter
    input [`TL_ADDR_BITS-1:0]     address_l1_0,    // Address for L1_0 operations
    input [`TL_SIZE_BITS-1:0]     size_l1_0,       // Size for L1_0 operations
    input [`TL_SOURCE_BITS-1:0]   source_l1_0,     // Source for L1_0 operations
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_0, // Data for L1_0 PUT operations
    input [`TL_DATA_BYTES-1:0]    write_mask_l1_0, // Mask for L1_0 PUTPARTIAL operation
    output [`TL_DATA_BYTES*8-1:0] read_data_l1_0,  // Data returned from L1_0 GET operation
    
    input [`TL_ADDR_BITS-1:0]     address_l1_1,    // Address for L1_1 operations
    input [`TL_SIZE_BITS-1:0]     size_l1_1,       // Size for L1_1 operations
    input [`TL_SOURCE_BITS-1:0]   source_l1_1,     // Source for L1_1 operations
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_1, // Data for L1_1 PUT operations
    input [`TL_DATA_BYTES-1:0]    write_mask_l1_1, // Mask for L1_1 PUTPARTIAL operation
    output [`TL_DATA_BYTES*8-1:0] read_data_l1_1,  // Data returned from L1_1 GET operation
    
    input [`TL_ADDR_BITS-1:0]     address_l1_2,    // Address for L1_2 operations
    input [`TL_SIZE_BITS-1:0]     size_l1_2,       // Size for L1_2 operations
    input [`TL_SOURCE_BITS-1:0]   source_l1_2,     // Source for L1_2 operations
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_2, // Data for L1_2 PUT operations
    input [`TL_DATA_BYTES-1:0]    write_mask_l1_2, // Mask for L1_2 PUTPARTIAL operation
    output [`TL_DATA_BYTES*8-1:0] read_data_l1_2,  // Data returned from L1_2 GET operation
    
    input [`TL_ADDR_BITS-1:0]     address_l1_3,    // Address for L1_3 operations
    input [`TL_SIZE_BITS-1:0]     size_l1_3,       // Size for L1_3 operations
    input [`TL_SOURCE_BITS-1:0]   source_l1_3,     // Source for L1_3 operations
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_3, // Data for L1_3 PUT operations
    input [`TL_DATA_BYTES-1:0]    write_mask_l1_3, // Mask for L1_3 PUTPARTIAL operation
    output [`TL_DATA_BYTES*8-1:0] read_data_l1_3,  // Data returned from L1_3 GET operation
    
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

    // --- Wires connecting L1_0 adapter to Interconnect Master Port 0 (m0) ---
    // Channel A (L1_0 -> Interconnect)
    wire  [2:0]                       l1_0_a_opcode;
    wire  [2:0]                       l1_0_a_param;
    wire  [`TL_SIZE_BITS-1:0]         l1_0_a_size;
    wire  [`TL_SOURCE_BITS-1:0]       l1_0_a_source;
    wire  [`TL_ADDR_BITS-1:0]         l1_0_a_address;
    wire  [`TL_DATA_BYTES-1:0]        l1_0_a_mask;
    wire  [`TL_DATA_BYTES*8-1:0]      l1_0_a_data;
    wire                              l1_0_a_valid;
    wire                              l1_0_a_ready;
    // Channel D (Interconnect -> L1_0)
    wire         l1_0_d_valid;
    wire         l1_0_d_ready;
    wire [3:0]   l1_0_d_opcode;
    wire [1:0]   l1_0_d_param;
    wire [`TL_SIZE_BITS-1:0]   l1_0_d_size;
    wire [`TL_SOURCE_BITS-1:0] l1_0_d_source;
    wire [`TL_SINK_BITS-1:0]   l1_0_d_sink;
    wire         l1_0_d_denied;
    wire [`TL_DATA_BYTES*8-1:0] l1_0_d_data;

    // --- Wires connecting L1_1 adapter to Interconnect Master Port 1 (m1) ---
    // Channel A (L1_1 -> Interconnect)
    wire  [2:0]                       l1_1_a_opcode;
    wire  [2:0]                       l1_1_a_param;
    wire  [`TL_SIZE_BITS-1:0]         l1_1_a_size;
    wire  [`TL_SOURCE_BITS-1:0]       l1_1_a_source;
    wire  [`TL_ADDR_BITS-1:0]         l1_1_a_address;
    wire  [`TL_DATA_BYTES-1:0]        l1_1_a_mask;
    wire  [`TL_DATA_BYTES*8-1:0]      l1_1_a_data;
    wire                              l1_1_a_valid;
    wire                              l1_1_a_ready;
    // Channel D (Interconnect -> L1_1)
    wire         l1_1_d_valid;
    wire         l1_1_d_ready;
    wire [3:0]   l1_1_d_opcode;
    wire [1:0]   l1_1_d_param;
    wire [`TL_SIZE_BITS-1:0]   l1_1_d_size;
    wire [`TL_SOURCE_BITS-1:0] l1_1_d_source;
    wire [`TL_SINK_BITS-1:0]   l1_1_d_sink;
    wire         l1_1_d_denied;
    wire [`TL_DATA_BYTES*8-1:0] l1_1_d_data;

    // --- Wires connecting L1_2 adapter to Interconnect Master Port 2 (m2) ---
    // Channel A (L1_2 -> Interconnect)
    wire  [2:0]                       l1_2_a_opcode;
    wire  [2:0]                       l1_2_a_param;
    wire  [`TL_SIZE_BITS-1:0]         l1_2_a_size;
    wire  [`TL_SOURCE_BITS-1:0]       l1_2_a_source;
    wire  [`TL_ADDR_BITS-1:0]         l1_2_a_address;
    wire  [`TL_DATA_BYTES-1:0]        l1_2_a_mask;
    wire  [`TL_DATA_BYTES*8-1:0]      l1_2_a_data;
    wire                              l1_2_a_valid;
    wire                              l1_2_a_ready;
    // Channel D (Interconnect -> L1_2)
    wire         l1_2_d_valid;
    wire         l1_2_d_ready;
    wire [3:0]   l1_2_d_opcode;
    wire [1:0]   l1_2_d_param;
    wire [`TL_SIZE_BITS-1:0]   l1_2_d_size;
    wire [`TL_SOURCE_BITS-1:0] l1_2_d_source;
    wire [`TL_SINK_BITS-1:0]   l1_2_d_sink;
    wire         l1_2_d_denied;
    wire [`TL_DATA_BYTES*8-1:0] l1_2_d_data;

    // --- Wires connecting L1_3 adapter to Interconnect Master Port 3 (m3) ---
    // Channel A (L1_3 -> Interconnect)
    wire  [2:0]                       l1_3_a_opcode;
    wire  [2:0]                       l1_3_a_param;
    wire  [`TL_SIZE_BITS-1:0]         l1_3_a_size;
    wire  [`TL_SOURCE_BITS-1:0]       l1_3_a_source;
    wire  [`TL_ADDR_BITS-1:0]         l1_3_a_address;
    wire  [`TL_DATA_BYTES-1:0]        l1_3_a_mask;
    wire  [`TL_DATA_BYTES*8-1:0]      l1_3_a_data;
    wire                              l1_3_a_valid;
    wire                              l1_3_a_ready;
    // Channel D (Interconnect -> L1_3)
    wire         l1_3_d_valid;
    wire         l1_3_d_ready;
    wire [3:0]   l1_3_d_opcode;
    wire [1:0]   l1_3_d_param;
    wire [`TL_SIZE_BITS-1:0]   l1_3_d_size;
    wire [`TL_SOURCE_BITS-1:0] l1_3_d_source;
    wire [`TL_SINK_BITS-1:0]   l1_3_d_sink;
    wire         l1_3_d_denied;
    wire [`TL_DATA_BYTES*8-1:0] l1_3_d_data;

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

    // Instantiate L1_0 Adapter (Master 0)
    tl_l1_adapter l1_0_adapter (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Control signals
        .start_transaction(start_transaction[0]),
        .transaction_type(transaction_type[1:0]),
        .transaction_done(transaction_done[0]),
        
        // Transaction parameters
        .address    (address_l1_0),
        .size       (size_l1_0),
        .source     (source_l1_0),
        .write_data (write_data_l1_0),
        .write_mask (write_mask_l1_0),
        .read_data  (read_data_l1_0),
        
        // Channel A
        .a_valid    (l1_0_a_valid),
        .a_ready    (l1_0_a_ready),
        .a_opcode   (l1_0_a_opcode),
        .a_param    (l1_0_a_param),
        .a_size     (l1_0_a_size),
        .a_source   (l1_0_a_source),
        .a_address  (l1_0_a_address),
        .a_mask     (l1_0_a_mask),
        .a_data     (l1_0_a_data),
        // Channel D
        .d_valid    (l1_0_d_valid),
        .d_ready    (l1_0_d_ready),
        .d_opcode   (l1_0_d_opcode),
        .d_param    (l1_0_d_param),
        .d_size     (l1_0_d_size),
        .d_source   (l1_0_d_source),
        .d_sink     (l1_0_d_sink),
        .d_denied   (l1_0_d_denied),
        .d_data     (l1_0_d_data)
    );

    // Instantiate L1_1 Adapter (Master 1)
    tl_l1_adapter l1_1_adapter (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Control signals
        .start_transaction(start_transaction[1]),
        .transaction_type(transaction_type[3:2]),
        .transaction_done(transaction_done[1]),
        
        // Transaction parameters
        .address    (address_l1_1),
        .size       (size_l1_1),
        .source     (source_l1_1),
        .write_data (write_data_l1_1),
        .write_mask (write_mask_l1_1),
        .read_data  (read_data_l1_1),
        
        // Channel A
        .a_valid    (l1_1_a_valid),
        .a_ready    (l1_1_a_ready),
        .a_opcode   (l1_1_a_opcode),
        .a_param    (l1_1_a_param),
        .a_size     (l1_1_a_size),
        .a_source   (l1_1_a_source),
        .a_address  (l1_1_a_address),
        .a_mask     (l1_1_a_mask),
        .a_data     (l1_1_a_data),
        // Channel D
        .d_valid    (l1_1_d_valid),
        .d_ready    (l1_1_d_ready),
        .d_opcode   (l1_1_d_opcode),
        .d_param    (l1_1_d_param),
        .d_size     (l1_1_d_size),
        .d_source   (l1_1_d_source),
        .d_sink     (l1_1_d_sink),
        .d_denied   (l1_1_d_denied),
        .d_data     (l1_1_d_data)
    );

    // Instantiate L1_2 Adapter (Master 2)
    tl_l1_adapter l1_2_adapter (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Control signals
        .start_transaction(start_transaction[2]),
        .transaction_type(transaction_type[5:4]),
        .transaction_done(transaction_done[2]),
        
        // Transaction parameters
        .address    (address_l1_2),
        .size       (size_l1_2),
        .source     (source_l1_2),
        .write_data (write_data_l1_2),
        .write_mask (write_mask_l1_2),
        .read_data  (read_data_l1_2),
        
        // Channel A
        .a_valid    (l1_2_a_valid),
        .a_ready    (l1_2_a_ready),
        .a_opcode   (l1_2_a_opcode),
        .a_param    (l1_2_a_param),
        .a_size     (l1_2_a_size),
        .a_source   (l1_2_a_source),
        .a_address  (l1_2_a_address),
        .a_mask     (l1_2_a_mask),
        .a_data     (l1_2_a_data),
        // Channel D
        .d_valid    (l1_2_d_valid),
        .d_ready    (l1_2_d_ready),
        .d_opcode   (l1_2_d_opcode),
        .d_param    (l1_2_d_param),
        .d_size     (l1_2_d_size),
        .d_source   (l1_2_d_source),
        .d_sink     (l1_2_d_sink),
        .d_denied   (l1_2_d_denied),
        .d_data     (l1_2_d_data)
    );

    // Instantiate L1_3 Adapter (Master 3)
    tl_l1_adapter l1_3_adapter (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Control signals
        .start_transaction(start_transaction[3]),
        .transaction_type(transaction_type[7:6]),
        .transaction_done(transaction_done[3]),
        
        // Transaction parameters
        .address    (address_l1_3),
        .size       (size_l1_3),
        .source     (source_l1_3),
        .write_data (write_data_l1_3),
        .write_mask (write_mask_l1_3),
        .read_data  (read_data_l1_3),
        
        // Channel A
        .a_valid    (l1_3_a_valid),
        .a_ready    (l1_3_a_ready),
        .a_opcode   (l1_3_a_opcode),
        .a_param    (l1_3_a_param),
        .a_size     (l1_3_a_size),
        .a_source   (l1_3_a_source),
        .a_address  (l1_3_a_address),
        .a_mask     (l1_3_a_mask),
        .a_data     (l1_3_a_data),
        // Channel D
        .d_valid    (l1_3_d_valid),
        .d_ready    (l1_3_d_ready),
        .d_opcode   (l1_3_d_opcode),
        .d_param    (l1_3_d_param),
        .d_size     (l1_3_d_size),
        .d_source   (l1_3_d_source),
        .d_sink     (l1_3_d_sink),
        .d_denied   (l1_3_d_denied),
        .d_data     (l1_3_d_data)
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

    // Instantiate TileLink Interconnect with 4 masters and 1 slave
    tl_interconnect interconnect (
        .clk        (clk),
        .rst_n      (rst_n),
        
        // Master Port 0 (Connects to L1_0)
        .m0_a_valid    (l1_0_a_valid),
        .m0_a_ready    (l1_0_a_ready),
        .m0_a_opcode   (l1_0_a_opcode),
        .m0_a_param    (l1_0_a_param),
        .m0_a_size     (l1_0_a_size),
        .m0_a_source   (l1_0_a_source),
        .m0_a_address  (l1_0_a_address),
        .m0_a_mask     (l1_0_a_mask),
        .m0_a_data     (l1_0_a_data),
        .m0_d_valid    (l1_0_d_valid),
        .m0_d_ready    (l1_0_d_ready),
        .m0_d_opcode   (l1_0_d_opcode),
        .m0_d_param    (l1_0_d_param),
        .m0_d_size     (l1_0_d_size),
        .m0_d_source   (l1_0_d_source),
        .m0_d_sink     (l1_0_d_sink),
        .m0_d_denied   (l1_0_d_denied),
        .m0_d_data     (l1_0_d_data),
        
        // Master Port 1 (Connects to L1_1)
        .m1_a_valid    (l1_1_a_valid),
        .m1_a_ready    (l1_1_a_ready),
        .m1_a_opcode   (l1_1_a_opcode),
        .m1_a_param    (l1_1_a_param),
        .m1_a_size     (l1_1_a_size),
        .m1_a_source   (l1_1_a_source),
        .m1_a_address  (l1_1_a_address),
        .m1_a_mask     (l1_1_a_mask),
        .m1_a_data     (l1_1_a_data),
        .m1_d_valid    (l1_1_d_valid),
        .m1_d_ready    (l1_1_d_ready),
        .m1_d_opcode   (l1_1_d_opcode),
        .m1_d_param    (l1_1_d_param),
        .m1_d_size     (l1_1_d_size),
        .m1_d_source   (l1_1_d_source),
        .m1_d_sink     (l1_1_d_sink),
        .m1_d_denied   (l1_1_d_denied),
        .m1_d_data     (l1_1_d_data),
        
        // Master Port 2 (Connects to L1_2)
        .m2_a_valid    (l1_2_a_valid),
        .m2_a_ready    (l1_2_a_ready),
        .m2_a_opcode   (l1_2_a_opcode),
        .m2_a_param    (l1_2_a_param),
        .m2_a_size     (l1_2_a_size),
        .m2_a_source   (l1_2_a_source),
        .m2_a_address  (l1_2_a_address),
        .m2_a_mask     (l1_2_a_mask),
        .m2_a_data     (l1_2_a_data),
        .m2_d_valid    (l1_2_d_valid),
        .m2_d_ready    (l1_2_d_ready),
        .m2_d_opcode   (l1_2_d_opcode),
        .m2_d_param    (l1_2_d_param),
        .m2_d_size     (l1_2_d_size),
        .m2_d_source   (l1_2_d_source),
        .m2_d_sink     (l1_2_d_sink),
        .m2_d_denied   (l1_2_d_denied),
        .m2_d_data     (l1_2_d_data),
        
        // Master Port 3 (Connects to L1_3)
        .m3_a_valid    (l1_3_a_valid),
        .m3_a_ready    (l1_3_a_ready),
        .m3_a_opcode   (l1_3_a_opcode),
        .m3_a_param    (l1_3_a_param),
        .m3_a_size     (l1_3_a_size),
        .m3_a_source   (l1_3_a_source),
        .m3_a_address  (l1_3_a_address),
        .m3_a_mask     (l1_3_a_mask),
        .m3_a_data     (l1_3_a_data),
        .m3_d_valid    (l1_3_d_valid),
        .m3_d_ready    (l1_3_d_ready),
        .m3_d_opcode   (l1_3_d_opcode),
        .m3_d_param    (l1_3_d_param),
        .m3_d_size     (l1_3_d_size),
        .m3_d_source   (l1_3_d_source),
        .m3_d_sink     (l1_3_d_sink),
        .m3_d_denied   (l1_3_d_denied),
        .m3_d_data     (l1_3_d_data),
        
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