`timescale 1ns / 1ps
`include "tl_pkg.vh"

// Ultra-simplified TileLink monitor module
module tb_tl_monitor #(
    parameter MEM_DEPTH = 1024 // Memory depth in 64-bit words
) (
    input clk,
    input rst_n,
    
    // Transaction signals
    input [3:0]  transaction_done,
    input [7:0]  transaction_type,
    
    // Transaction parameters for L1_0
    input [`TL_ADDR_BITS-1:0]     address_l1_0,
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_0,
    input [`TL_DATA_BYTES*8-1:0]  read_data_l1_0,
    
    // Transaction parameters for L1_1 (unused in simplified testbench)
    input [`TL_ADDR_BITS-1:0]     address_l1_1,
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_1,
    input [`TL_DATA_BYTES*8-1:0]  read_data_l1_1,
    
    // Transaction parameters for L1_2 (unused in simplified testbench)
    input [`TL_ADDR_BITS-1:0]     address_l1_2,
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_2,
    input [`TL_DATA_BYTES*8-1:0]  read_data_l1_2,
    
    // Transaction parameters for L1_3 (unused in simplified testbench)
    input [`TL_ADDR_BITS-1:0]     address_l1_3,
    input [`TL_DATA_BYTES*8-1:0]  write_data_l1_3,
    input [`TL_DATA_BYTES*8-1:0]  read_data_l1_3,
    
    // Control signals
    input         test_done,
    output reg    mem_init_done,
    output reg    all_tests_passed
);

    // Reference memory model for validation
    reg [63:0] ref_model_mem [0:MEM_DEPTH-1];
    
    // Transaction type constants
    localparam TX_GET         = 2'b00;
    localparam TX_PUTFULL     = 2'b01;
    localparam TX_PUTPARTIAL  = 2'b10;
    
    // Initialize memory model and flags
    initial begin
        // Initialize memory to zeros
        for (integer i = 0; i < MEM_DEPTH; i = i + 1) begin
            ref_model_mem[i] = 0;
        end
        
        mem_init_done = 1; // Start with memory initialized
        all_tests_passed = 1;  // Assume pass until proven otherwise
        
        $display("[%0t ns] Monitor initialized", $time);
    end
    
    // Monitor L1_0 transactions
    always @(posedge clk) begin
        if (rst_n && transaction_done[0]) begin
            // Log the transaction based on type
            case (transaction_type[1:0])
                TX_GET: begin
                    $display("[%0t ns] Monitor: L1_0 completed GET from address 0x%h, read data: 0x%h", 
                             $time, address_l1_0, read_data_l1_0);
                    
                    // Compare with reference model
                    if (read_data_l1_0 === ref_model_mem[address_l1_0 >> 3]) begin
                        $display("[%0t ns] Monitor: Data match OK for GET", $time);
                    end else begin
                        $display("[%0t ns] Monitor: DATA MISMATCH! Expected=0x%h, actual=0x%h", 
                                 $time, ref_model_mem[address_l1_0 >> 3], read_data_l1_0);
                        all_tests_passed = 0;
                    end
                end
                
                TX_PUTFULL: begin
                    $display("[%0t ns] Monitor: L1_0 completed PUTFULL to address 0x%h, data: 0x%h", 
                             $time, address_l1_0, write_data_l1_0);
                    
                    // Update reference memory model
                    ref_model_mem[address_l1_0 >> 3] = write_data_l1_0;
                end
                
                TX_PUTPARTIAL: begin
                    $display("[%0t ns] Monitor: L1_0 completed PUTPARTIAL to address 0x%h", $time, address_l1_0);
                    
                    // Simplified implementation - would need mask for real implementation
                    ref_model_mem[address_l1_0 >> 3] = write_data_l1_0;
                end
                
                default: $display("[%0t ns] Monitor: Unknown transaction type", $time);
            endcase
        end
    end
    
    // Add a timeout in case simulation hangs
    initial begin
        #10000 // 10,000 time units
        if (!test_done) begin
            $display("\n*** MONITOR TIMEOUT ***\n");
            $finish;
        end
    end

endmodule 