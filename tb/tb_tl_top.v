`timescale 1ns / 1ps
`include "tl_pkg.vh"

module tb_tl_top;

    // Common signals for DUT
    wire clk;
    wire rst_n;
    
    // Control signals for L1 adapter
    wire        start_transaction;  // Pulse to start a new transaction
    wire [1:0]  transaction_type;   // 0: GET, 1: PUTFULL, 2: PUTPARTIAL, 3: reserved
    wire        transaction_done;   // Pulses when transaction is complete
    
    // Transaction parameters
    wire [`TL_ADDR_BITS-1:0]     address;    // Address for any operation
    wire [`TL_SIZE_BITS-1:0]     size;       // Size for any operation
    wire [`TL_SOURCE_BITS-1:0]   source;     // Source for any operation
    wire [`TL_DATA_BYTES*8-1:0]  write_data; // Data for PUT operations
    wire [`TL_DATA_BYTES-1:0]    write_mask; // Mask for PUTPARTIAL operation
    wire [`TL_DATA_BYTES*8-1:0]  read_data;  // Data returned from GET operation
    
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
        
        // Control signals
        .start_transaction  (start_transaction),
        .transaction_type   (transaction_type),
        .transaction_done   (transaction_done),
        
        // Transaction parameters
        .address            (address),
        .size               (size),
        .source             (source),
        .write_data         (write_data),
        .write_mask         (write_mask),
        .read_data          (read_data),
        
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
        
        // Transaction parameters
        .address            (address),
        .size               (size),
        .source             (source),
        .write_data         (write_data),
        .write_mask         (write_mask),
        .read_data          (read_data),
        
        // Control signals
        .transaction_done   (transaction_done),
        .mem_init_done      (mem_init_done),
        .test_done          (test_done),
        .all_tests_passed   (all_tests_passed)
    );
    
    // Instantiate the simplified monitor
    tb_tl_monitor monitor (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Transaction signals
        .transaction_done   (transaction_done),
        .transaction_type   (transaction_type),
        .address            (address),
        .write_data         (write_data),
        .read_data          (read_data),
        
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
