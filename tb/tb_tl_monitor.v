`timescale 1ns / 1ps
`include "tl_pkg.vh"

// Simplified TileLink monitor module
module tb_tl_monitor #(
    parameter MEM_DEPTH = 1024 // Memory depth in 64-bit words
) (
    input clk,
    input rst_n,
    
    // TileLink L1 channel signals to monitor (essential signals only)
    // Channel A signals 
    input                        a_valid,
    input                        a_ready,
    input [2:0]                  a_opcode,
    input [`TL_SOURCE_BITS-1:0]  a_source,
    input [`TL_ADDR_BITS-1:0]    a_address,
    input [`TL_DATA_BYTES-1:0]   a_mask,
    input [`TL_DATA_BYTES*8-1:0] a_data,
    
    // Channel D signals
    input                        d_valid,
    input                        d_ready,
    input [3:0]                  d_opcode,
    input [`TL_SOURCE_BITS-1:0]  d_source,
    input [`TL_DATA_BYTES*8-1:0] d_data,
    
    // Memory monitoring signals
    input                              mem_write_valid,
    input [`TL_ADDR_BITS-1:0]          mem_write_addr,
    input [`TL_DATA_BYTES*8-1:0]       mem_write_data,
    input [`TL_DATA_BYTES-1:0]         mem_write_mask,
    
    input                              mem_read_valid,
    input [`TL_ADDR_BITS-1:0]          mem_read_addr,
    input [`TL_DATA_BYTES*8-1:0]       mem_read_data,
    
    // Response monitoring signals
    input                              resp_valid,
    input [3:0]                        resp_opcode,
    input [`TL_SOURCE_BITS-1:0]        resp_source,
    input [`TL_DATA_BYTES*8-1:0]       resp_data,
    
    // Control signals
    input                        transaction_done,
    input                        test_done,
    output reg                   mem_init_done,
    output reg                   all_tests_passed
);

    // Reference memory model for validation
    reg [63:0] ref_model_mem [0:MEM_DEPTH-1];
    
    // Transaction counters for verification
    integer get_sent = 0;
    integer get_ack = 0;
    integer put_full_sent = 0;
    integer put_full_ack = 0;
    integer put_partial_sent = 0;
    integer put_partial_ack = 0;
    integer transactions_count = 0;
    integer test_passed = 0;
    
    // Memory access counters
    integer mem_writes = 0;
    integer mem_reads = 0;
    
    // Local variables for loops and calculations
    integer i;
    integer word_addr;
    
    // Variables for data comparison
    reg [`TL_ADDR_BITS-1:0] ref_addr;
    reg [63:0] expected_data;
    
    // Transaction tracking - store last address for each source ID
    reg [`TL_ADDR_BITS-1:0] source_address [0:(1<<`TL_SOURCE_BITS)-1];
    
    // Transaction type tracking for each source ID
    reg [2:0] source_opcode [0:(1<<`TL_SOURCE_BITS)-1];
    
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
                 
        // Initialize source address tracking
        for (idx = 0; idx < (1<<`TL_SOURCE_BITS); idx = idx + 1) begin
            source_address[idx] = 0;
            source_opcode[idx] = 0;
        end
    end
    endtask
    
    // Monitor A channel transactions
    always @(posedge clk) begin
        if (rst_n && a_valid && a_ready) begin
            case (a_opcode)
                `TL_A_GET: begin
                    get_sent = get_sent + 1;
                    source_address[a_source] = a_address;
                    source_opcode[a_source] = a_opcode;
                    $display("[%0t ns] Monitor: GET request (addr=0x%h, source=%d)", 
                             $time, a_address, a_source);
                end
                
                `TL_A_PUTFULL: begin
                    put_full_sent = put_full_sent + 1;
                    source_address[a_source] = a_address;
                    source_opcode[a_source] = a_opcode;
                    $display("[%0t ns] Monitor: PUTFULL request (addr=0x%h, data=0x%h, source=%d)", 
                             $time, a_address, a_data, a_source);
                    
                    // Update the reference model for PUTFULL
                    ref_model_mem[a_address >> 3] = a_data;
                end
                
                `TL_A_PUTPARTIAL: begin
                    put_partial_sent = put_partial_sent + 1;
                    source_address[a_source] = a_address;
                    source_opcode[a_source] = a_opcode;
                    $display("[%0t ns] Monitor: PUTPARTIAL request (addr=0x%h, mask=0x%h, data=0x%h, source=%d)", 
                             $time, a_address, a_mask, a_data, a_source);
                    
                    // Update the reference model for PUTPARTIAL
                    word_addr = a_address >> 3;
                    
                    // Loop through each byte and update according to mask
                    for (i = 0; i < 8; i = i + 1) begin
                        if (a_mask[i]) begin
                            // Update only bytes where mask is set
                            ref_model_mem[word_addr][i*8 +: 8] = a_data[i*8 +: 8];
                        end
                    end
                end
                
                default: $display("[%0t ns] Monitor: Unknown A opcode: %d", $time, a_opcode);
            endcase
        end
    end
    
    // Monitor D channel transactions
    always @(posedge clk) begin
        if (rst_n && d_valid && d_ready) begin
            case (d_opcode)
                `TL_D_ACCESSACKDATA: begin
                    get_ack = get_ack + 1;
                    transactions_count = transactions_count + 1;
                    $display("[%0t ns] Monitor: ACCESSACKDATA response (data=0x%h, source=%d)", 
                             $time, d_data, d_source);
                    
                    // Verify original opcode was GET
                    if (source_opcode[d_source] != `TL_A_GET) begin
                        $display("[%0t ns] Monitor: *** PROTOCOL ERROR *** Expected GET request for source %d", 
                                 $time, d_source);
                    end
                    
                    // Compare with reference model for GET operation
                    ref_addr = source_address[d_source];
                    expected_data = ref_model_mem[ref_addr >> 3];
                    
                    if (d_data === expected_data) begin
                        $display("[%0t ns] Monitor: Data match for GET: expected=0x%h", $time, expected_data);
                        test_passed = test_passed + 1;
                    } else begin
                        $display("[%0t ns] Monitor: *** DATA MISMATCH *** expected=0x%h, actual=0x%h", 
                                 $time, expected_data, d_data);
                    end
                end
                
                `TL_D_ACCESSACK: begin
                    transactions_count = transactions_count + 1;
                    
                    // Check which type of request this is acknowledging
                    if (source_opcode[d_source] == `TL_A_PUTFULL) begin
                        put_full_ack = put_full_ack + 1;
                        test_passed = test_passed + 1;
                        $display("[%0t ns] Monitor: ACCESSACK for PUTFULL (source=%d)", $time, d_source);
                    end 
                    else if (source_opcode[d_source] == `TL_A_PUTPARTIAL) begin
                        put_partial_ack = put_partial_ack + 1;
                        test_passed = test_passed + 1;
                        $display("[%0t ns] Monitor: ACCESSACK for PUTPARTIAL (source=%d)", $time, d_source);
                    end 
                    else begin
                        $display("[%0t ns] Monitor: Unexpected ACCESSACK (source=%d)", $time, d_source);
                    end
                end
                
                default: $display("[%0t ns] Monitor: Unknown D opcode: %d", $time, d_opcode);
            endcase
        end
    end
    
    // Monitor memory write signals
    always @(posedge clk) begin
        if (rst_n && mem_write_valid) begin
            mem_writes = mem_writes + 1;
            $display("[%0t ns] Monitor: Memory Write (addr=0x%h, data=0x%h, mask=0x%h)", 
                     $time, mem_write_addr, mem_write_data, mem_write_mask);
            
            // Verify memory write matches reference model
            word_addr = mem_write_addr >> 3;
            expected_data = ref_model_mem[word_addr];
            
            // For full writes, verify data
            if (mem_write_mask == 8'hFF) begin
                if (mem_write_data !== expected_data) begin
                    $display("[%0t ns] Monitor: *** MEMORY WRITE MISMATCH *** addr=0x%h, expected=0x%h, actual=0x%h", 
                             $time, mem_write_addr, expected_data, mem_write_data);
                end
            } 
            // For partial writes, verify only masked bytes
            else begin
                // Create expected data with masked bytes
                reg [63:0] masked_expected;
                masked_expected = 64'h0;
                
                for (i = 0; i < 8; i = i + 1) begin
                    if (mem_write_mask[i]) begin
                        // Check only bytes that are being written
                        if (mem_write_data[i*8 +: 8] !== expected_data[i*8 +: 8]) begin
                            $display("[%0t ns] Monitor: *** MEMORY WRITE BYTE %0d MISMATCH *** addr=0x%h, expected=0x%h, actual=0x%h", 
                                     $time, i, mem_write_addr, expected_data[i*8 +: 8], mem_write_data[i*8 +: 8]);
                        end
                    end
                end
            end
        end
    end
    
    // Monitor memory read signals
    always @(posedge clk) begin
        if (rst_n && mem_read_valid) begin
            mem_reads = mem_reads + 1;
            $display("[%0t ns] Monitor: Memory Read (addr=0x%h, data=0x%h)", 
                     $time, mem_read_addr, mem_read_data);
            
            // Verify memory read matches reference model
            word_addr = mem_read_addr >> 3;
            expected_data = ref_model_mem[word_addr];
            
            if (mem_read_data !== expected_data) begin
                $display("[%0t ns] Monitor: *** MEMORY READ MISMATCH *** addr=0x%h, expected=0x%h, actual=0x%h", 
                         $time, mem_read_addr, expected_data, mem_read_data);
            end
        end
    end
    
    // Monitor response signals
    always @(posedge clk) begin
        if (rst_n && resp_valid) begin
            $display("[%0t ns] Monitor: Response (opcode=0x%h, source=%d, data=0x%h)", 
                     $time, resp_opcode, resp_source, resp_data);
            
            // For data responses, check against reference model
            if (resp_opcode == `TL_D_ACCESSACKDATA) begin
                ref_addr = source_address[resp_source];
                expected_data = ref_model_mem[ref_addr >> 3];
                
                if (resp_data !== expected_data) begin
                    $display("[%0t ns] Monitor: *** RESPONSE DATA MISMATCH *** source=%d, expected=0x%h, actual=0x%h", 
                             $time, resp_source, expected_data, resp_data);
                end
            end
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
        $display("GET requests sent: %d, ACKs received: %d", get_sent, get_ack);
        $display("PUTFULL requests sent: %d, ACKs received: %d", put_full_sent, put_full_ack);
        $display("PUTPARTIAL requests sent: %d, ACKs received: %d", put_partial_sent, put_partial_ack);
        $display("Memory writes: %d, Memory reads: %d", mem_writes, mem_reads);
        $display("Total transactions: %d, Verified correct: %d", transactions_count, test_passed);
        
        if ((get_sent == get_ack) && 
            (put_full_sent == put_full_ack) && 
            (put_partial_sent == put_partial_ack) &&
            (test_passed == transactions_count) && 
            (transactions_count > 0)) begin
            $display("[%0t ns] Monitor: TEST PASSED! All transactions verified successfully.", $time);
            all_tests_passed = 1'b1;
        end else begin
            if (get_sent != get_ack)
                $display("[%0t ns] Monitor: TEST FAILED! GET requests/responses mismatch: sent=%d, ack=%d", 
                        $time, get_sent, get_ack);
            if (put_full_sent != put_full_ack)
                $display("[%0t ns] Monitor: TEST FAILED! PUTFULL requests/responses mismatch: sent=%d, ack=%d", 
                        $time, put_full_sent, put_full_ack);  
            if (put_partial_sent != put_partial_ack)
                $display("[%0t ns] Monitor: TEST FAILED! PUTPARTIAL requests/responses mismatch: sent=%d, ack=%d", 
                        $time, put_partial_sent, put_partial_ack);
            if (test_passed != transactions_count)
                $display("[%0t ns] Monitor: TEST FAILED! %0d out of %0d transactions failed verification.", 
                        $time, transactions_count - test_passed, transactions_count);
                
            all_tests_passed = 1'b0;
        end
    end

endmodule 