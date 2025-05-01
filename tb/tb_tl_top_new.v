`timescale 1ns / 1ps
`include "tl_pkg.vh"

module tb_tl_top_new;

    // Parameters
    localparam CLK_PERIOD = 10; // Clock period in ns
    localparam MEM_DEPTH = 1024; // Memory depth in 64-bit words

    // Common signals
    reg clk;
    reg rst_n;
    integer i; // Variable for loop
    
    // Test control signals
    wire test_done;
    reg mem_init_done_reg;
    wire mem_init_done;
    wire all_tests_passed;

    // Connect reg to wire for mem_init_done
    assign mem_init_done = mem_init_done_reg;

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

    // Clock generation
    always begin
        clk = 1'b0;
        #(CLK_PERIOD / 2);
        clk = 1'b1;
        #(CLK_PERIOD / 2);
    end
    
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
        .test_done          (test_done)
    );
    
    // Instantiate the monitor
    tb_tl_monitor #(
        .MEM_DEPTH          (MEM_DEPTH)
    ) monitor (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // TileLink signals from DUT to monitor - L1 side
        .a_valid            (dut.l1_a_valid),
        .a_ready            (dut.l1_a_ready),
        .a_opcode           (dut.l1_a_opcode),
        .a_source           (dut.l1_a_source),
        .a_address          (dut.l1_a_address),
        .a_mask             (dut.l1_a_mask),
        .a_data             (dut.l1_a_data),
        
        .d_valid            (dut.l1_d_valid),
        .d_ready            (dut.l1_d_ready),
        .d_opcode           (dut.l1_d_opcode),
        .d_source           (dut.l1_d_source),
        .d_data             (dut.l1_d_data),
        
        // TileLink signals from DUT to monitor - L2 side
        .l2_a_valid         (dut.l2_a_valid),
        .l2_a_ready         (dut.l2_a_ready),
        .l2_a_opcode        (dut.l2_a_opcode),
        .l2_a_source        (dut.l2_a_source),
        .l2_a_address       (dut.l2_a_address),
        .l2_a_mask          (dut.l2_a_mask),
        .l2_a_data          (dut.l2_a_data),
        
        .l2_d_valid         (dut.l2_d_valid),
        .l2_d_ready         (dut.l2_d_ready),
        .l2_d_opcode        (dut.l2_d_opcode),
        .l2_d_source        (dut.l2_d_source),
        .l2_d_data          (dut.l2_d_data),
        
        // Control signals
        .transaction_done   (transaction_done),
        .test_done          (test_done),
        .mem_init_done      (mem_init_done),
        .all_tests_passed   (all_tests_passed)
    );

    // Reset generation and simulation sequence
    initial begin
        $display("[%0t ns] Starting Testbench for tl_top", $time);

        // Dump waveforms
        $dumpfile("tb_tl_top_new.vcd");
        $dumpvars(0, tb_tl_top_new); 

        // Memory is now initialized inside the memory module
        $display("[%0t ns] Memory already initialized inside the memory module", $time);
        mem_init_done_reg = 1'b1;

        // Assert reset
        rst_n = 1'b0;
        
        // Apply reset for a few cycles
        repeat (5) @(posedge clk);
        rst_n = 1'b1; // Deassert reset
        $display("[%0t ns] Reset deasserted", $time);

        // Wait for the test to complete
        wait(test_done);
        
        // Allow time for the monitor to print test results
        repeat(10) @(posedge clk);
        
        // End simulation
        if (all_tests_passed) begin
            $display("[%0t ns] All tests passed successfully!", $time);
        end else begin
            $display("[%0t ns] Some tests failed, check log for details", $time);
        end
        
        $display("[%0t ns] Simulation finished", $time);
        $finish;
    end

endmodule 