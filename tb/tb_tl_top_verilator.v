`timescale 1ns / 1ps
`include "tl_pkg.vh"

module tb_tl_top_verilator(
    input clk,
    input rst_n
);

    // Control signals for L1 adapter
    reg         start_transaction;
    reg [1:0]   transaction_type;
    wire        transaction_done;
    
    // Transaction parameters
    reg [`TL_ADDR_BITS-1:0]     address;
    reg [`TL_SIZE_BITS-1:0]     size;
    reg [`TL_SOURCE_BITS-1:0]   source;
    reg [`TL_DATA_BYTES*8-1:0]  write_data;
    reg [`TL_DATA_BYTES-1:0]    write_mask;
    wire [`TL_DATA_BYTES*8-1:0] read_data;
    
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

    // Testbench state machine
    reg [3:0] test_state;
    reg [7:0] cycle_count;
    reg [3:0] current_test;
    
    // Transaction type constants
    localparam TX_GET           = 2'b00;
    localparam TX_PUTFULL       = 2'b01;
    localparam TX_PUTPARTIAL    = 2'b10;
    
    // Test states
    localparam ST_RESET         = 4'd0;
    localparam ST_INIT          = 4'd1;
    localparam ST_SETUP_TEST    = 4'd2;
    localparam ST_START_TRANS   = 4'd3;
    localparam ST_WAIT_DONE     = 4'd4;
    localparam ST_NEXT_TEST     = 4'd5;
    localparam ST_FINISH        = 4'd6;

    // Instantiate the DUT
    tl_top dut (
        .clk                (clk),
        .rst_n              (rst_n),
        
        .start_transaction  (start_transaction),
        .transaction_type   (transaction_type),
        .transaction_done   (transaction_done),
        
        .address            (address),
        .size               (size),
        .source             (source),
        .write_data         (write_data),
        .write_mask         (write_mask),
        .read_data          (read_data),
        
        .mem_write_valid    (mem_write_valid),
        .mem_write_addr     (mem_write_addr),
        .mem_write_data     (mem_write_data),
        .mem_write_mask     (mem_write_mask),
        
        .mem_read_valid     (mem_read_valid),
        .mem_read_addr      (mem_read_addr),
        .mem_read_data      (mem_read_data),
        
        .resp_valid         (resp_valid),
        .resp_opcode        (resp_opcode),
        .resp_source        (resp_source),
        .resp_data          (resp_data)
    );

    // Main testbench process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_state <= ST_RESET;
            cycle_count <= 0;
            current_test <= 0;
            start_transaction <= 0;
            transaction_type <= TX_GET;
            address <= 0;
            size <= 3; // 8 bytes
            source <= 0;
            write_data <= 0;
            write_mask <= 8'hFF;
        end else begin
            cycle_count <= cycle_count + 1;
            
            case (test_state)
                ST_RESET: begin
                    if (cycle_count >= 10) begin
                        test_state <= ST_INIT;
                        cycle_count <= 0;
                        $display("[%t] Starting Verilator testbench", $time);
                    end
                end
                
                ST_INIT: begin
                    if (cycle_count >= 5) begin
                        test_state <= ST_SETUP_TEST;
                        cycle_count <= 0;
                    end
                end
                
                ST_SETUP_TEST: begin
                    // Setup test parameters based on current_test
                    case (current_test)
                        0: begin // GET operation
                            $display("[%t] Test %0d: GET operation", $time, current_test);
                            transaction_type <= TX_GET;
                            address <= 32'h1000;
                            source <= 1;
                        end
                        1: begin // PUTFULL operation
                            $display("[%t] Test %0d: PUTFULL operation", $time, current_test);
                            transaction_type <= TX_PUTFULL;
                            address <= 32'h2000;
                            source <= 2;
                            write_data <= 64'h11223344AABBCCDD;
                            write_mask <= 8'hFF;
                        end
                        2: begin // PUTPARTIAL operation
                            $display("[%t] Test %0d: PUTPARTIAL operation", $time, current_test);
                            transaction_type <= TX_PUTPARTIAL;
                            address <= 32'h3000;
                            source <= 3;
                            write_data <= 64'hFFFFFFFF00000000;
                            write_mask <= 8'b11110000;
                        end
                        3: begin // Another GET
                            $display("[%t] Test %0d: GET from written address", $time, current_test);
                            transaction_type <= TX_GET;
                            address <= 32'h2000;
                            source <= 4;
                        end
                        default: begin
                            test_state <= ST_FINISH;
                        end
                    endcase
                    
                    if (current_test < 4) begin
                        test_state <= ST_START_TRANS;
                        cycle_count <= 0;
                    end
                end
                
                ST_START_TRANS: begin
                    start_transaction <= 1;
                    test_state <= ST_WAIT_DONE;
                    cycle_count <= 0;
                end
                
                ST_WAIT_DONE: begin
                    start_transaction <= 0;
                    
                    // Simple timeout mechanism instead of wait
                    if (transaction_done) begin
                        $display("[%t] Transaction %0d completed", $time, current_test);
                        if (transaction_type == TX_GET) begin
                            $display("[%t] Read data: 0x%h", $time, read_data);
                        end
                        test_state <= ST_NEXT_TEST;
                        cycle_count <= 0;
                    end else if (cycle_count >= 100) begin
                        $display("[%t] Transaction %0d timeout", $time, current_test);
                        test_state <= ST_NEXT_TEST;
                        cycle_count <= 0;
                    end
                end
                
                ST_NEXT_TEST: begin
                    current_test <= current_test + 1;
                    test_state <= ST_SETUP_TEST;
                    cycle_count <= 0;
                end
                
                ST_FINISH: begin
                    if (cycle_count >= 10) begin
                        $display("[%t] Testbench completed", $time);
                        $finish;
                    end
                end
                
                default: test_state <= ST_RESET;
            endcase
        end
    end

    // Reset and initialization - will be controlled by C++ wrapper
    // Remove automatic reset generation

    // Waveform dumping for Verilator
    initial begin
        $dumpfile("tb_tl_top_verilator.vcd");
        $dumpvars(0, tb_tl_top_verilator);
    end

endmodule 