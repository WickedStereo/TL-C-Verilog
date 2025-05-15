`timescale 1ns / 1ps
`include "tl_pkg.vh"

module tb_tl_top;

    // Common signals for DUT
    wire clk;
    wire rst_n;
    
    // Control signals for 4 L1 adapters
    wire [3:0]  start_transaction;  // Pulse to start a new transaction (one bit per L1)
    wire [7:0]  transaction_type;   // 2 bits per L1 adapter (0: GET, 1: PUTFULL, 2: PUTPARTIAL, 3: reserved)
    wire [3:0]  transaction_done;   // Pulses when transaction is complete (one bit per L1)
    
    // Transaction parameters for L1_0
    wire [`TL_ADDR_BITS-1:0]     address_l1_0;     // Address for L1_0 operations
    wire [`TL_SIZE_BITS-1:0]     size_l1_0;        // Size for L1_0 operations
    wire [`TL_SOURCE_BITS-1:0]   source_l1_0;      // Source for L1_0 operations
    wire [`TL_DATA_BYTES*8-1:0]  write_data_l1_0;  // Data for L1_0 PUT operations
    wire [`TL_DATA_BYTES-1:0]    write_mask_l1_0;  // Mask for L1_0 PUTPARTIAL operation
    wire [`TL_DATA_BYTES*8-1:0]  read_data_l1_0;   // Data returned from L1_0 GET operation
    
    // Transaction parameters for L1_1
    wire [`TL_ADDR_BITS-1:0]     address_l1_1;     // Address for L1_1 operations
    wire [`TL_SIZE_BITS-1:0]     size_l1_1;        // Size for L1_1 operations
    wire [`TL_SOURCE_BITS-1:0]   source_l1_1;      // Source for L1_1 operations
    wire [`TL_DATA_BYTES*8-1:0]  write_data_l1_1;  // Data for L1_1 PUT operations
    wire [`TL_DATA_BYTES-1:0]    write_mask_l1_1;  // Mask for L1_1 PUTPARTIAL operation
    wire [`TL_DATA_BYTES*8-1:0]  read_data_l1_1;   // Data returned from L1_1 GET operation
    
    // Transaction parameters for L1_2
    wire [`TL_ADDR_BITS-1:0]     address_l1_2;     // Address for L1_2 operations
    wire [`TL_SIZE_BITS-1:0]     size_l1_2;        // Size for L1_2 operations
    wire [`TL_SOURCE_BITS-1:0]   source_l1_2;      // Source for L1_2 operations
    wire [`TL_DATA_BYTES*8-1:0]  write_data_l1_2;  // Data for L1_2 PUT operations
    wire [`TL_DATA_BYTES-1:0]    write_mask_l1_2;  // Mask for L1_2 PUTPARTIAL operation
    wire [`TL_DATA_BYTES*8-1:0]  read_data_l1_2;   // Data returned from L1_2 GET operation
    
    // Transaction parameters for L1_3
    wire [`TL_ADDR_BITS-1:0]     address_l1_3;     // Address for L1_3 operations
    wire [`TL_SIZE_BITS-1:0]     size_l1_3;        // Size for L1_3 operations
    wire [`TL_SOURCE_BITS-1:0]   source_l1_3;      // Source for L1_3 operations
    wire [`TL_DATA_BYTES*8-1:0]  write_data_l1_3;  // Data for L1_3 PUT operations
    wire [`TL_DATA_BYTES-1:0]    write_mask_l1_3;  // Mask for L1_3 PUTPARTIAL operation
    wire [`TL_DATA_BYTES*8-1:0]  read_data_l1_3;   // Data returned from L1_3 GET operation
    
    // Memory monitoring outputs from L2 adapter
    wire                              mem_write_valid;
    wire [`TL_ADDR_BITS-1:0]          mem_write_addr;
    wire [`TL_DATA_BYTES*8-1:0]       mem_write_data;
    wire [`TL_DATA_BYTES-1:0]         mem_write_mask;
    
    wire                              mem_read_valid;
    wire [`TL_ADDR_BITS-1:0]          mem_read_addr;
    wire [`TL_DATA_BYTES*8-1:0]       mem_read_data;
    
    // Response monitoring outputs
    wire                              resp_valid;
    wire [3:0]                        resp_opcode;
    wire [`TL_SOURCE_BITS-1:0]        resp_source;
    wire [`TL_DATA_BYTES*8-1:0]       resp_data;

    // Test control signals
    wire test_done;
    wire mem_init_done;
    wire all_tests_passed;

    // Instantiate the DUT (Design Under Test)
    tl_top dut (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Control signals for all 4 L1 adapters
        .start_transaction  (start_transaction),
        .transaction_type   (transaction_type),
        .transaction_done   (transaction_done),
        
        // Transaction parameters for L1_0
        .address_l1_0       (address_l1_0),
        .size_l1_0          (size_l1_0),
        .source_l1_0        (source_l1_0),
        .write_data_l1_0    (write_data_l1_0),
        .write_mask_l1_0    (write_mask_l1_0),
        .read_data_l1_0     (read_data_l1_0),
        
        // Transaction parameters for L1_1
        .address_l1_1       (address_l1_1),
        .size_l1_1          (size_l1_1),
        .source_l1_1        (source_l1_1),
        .write_data_l1_1    (write_data_l1_1),
        .write_mask_l1_1    (write_mask_l1_1),
        .read_data_l1_1     (read_data_l1_1),
        
        // Transaction parameters for L1_2
        .address_l1_2       (address_l1_2),
        .size_l1_2          (size_l1_2),
        .source_l1_2        (source_l1_2),
        .write_data_l1_2    (write_data_l1_2),
        .write_mask_l1_2    (write_mask_l1_2),
        .read_data_l1_2     (read_data_l1_2),
        
        // Transaction parameters for L1_3
        .address_l1_3       (address_l1_3),
        .size_l1_3          (size_l1_3),
        .source_l1_3        (source_l1_3),
        .write_data_l1_3    (write_data_l1_3),
        .write_mask_l1_3    (write_mask_l1_3),
        .read_data_l1_3     (read_data_l1_3),
        
        // Memory monitoring outputs
        .mem_write_valid    (mem_write_valid),
        .mem_write_addr     (mem_write_addr),
        .mem_write_data     (mem_write_data),
        .mem_write_mask     (mem_write_mask),
        
        .mem_read_valid     (mem_read_valid),
        .mem_read_addr      (mem_read_addr),
        .mem_read_data      (mem_read_data),
        
        // Response monitoring outputs
        .resp_valid         (resp_valid),
        .resp_opcode        (resp_opcode),
        .resp_source        (resp_source),
        .resp_data          (resp_data)
    );
    
    // Instantiate the stimulus generator
    tb_tl_stimulus stimulus (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Control signals
        .start_transaction  (start_transaction),
        .transaction_type   (transaction_type),
        
        // Transaction parameters for L1_0
        .address_l1_0       (address_l1_0),
        .size_l1_0          (size_l1_0),
        .source_l1_0        (source_l1_0),
        .write_data_l1_0    (write_data_l1_0),
        .write_mask_l1_0    (write_mask_l1_0),
        .read_data_l1_0     (read_data_l1_0),
        
        // Transaction parameters for L1_1
        .address_l1_1       (address_l1_1),
        .size_l1_1          (size_l1_1),
        .source_l1_1        (source_l1_1),
        .write_data_l1_1    (write_data_l1_1),
        .write_mask_l1_1    (write_mask_l1_1),
        .read_data_l1_1     (read_data_l1_1),
        
        // Transaction parameters for L1_2
        .address_l1_2       (address_l1_2),
        .size_l1_2          (size_l1_2),
        .source_l1_2        (source_l1_2),
        .write_data_l1_2    (write_data_l1_2),
        .write_mask_l1_2    (write_mask_l1_2),
        .read_data_l1_2     (read_data_l1_2),
        
        // Transaction parameters for L1_3
        .address_l1_3       (address_l1_3),
        .size_l1_3          (size_l1_3),
        .source_l1_3        (source_l1_3),
        .write_data_l1_3    (write_data_l1_3),
        .write_mask_l1_3    (write_mask_l1_3),
        .read_data_l1_3     (read_data_l1_3),
        
        // Control signals
        .transaction_done   (transaction_done),
        .mem_init_done      (mem_init_done),
        .test_done          (test_done),
        .all_tests_passed   (all_tests_passed)
    );
    
    // Instantiate the monitor
    tb_tl_monitor monitor (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Transaction signals for all L1 adapters
        .transaction_done   (transaction_done),
        .transaction_type   (transaction_type),
        
        // Transaction parameters for L1_0
        .address_l1_0       (address_l1_0),
        .write_data_l1_0    (write_data_l1_0),
        .read_data_l1_0     (read_data_l1_0),
        
        // Transaction parameters for L1_1
        .address_l1_1       (address_l1_1),
        .write_data_l1_1    (write_data_l1_1),
        .read_data_l1_1     (read_data_l1_1),
        
        // Transaction parameters for L1_2
        .address_l1_2       (address_l1_2),
        .write_data_l1_2    (write_data_l1_2),
        .read_data_l1_2     (read_data_l1_2),
        
        // Transaction parameters for L1_3
        .address_l1_3       (address_l1_3),
        .write_data_l1_3    (write_data_l1_3),
        .read_data_l1_3     (read_data_l1_3),
        
        // Control signals
        .test_done          (test_done),
        .mem_init_done      (mem_init_done),
        .all_tests_passed   (all_tests_passed)
    );

    // Initial block for waveform dumping only
    initial begin
        // Dump waveforms
        $dumpfile("tb_tl_top.vcd");
        $dumpvars(0, tb_tl_top);
    end

endmodule 
