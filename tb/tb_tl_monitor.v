`timescale 1ns / 1ps
`include "tl_pkg.vh"

// Module for monitoring signals in the TileLink testbench
module tb_tl_monitor #(
    parameter MEM_DEPTH = 1024 // Memory depth in 64-bit words
) (
    input clk,
    input rst_n,
    
    // TileLink L1 channel signals to monitor
    // Channel A signals (hierarchical access via DUT)
    input                        a_valid,
    input                        a_ready,
    input [2:0]                  a_opcode,
    input [`TL_SOURCE_BITS-1:0]  a_source,
    input [`TL_ADDR_BITS-1:0]    a_address,
    input [`TL_DATA_BYTES-1:0]   a_mask,
    input [`TL_DATA_BYTES*8-1:0] a_data,
    
    // Channel D signals (hierarchical access via DUT)
    input                        d_valid,
    input                        d_ready,
    input [3:0]                  d_opcode,
    input [`TL_SOURCE_BITS-1:0]  d_source,
    input [`TL_DATA_BYTES*8-1:0] d_data,
    
    // L2 adapter channel signals to monitor
    input                        l2_a_valid,
    input                        l2_a_ready,
    input [2:0]                  l2_a_opcode,
    input [`TL_SOURCE_BITS-1:0]  l2_a_source,
    input [`TL_ADDR_BITS-1:0]    l2_a_address,
    input [`TL_DATA_BYTES-1:0]   l2_a_mask,
    input [`TL_DATA_BYTES*8-1:0] l2_a_data,
    
    input                        l2_d_valid,
    input                        l2_d_ready,
    input [3:0]                  l2_d_opcode,
    input [`TL_SOURCE_BITS-1:0]  l2_d_source,
    input [`TL_DATA_BYTES*8-1:0] l2_d_data,
    
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
    
    // Interconnect monitoring
    integer interconnect_requests = 0;
    integer interconnect_responses = 0;
    integer l2_requests = 0;
    integer l2_responses = 0;
    
    // Local variables for loops and calculations
    integer i;
    integer word_addr;
    
    // Variables for data comparison
    reg [`TL_ADDR_BITS-1:0] ref_addr;
    reg [63:0] expected_data;
    
    // Transaction tracking - store last address for each source ID
    // This allows us to remember which address was used for each transaction by source ID
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
    
    // Monitor L1 -> Interconnect A channel transactions
    always @(posedge clk) begin
        if (rst_n && a_valid && a_ready) begin
            interconnect_requests = interconnect_requests + 1;
            
            case (a_opcode)
                `TL_A_GET: begin
                    get_sent = get_sent + 1;
                    // Store the address and opcode associated with this source ID for later verification
                    source_address[a_source] = a_address;
                    source_opcode[a_source] = a_opcode;
                    $display("[%0t ns] Monitor: L1->Interconnect GET request detected (addr=0x%h, source=%d)", 
                             $time, a_address, a_source);
                end
                
                `TL_A_PUTFULL: begin
                    put_full_sent = put_full_sent + 1;
                    // Store the address and opcode associated with this source ID for later verification
                    source_address[a_source] = a_address;
                    source_opcode[a_source] = a_opcode;
                    $display("[%0t ns] Monitor: L1->Interconnect PUTFULL request detected (addr=0x%h, data=0x%h, source=%d)", 
                             $time, a_address, a_data, a_source);
                    
                    // Update the reference model for PUTFULL
                    ref_model_mem[a_address >> 3] = a_data;
                    $display("[%0t ns] Monitor-REF: Updated reference memory at addr=0x%h with data=0x%h", 
                             $time, a_address, a_data);
                end
                
                `TL_A_PUTPARTIAL: begin
                    put_partial_sent = put_partial_sent + 1;
                    // Store the address and opcode associated with this source ID for later verification
                    source_address[a_source] = a_address;
                    source_opcode[a_source] = a_opcode;
                    $display("[%0t ns] Monitor: L1->Interconnect PUTPARTIAL request detected (addr=0x%h, mask=0x%h, data=0x%h, source=%d)", 
                             $time, a_address, a_mask, a_data, a_source);
                    
                    // Update the reference model for PUTPARTIAL
                    // Get the word address (64-bit aligned)
                    word_addr = a_address >> 3;
                    
                    // Loop through each byte and update according to mask
                    for (i = 0; i < 8; i = i + 1) begin
                        if (a_mask[i]) begin
                            // Update only bytes where mask is set
                            ref_model_mem[word_addr][i*8 +: 8] = a_data[i*8 +: 8];
                        end
                    end
                    
                    $display("[%0t ns] Monitor-REF: Updated reference memory at addr=0x%h with masked data, result=0x%h", 
                             $time, a_address, ref_model_mem[word_addr]);
                end
                
                default: $display("[%0t ns] Monitor: Unknown L1->Interconnect A opcode: %d", $time, a_opcode);
            endcase
        end
    end
    
    // Monitor Interconnect -> L1 D channel transactions
    always @(posedge clk) begin
        if (rst_n && d_valid && d_ready) begin
            interconnect_responses = interconnect_responses + 1;
            
            case (d_opcode)
                `TL_D_ACCESSACKDATA: begin
                    get_ack = get_ack + 1;
                    transactions_count = transactions_count + 1;
                    $display("[%0t ns] Monitor: Interconnect->L1 ACCESSACKDATA response detected (data=0x%h, source=%d)", 
                             $time, d_data, d_source);
                    
                    // Verify original opcode was GET
                    if (source_opcode[d_source] != `TL_A_GET) begin
                        $display("[%0t ns] Monitor-CHECK: *** PROTOCOL ERROR *** Expected GET request for source %d but received opcode %d", 
                                 $time, d_source, source_opcode[d_source]);
                    end
                    
                    // Compare with reference model for GET operation
                    // Look up the address that was used for this source ID
                    ref_addr = source_address[d_source];
                    expected_data = ref_model_mem[ref_addr >> 3];
                    
                    $display("[%0t ns] Monitor-REF: Expecting data=0x%h from reference memory at addr=0x%h (source=%d)", 
                             $time, expected_data, ref_addr, d_source);
                    
                    if (d_data === expected_data) begin
                        $display("[%0t ns] Monitor-CHECK: Data match for GET response: expected=0x%h, actual=0x%h", 
                                 $time, expected_data, d_data);
                        test_passed = test_passed + 1;
                    end else begin
                        $display("[%0t ns] Monitor-CHECK: *** DATA MISMATCH *** for GET response: expected=0x%h, actual=0x%h", 
                                 $time, expected_data, d_data);
                    end
                end
                
                `TL_D_ACCESSACK: begin
                    transactions_count = transactions_count + 1;
                    
                    // Check which type of request this is acknowledging
                    if (source_opcode[d_source] == `TL_A_PUTFULL) begin
                        put_full_ack = put_full_ack + 1;
                        test_passed = test_passed + 1;
                        $display("[%0t ns] Monitor: Interconnect->L1 ACCESSACK for PUTFULL detected (source=%d)", 
                                 $time, d_source);
                    end 
                    else if (source_opcode[d_source] == `TL_A_PUTPARTIAL) begin
                        put_partial_ack = put_partial_ack + 1;
                        test_passed = test_passed + 1;
                        $display("[%0t ns] Monitor: Interconnect->L1 ACCESSACK for PUTPARTIAL detected (source=%d)", 
                                 $time, d_source);
                    end 
                    else begin
                        $display("[%0t ns] Monitor: Unexpected Interconnect->L1 ACCESSACK (source=%d, original opcode=%d)", 
                                 $time, d_source, source_opcode[d_source]);
                    end
                end
                
                default: $display("[%0t ns] Monitor: Unknown Interconnect->L1 D opcode: %d", $time, d_opcode);
            endcase
        end
    end
    
    // Monitor Interconnect -> L2 A channel transactions
    always @(posedge clk) begin
        if (rst_n && l2_a_valid && l2_a_ready) begin
            l2_requests = l2_requests + 1;
            
            case (l2_a_opcode)
                `TL_A_GET: begin
                    $display("[%0t ns] Monitor: Interconnect->L2 GET request detected (addr=0x%h, source=%d)", 
                             $time, l2_a_address, l2_a_source);
                    
                    // Verify address matches L1 request
                    ref_addr = source_address[l2_a_source];
                    if (l2_a_address != ref_addr) begin
                        $display("[%0t ns] Monitor-CHECK: *** ADDRESS MISMATCH *** L2 GET address=0x%h doesn't match L1 address=0x%h", 
                                 $time, l2_a_address, ref_addr);
                    end
                end
                
                `TL_A_PUTFULL: begin
                    $display("[%0t ns] Monitor: Interconnect->L2 PUTFULL request detected (addr=0x%h, data=0x%h, source=%d)", 
                             $time, l2_a_address, l2_a_data, l2_a_source);
                    
                    // Verify data and address match L1 request
                    ref_addr = source_address[l2_a_source];
                    if (l2_a_address != ref_addr) begin
                        $display("[%0t ns] Monitor-CHECK: *** ADDRESS MISMATCH *** L2 PUTFULL address=0x%h doesn't match L1 address=0x%h", 
                                 $time, l2_a_address, ref_addr);
                    end
                end
                
                `TL_A_PUTPARTIAL: begin
                    $display("[%0t ns] Monitor: Interconnect->L2 PUTPARTIAL request detected (addr=0x%h, mask=0x%h, data=0x%h, source=%d)", 
                             $time, l2_a_address, l2_a_mask, l2_a_data, l2_a_source);
                    
                    // Verify address matches L1 request
                    ref_addr = source_address[l2_a_source];
                    if (l2_a_address != ref_addr) begin
                        $display("[%0t ns] Monitor-CHECK: *** ADDRESS MISMATCH *** L2 PUTPARTIAL address=0x%h doesn't match L1 address=0x%h", 
                                 $time, l2_a_address, ref_addr);
                    end
                end
                
                default: $display("[%0t ns] Monitor: Unknown Interconnect->L2 A opcode: %d", $time, l2_a_opcode);
            endcase
        end
    end
    
    // Monitor L2 -> Interconnect D channel transactions
    always @(posedge clk) begin
        if (rst_n && l2_d_valid && l2_d_ready) begin
            l2_responses = l2_responses + 1;
            
            case (l2_d_opcode)
                `TL_D_ACCESSACKDATA: begin
                    $display("[%0t ns] Monitor: L2->Interconnect ACCESSACKDATA response detected (data=0x%h, source=%d)", 
                             $time, l2_d_data, l2_d_source);
                    
                    // Verify response data is correct
                    ref_addr = source_address[l2_d_source];
                    expected_data = ref_model_mem[ref_addr >> 3];
                    
                    if (l2_d_data !== expected_data) begin
                        $display("[%0t ns] Monitor-CHECK: *** L2 DATA MISMATCH *** for GET response: expected=0x%h, actual=0x%h", 
                                 $time, expected_data, l2_d_data);
                    end
                end
                
                `TL_D_ACCESSACK: begin
                    $display("[%0t ns] Monitor: L2->Interconnect ACCESSACK detected (source=%d)", 
                             $time, l2_d_source);
                end
                
                default: $display("[%0t ns] Monitor: Unknown L2->Interconnect D opcode: %d", $time, l2_d_opcode);
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
        $display("GET requests sent: %d, ACKs received: %d", get_sent, get_ack);
        $display("PUTFULL requests sent: %d, ACKs received: %d", put_full_sent, put_full_ack);
        $display("PUTPARTIAL requests sent: %d, ACKs received: %d", put_partial_sent, put_partial_ack);
        $display("Total L1->Interconnect requests: %d", interconnect_requests);
        $display("Total Interconnect->L1 responses: %d", interconnect_responses);
        $display("Total Interconnect->L2 requests: %d", l2_requests);
        $display("Total L2->Interconnect responses: %d", l2_responses);
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