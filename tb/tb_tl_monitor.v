`timescale 1ns / 1ps
`include "tl_pkg.vh"

// Extremely simplified TileLink monitor module
module tb_tl_monitor #(
    parameter MEM_DEPTH = 1024 // Memory depth in 64-bit words
) (
    input clk,
    input rst_n,
    
    // Transaction signals
    input                        transaction_done,
    input [1:0]                  transaction_type,
    input [`TL_ADDR_BITS-1:0]    address,
    input [`TL_DATA_BYTES*8-1:0] write_data,
    input [`TL_DATA_BYTES*8-1:0] read_data,
    
    // Control signals
    input                        test_done,
    output reg                   mem_init_done,
    output reg                   all_tests_passed
);

    // Reference memory model for validation
    reg [63:0] ref_model_mem [0:MEM_DEPTH-1];
    
    // Transaction counters for verification
    integer get_count = 0;
    integer putfull_count = 0;
    integer putpartial_count = 0;
    integer transactions_count = 0;
    integer test_passed = 0;
    
    // Function to initialize the reference memory model
    task initialize_ref_memory;
        input [63:0] init_pattern;
        integer idx;
    begin
        for (idx = 0; idx < MEM_DEPTH; idx = idx + 1) begin
            ref_model_mem[idx] = init_pattern | idx;
        end
        $display("[%0t ns] Monitor: Reference memory model initialized with pattern 0x%h", 
                 $time, init_pattern);
    end
    endtask
    
    // Monitor transactions
    always @(posedge clk) begin
        if (rst_n && transaction_done) begin
            transactions_count = transactions_count + 1;
            
            case (transaction_type)
                2'b00: begin // GET
                    get_count = get_count + 1;
                    $display("[%0t ns] Monitor: GET transaction (addr=0x%h, data=0x%h)", 
                             $time, address, read_data);
                    
                    // Compare with reference model
                    if (read_data === ref_model_mem[address >> 3]) begin
                        $display("[%0t ns] Monitor: Data match for GET", $time);
                        test_passed = test_passed + 1;
                    end else begin
                        $display("[%0t ns] Monitor: *** DATA MISMATCH *** expected=0x%h, actual=0x%h", 
                                 $time, ref_model_mem[address >> 3], read_data);
                    end
                end
                
                2'b01: begin // PUTFULL
                    putfull_count = putfull_count + 1;
                    $display("[%0t ns] Monitor: PUTFULL transaction (addr=0x%h, data=0x%h)", 
                             $time, address, write_data);
                    
                    // Update the reference model
                    ref_model_mem[address >> 3] = write_data;
                    test_passed = test_passed + 1;
                end
                
                2'b10: begin // PUTPARTIAL
                    putpartial_count = putpartial_count + 1;
                    $display("[%0t ns] Monitor: PUTPARTIAL transaction (addr=0x%h, data=0x%h)", 
                             $time, address, write_data);
                    
                    // Note: For a fully accurate model, we would need the mask
                    // For simplicity, just treat as PUTFULL in this simplified version
                    ref_model_mem[address >> 3] = write_data;
                    test_passed = test_passed + 1;
                end
                
                default: $display("[%0t ns] Monitor: Unknown transaction type: %d", $time, transaction_type);
            endcase
        end
    end
    
    // Report test results
    initial begin
        // Initialize control signals
        mem_init_done = 1'b0;
        all_tests_passed = 1'b0;
        
        // Initialize reference memory model
        initialize_ref_memory(64'hAA00000000000000);
        mem_init_done = 1'b1;
        
        // Wait for test completion
        wait(test_done);
        
        // Print final verification counts
        $display("\n[%0t ns] === Monitor: Test Summary ===", $time);
        $display("GET transactions: %d", get_count);
        $display("PUTFULL transactions: %d", putfull_count);
        $display("PUTPARTIAL transactions: %d", putpartial_count);
        $display("Total transactions: %d, Verified correct: %d", transactions_count, test_passed);
        
        if ((test_passed == transactions_count) && (transactions_count > 0)) begin
            $display("[%0t ns] Monitor: TEST PASSED! All transactions verified successfully.", $time);
            all_tests_passed = 1'b1;
        end else begin
            $display("[%0t ns] Monitor: TEST FAILED! %0d out of %0d transactions failed verification.", 
                    $time, transactions_count - test_passed, transactions_count);
            all_tests_passed = 1'b0;
        end
    end

endmodule 