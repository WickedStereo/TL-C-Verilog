`timescale 1ns / 1ps
`include "tl_pkg.vh"

// Module for generating stimulus for the TileLink testbench
// This standalone version also generates clock and reset and controls simulation
module tb_tl_stimulus_standalone (
    // Clock and reset - outputs in this version
    output reg         clk,
    output reg         rst_n,
    
    // Control signals
    output reg         start_transaction,  // Pulse to start a new transaction
    output reg [1:0]   transaction_type,   // 0: GET, 1: PUTFULL, 2: PUTPARTIAL, 3: reserved
    
    // Transaction parameters
    output reg [`TL_ADDR_BITS-1:0]     address,    // Address for any operation
    output reg [`TL_SIZE_BITS-1:0]     size,       // Size for any operation
    output reg [`TL_SOURCE_BITS-1:0]   source,     // Source for any operation
    output reg [`TL_DATA_BYTES*8-1:0]  write_data, // Data for PUT operations
    output reg [`TL_DATA_BYTES-1:0]    write_mask, // Mask for PUTPARTIAL operation
    input [`TL_DATA_BYTES*8-1:0]       read_data,  // Data returned from GET operation
    
    // Testbench control signals
    input                              transaction_done,
    output reg                         mem_init_done,
    output reg                         test_done,
    
    // Additional input for test status - connected from monitor
    input                              all_tests_passed
);
    
    // Parameters
    localparam CLK_PERIOD = 10; // Clock period in ns
    
    // Transaction type constants
    localparam TX_GET           = 2'b00;
    localparam TX_PUTFULL       = 2'b01;
    localparam TX_PUTPARTIAL    = 2'b10;
    
    // Test case parameters
    localparam TEST_COUNT = 10;
    reg [3:0] current_test;
    
    // Storage for data read during GET operations for verification
    reg [`TL_DATA_BYTES*8-1:0] last_read_data;
    
    // Clock generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Initialize transaction parameters with default values
    task initialize_transaction_params;
    begin
        // Initialize transaction parameters
        start_transaction = 1'b0;
        transaction_type = TX_GET;
        
        address = 32'h0;
        size = `TL_SIZE_BITS'd3; // Default: 8 bytes
        source = `TL_SOURCE_BITS'd0;
        write_data = 64'h0;
        write_mask = 8'hFF; // Default: all bytes enabled
        
        current_test = 0;
        test_done = 1'b0;
        mem_init_done = 1'b0;
    end
    endtask
    
    // Execute a specific test case based on the test number
    task execute_test_case;
        input [3:0] test_num;
    begin
        // Initialize signals for this operation
        start_transaction = 1'b0;
        
        case (test_num)
            0: begin // Basic GET operation
                $display("[%0t ns] Stimulus: Test Case %0d - Basic GET operation", $time, test_num);
                address = 32'h1000;
                size = `TL_SIZE_BITS'd3; // 8 bytes
                source = `TL_SOURCE_BITS'd1;
                transaction_type = TX_GET;
            end
            
            1: begin // Basic PUTFULL operation
                $display("[%0t ns] Stimulus: Test Case %0d - Basic PUTFULL operation", $time, test_num);
                address = 32'h2000;
                size = `TL_SIZE_BITS'd3; // 8 bytes
                source = `TL_SOURCE_BITS'd2;
                write_data = 64'h11223344AABBCCDD;
                write_mask = 8'hFF; // All bytes
                transaction_type = TX_PUTFULL;
            end
            
            2: begin // Basic PUTPARTIAL operation
                $display("[%0t ns] Stimulus: Test Case %0d - Basic PUTPARTIAL operation", $time, test_num);
                address = 32'h3004;
                size = `TL_SIZE_BITS'd3; // 8 bytes
                source = `TL_SOURCE_BITS'd3;
                write_data = 64'hFFFFFFFF00000000;
                write_mask = 8'b11110000; // Upper 4 bytes
                transaction_type = TX_PUTPARTIAL;
            end
            
            3: begin // GET with different source ID
                $display("[%0t ns] Stimulus: Test Case %0d - GET with different source ID", $time, test_num);
                address = 32'h1008;
                size = `TL_SIZE_BITS'd3; // 8 bytes
                source = `TL_SOURCE_BITS'd4;
                transaction_type = TX_GET;
            end
            
            4: begin // PUTFULL to previously read address
                $display("[%0t ns] Stimulus: Test Case %0d - PUTFULL to previously read address", $time, test_num);
                address = 32'h1000;
                size = `TL_SIZE_BITS'd3;
                source = `TL_SOURCE_BITS'd5;
                write_data = 64'h9988776655443322;
                write_mask = 8'hFF; // All bytes
                transaction_type = TX_PUTFULL;
            end
            
            5: begin // PUTPARTIAL with different mask pattern
                $display("[%0t ns] Stimulus: Test Case %0d - PUTPARTIAL with different mask pattern", $time, test_num);
                address = 32'h2000;
                size = `TL_SIZE_BITS'd3;
                source = `TL_SOURCE_BITS'd6;
                write_data = 64'h00000000FFFFFFFF;
                write_mask = 8'b00001111; // Lower 4 bytes
                transaction_type = TX_PUTPARTIAL;
            end
            
            6: begin // GET to verify PUTPARTIAL result
                $display("[%0t ns] Stimulus: Test Case %0d - GET to verify PUTPARTIAL result", $time, test_num);
                address = 32'h2000;
                size = `TL_SIZE_BITS'd3;
                source = `TL_SOURCE_BITS'd7;
                transaction_type = TX_GET;
            end
            
            7: begin // PUTFULL to a new address
                $display("[%0t ns] Stimulus: Test Case %0d - PUTFULL to a new address", $time, test_num);
                address = 32'h4000;
                size = `TL_SIZE_BITS'd3;
                source = `TL_SOURCE_BITS'd8;
                write_data = 64'hAA55AA55AA55AA55;
                write_mask = 8'hFF; // All bytes
                transaction_type = TX_PUTFULL;
            end
            
            8: begin // PUTPARTIAL overlapping previous PUTFULL
                $display("[%0t ns] Stimulus: Test Case %0d - PUTPARTIAL overlapping previous PUTFULL", $time, test_num);
                address = 32'h4000;
                size = `TL_SIZE_BITS'd3;
                source = `TL_SOURCE_BITS'd9;
                write_data = 64'h00FFFF0000FFFF00;
                write_mask = 8'b01010101; // Alternating bytes
                transaction_type = TX_PUTPARTIAL;
            end
            
            9: begin // GET to verify combined PUTFULL+PUTPARTIAL result
                $display("[%0t ns] Stimulus: Test Case %0d - GET to verify combined PUTFULL+PUTPARTIAL result", $time, test_num);
                address = 32'h4000;
                size = `TL_SIZE_BITS'd3;
                source = `TL_SOURCE_BITS'd10;
                transaction_type = TX_GET;
            end
            
            default: begin
                $display("[%0t ns] Stimulus: Unknown test case %0d", $time, test_num);
            end
        endcase
        
        // Start the transaction after setting up the parameters
        @(posedge clk);
        start_transaction = 1'b1;
        @(posedge clk);
        start_transaction = 1'b0;
        
        // For GET operations, save the read data when transaction is done
        if (transaction_type == TX_GET) begin
            wait(transaction_done);
            last_read_data = read_data;
            $display("[%0t ns] Stimulus: GET operation completed, data read: 0x%h", $time, read_data);
        end
    end
    endtask
    
    // Initial sequence for stimulus generation - now also includes reset control
    initial begin
        // Initialize signals
        initialize_transaction_params();
        rst_n = 1'b0; // Start with reset asserted
        
        $display("[%0t ns] Stimulus: Starting Testbench for tl_top (No Top version)", $time);
        
        // Dump waveforms functionality is moved to the top module
        
        $display("[%0t ns] Stimulus: Starting with reset asserted", $time);
        
        // Apply reset for a few cycles
        repeat (5) @(posedge clk);
        rst_n = 1'b1; // Deassert reset
        $display("[%0t ns] Stimulus: Reset deasserted", $time);
        
        // Initialize memory
        mem_init_done = 1'b1;
        $display("[%0t ns] Stimulus: Memory initialization done", $time);
        
        // Small delay after reset
        repeat(3) @(posedge clk);
        
        $display("[%0t ns] Stimulus: Starting test sequence with %0d test cases", $time, TEST_COUNT);
        
        // Execute all test cases
        for (current_test = 0; current_test < TEST_COUNT; current_test = current_test + 1) begin
            // Execute test case
            execute_test_case(current_test);
            
            // Wait for transaction to complete before starting next test
            wait(transaction_done);
            repeat(3) @(posedge clk); // Add small delay between tests
        end
        
        // Test sequence complete
        repeat(5) @(posedge clk);
        test_done = 1'b1;
        $display("[%0t ns] Stimulus: Test sequence complete, executed %0d test cases", $time, TEST_COUNT);
        
        // Wait for results to be processed
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