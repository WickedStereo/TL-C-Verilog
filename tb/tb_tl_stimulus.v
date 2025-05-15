`timescale 1ns / 1ps
`include "tl_pkg.vh"

// Ultra-simplified TileLink stimulus module
// Contains just a single GET operation test case
module tb_tl_stimulus (
    // Clock and reset
    output reg         clk,
    output reg         rst_n,
    
    // Control signals for L1 adapter
    output reg [3:0]  start_transaction,  // Pulse to start a new transaction
    output reg [7:0]  transaction_type,   // 2 bits per L1 adapter
    
    // Transaction parameters for L1_0 (only using L1_0)
    output reg [`TL_ADDR_BITS-1:0]     address_l1_0,
    output reg [`TL_SIZE_BITS-1:0]     size_l1_0,
    output reg [`TL_SOURCE_BITS-1:0]   source_l1_0,
    output reg [`TL_DATA_BYTES*8-1:0]  write_data_l1_0,
    output reg [`TL_DATA_BYTES-1:0]    write_mask_l1_0,
    input      [`TL_DATA_BYTES*8-1:0]  read_data_l1_0,
    
    // Unused L1 ports - kept for interface compatibility
    output reg [`TL_ADDR_BITS-1:0]     address_l1_1,
    output reg [`TL_SIZE_BITS-1:0]     size_l1_1,
    output reg [`TL_SOURCE_BITS-1:0]   source_l1_1,
    output reg [`TL_DATA_BYTES*8-1:0]  write_data_l1_1,
    output reg [`TL_DATA_BYTES-1:0]    write_mask_l1_1,
    input      [`TL_DATA_BYTES*8-1:0]  read_data_l1_1,
    
    output reg [`TL_ADDR_BITS-1:0]     address_l1_2,
    output reg [`TL_SIZE_BITS-1:0]     size_l1_2,
    output reg [`TL_SOURCE_BITS-1:0]   source_l1_2,
    output reg [`TL_DATA_BYTES*8-1:0]  write_data_l1_2,
    output reg [`TL_DATA_BYTES-1:0]    write_mask_l1_2,
    input      [`TL_DATA_BYTES*8-1:0]  read_data_l1_2,
    
    output reg [`TL_ADDR_BITS-1:0]     address_l1_3,
    output reg [`TL_SIZE_BITS-1:0]     size_l1_3,
    output reg [`TL_SOURCE_BITS-1:0]   source_l1_3,
    output reg [`TL_DATA_BYTES*8-1:0]  write_data_l1_3,
    output reg [`TL_DATA_BYTES-1:0]    write_mask_l1_3,
    input      [`TL_DATA_BYTES*8-1:0]  read_data_l1_3,
    
    // Control signals
    input [3:0]  transaction_done,
    input        mem_init_done,
    output reg   test_done,
    output reg   all_tests_passed
);
    
    // Parameters
    localparam CLK_PERIOD = 10; // 10ns period (100MHz clock)
    
    // Transaction types
    localparam TX_GET = 2'b00;
    localparam TX_PUTFULL = 2'b01;
    localparam TX_PUTPARTIAL = 2'b10;
    
    // Simplified state machine with just two test states
    localparam S_RESET = 0;   // Initial reset
    localparam S_INIT = 1;    // Initialize memory
    localparam S_TEST = 2;    // Run the single test
    localparam S_DONE = 3;    // Test finished
    
    reg [1:0] state;
    reg [7:0] counter;
    
    // Generate clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Initialize all signals
    initial begin
        // Initialize outputs
        rst_n = 0;
        start_transaction = 4'b0000;
        transaction_type = 8'h00;
        address_l1_0 = 0;
        size_l1_0 = 0;
        source_l1_0 = 0;
        write_data_l1_0 = 0;
        write_mask_l1_0 = 0;
        
        // Initialize unused ports to avoid X values
        address_l1_1 = 0;
        size_l1_1 = 0;
        source_l1_1 = 0;
        write_data_l1_1 = 0;
        write_mask_l1_1 = 0;
        address_l1_2 = 0;
        size_l1_2 = 0;
        source_l1_2 = 0;
        write_data_l1_2 = 0;
        write_mask_l1_2 = 0;
        address_l1_3 = 0;
        size_l1_3 = 0;
        source_l1_3 = 0;
        write_data_l1_3 = 0;
        write_mask_l1_3 = 0;
        
        test_done = 0;
        all_tests_passed = 0;
        state = S_RESET;
        counter = 0;
    end
    
    // Simple timeout to prevent infinite simulation
    initial begin
        #10000 // 10,000 time units timeout
        if (!test_done) begin
            $display("\n*** SIMULATION TIMEOUT ***\n");
            $finish;
        end
    end
    
    // Main state machine
    always @(posedge clk) begin
        // Default: clear the start_transaction pulse
        start_transaction <= 4'b0000;
        
        case (state)
            S_RESET: begin
                // Assert reset for 10 cycles
                counter <= counter + 1;
                if (counter >= 10) begin
                    rst_n <= 1;
                    counter <= 0;
                    state <= S_INIT;
                    $display("[%0t ns] Reset complete, initializing memory", $time);
                end else begin
                    rst_n <= 0;
                end
            end
            
            S_INIT: begin
                if (counter == 0) begin
                    // Initialize memory with data
                    $display("[%0t ns] Writing initial data to memory address 0x0", $time);
                    address_l1_0 <= 32'h0;
                    size_l1_0 <= 3; // 2^3 = 8 bytes
                    source_l1_0 <= 0; 
                    write_data_l1_0 <= 64'hABCD_1234_5678_9ABC;
                    write_mask_l1_0 <= 8'hFF; // All bytes enabled
                    transaction_type[1:0] <= TX_PUTFULL;
                    start_transaction[0] <= 1'b1;
                    counter <= counter + 1;
                end
                else if (transaction_done[0]) begin
                    $display("[%0t ns] Memory initialization complete", $time);
                    counter <= 0;
                    state <= S_TEST;
                end
                else if (counter >= 100) begin
                    // Timeout after waiting too long
                    $display("[%0t ns] Memory initialization timed out", $time);
                    counter <= 0;
                    state <= S_TEST;
                end
                else begin
                    counter <= counter + 1;
                end
            end
            
            S_TEST: begin
                if (counter == 0) begin
                    // Perform simple GET operation
                    $display("[%0t ns] TEST: Performing GET operation from address 0x0", $time);
                    address_l1_0 <= 32'h0; 
                    size_l1_0 <= 3; // 2^3 = 8 bytes
                    source_l1_0 <= 0;
                    transaction_type[1:0] <= TX_GET;
                    start_transaction[0] <= 1'b1;
                    counter <= counter + 1;
                end
                else if (transaction_done[0]) begin
                    // Verify the read data
                    $display("[%0t ns] TEST: GET transaction completed", $time);
                    $display("[%0t ns] TEST: Read data: 0x%h", $time, read_data_l1_0);
                    if (read_data_l1_0 == 64'hABCD_1234_5678_9ABC) begin
                        $display("[%0t ns] TEST PASSED: Data matches expected value", $time);
                        all_tests_passed <= 1;
                    end else begin
                        $display("[%0t ns] TEST FAILED: Expected 0x%h, Got 0x%h", $time, 
                                64'hABCD_1234_5678_9ABC, read_data_l1_0);
                    end
                    state <= S_DONE;
                end
                else if (counter >= 100) begin
                    // Timeout after waiting too long
                    $display("[%0t ns] TEST: GET transaction timed out", $time);
                    state <= S_DONE;
                end
                else begin
                    counter <= counter + 1;
                end
            end
            
            S_DONE: begin
                // Test complete
                $display("[%0t ns] Test complete", $time);
                test_done <= 1;
                
                // End simulation
                #10 $finish;
            end
        endcase
    end

endmodule 

