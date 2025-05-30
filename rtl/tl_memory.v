`timescale 1ns / 1ps

`include "tl_pkg.vh"

// TileLink memory module with configurable delay
module tl_memory (
    input clk,
    input rst_n,
    
    // Memory interface
    input                           write_valid,
    input [`TL_ADDR_BITS-1:0]       write_addr,
    input [`TL_DATA_BYTES*8-1:0]    write_data,
    input [`TL_DATA_BYTES-1:0]      write_mask,
    output reg                      write_ready,
    
    input                           read_valid,
    input [`TL_ADDR_BITS-1:0]       read_addr,
    output reg [`TL_DATA_BYTES*8-1:0] read_data,
    output reg                      read_data_valid,
    
    // Memory monitoring outputs (for testbench)
    output reg                      mem_write_valid,
    output reg [`TL_ADDR_BITS-1:0]  mem_write_addr,
    output reg [`TL_DATA_BYTES*8-1:0] mem_write_data,
    output reg [`TL_DATA_BYTES-1:0] mem_write_mask,
    
    output reg                      mem_read_valid,
    output reg [`TL_ADDR_BITS-1:0]  mem_read_addr,
    output reg [`TL_DATA_BYTES*8-1:0] mem_read_data
);

    // Memory size parameters
    localparam MEM_SIZE = 1024;             // Memory size in 64-bit words
    localparam MEM_ADDR_BITS = 10;          // log2(MEM_SIZE)
    
    // Delay parameters
    localparam DELAY_CYCLES = 5;            // Configurable delay cycles for read/write operations
    
    // Memory array
    reg [`TL_DATA_BYTES*8-1:0] mem [MEM_SIZE-1:0];
    
    // State machine for read/write operations with delay
    localparam S_IDLE     = 2'b00;
    localparam S_READ     = 2'b01;
    localparam S_WRITE    = 2'b10;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] delay_counter;
    reg [`TL_ADDR_BITS-1:0] pending_addr;
    reg [`TL_DATA_BYTES*8-1:0] pending_write_data;
    reg [`TL_DATA_BYTES-1:0] pending_write_mask;
    
    // Temporary variables for memory operations
    reg [`TL_DATA_BYTES*8-1:0] current_mem_val;
    reg [`TL_DATA_BYTES*8-1:0] next_mem_val;
    
    // Initialize memory (in simulation)
    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            mem[i] = 64'hAA00000000000000 | i;
        end
    end
    
    // 1. State register and counter updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            delay_counter <= 4'd0;
            pending_addr <= {`TL_ADDR_BITS{1'b0}};
            pending_write_data <= {(`TL_DATA_BYTES*8){1'b0}};
            pending_write_mask <= {`TL_DATA_BYTES{1'b0}};
            
            // Reset output signals
            read_data <= {(`TL_DATA_BYTES*8){1'b0}};
            read_data_valid <= 1'b0;
            write_ready <= 1'b0;
            
            // Reset monitoring outputs
            mem_write_valid <= 1'b0;
            mem_read_valid <= 1'b0;
            mem_write_addr <= {`TL_ADDR_BITS{1'b0}};
            mem_read_addr <= {`TL_ADDR_BITS{1'b0}};
            mem_write_data <= {(`TL_DATA_BYTES*8){1'b0}};
            mem_read_data <= {(`TL_DATA_BYTES*8){1'b0}};
            mem_write_mask <= {`TL_DATA_BYTES{1'b0}};
        end else begin
            state <= next_state;
            
            // Default values for outputs
            read_data_valid <= 1'b0;
            write_ready <= 1'b0;
            mem_write_valid <= 1'b0;
            mem_read_valid <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    delay_counter <= 4'd0;
                    
                    // Capture request parameters
                    if (read_valid) begin
                        pending_addr <= read_addr;
                    end else if (write_valid) begin
                        pending_addr <= write_addr;
                        pending_write_data <= write_data;
                        pending_write_mask <= write_mask;
                    end
                end
                
                S_READ, S_WRITE: begin
                    if (delay_counter >= DELAY_CYCLES) begin
                        delay_counter <= 4'd0;
                        
                        if (state == S_READ) begin
                            // Perform read operation after delay
                            read_data <= mem[pending_addr[MEM_ADDR_BITS+2:3]]; // Convert to word address
                            read_data_valid <= 1'b1;
                            
                            // Set monitoring outputs for read
                            mem_read_valid <= 1'b1;
                            mem_read_addr <= pending_addr;
                            mem_read_data <= mem[pending_addr[MEM_ADDR_BITS+2:3]];
                            
                            $display("[%0t ns] Memory: Read complete (Addr: 0x%h, Data: 0x%h)",
                                     $time, pending_addr, mem[pending_addr[MEM_ADDR_BITS+2:3]]);
                        end else begin
                            // Perform write operation after delay
                            // Current value from memory
                            current_mem_val = mem[pending_addr[MEM_ADDR_BITS+2:3]];
                            next_mem_val = current_mem_val;
                            
                            // Apply byte mask
                            for (i = 0; i < `TL_DATA_BYTES; i = i + 1) begin
                                if (pending_write_mask[i]) begin
                                    next_mem_val[i*8 +: 8] = pending_write_data[i*8 +: 8];
                                end
                            end
                            
                            // Update memory
                            mem[pending_addr[MEM_ADDR_BITS+2:3]] = next_mem_val;
                            write_ready <= 1'b1;
                            
                            // Set monitoring outputs for write
                            mem_write_valid <= 1'b1;
                            mem_write_addr <= pending_addr;
                            mem_write_data <= next_mem_val;
                            mem_write_mask <= pending_write_mask;
                            
                            $display("[%0t ns] Memory: Write complete (Addr: 0x%h, Data: 0x%h, Mask: 0x%h)",
                                     $time, pending_addr, next_mem_val, pending_write_mask);
                        end
                    end else begin
                        delay_counter <= delay_counter + 1;
                    end
                end
                
                default: begin
                    // Default case for unused state values
                    delay_counter <= 4'd0;
                end
            endcase
        end
    end
    
    // 2. Next state logic
    always @(*) begin
        // Default assignment
        next_state = state;
        
        case (state)
            S_IDLE: begin
                if (read_valid) begin
                    next_state = S_READ;
                    $display("[%0t ns] Memory: Starting read operation with %0d cycle delay (Addr: 0x%h)",
                             $time, DELAY_CYCLES, read_addr);
                end else if (write_valid) begin
                    next_state = S_WRITE;
                    $display("[%0t ns] Memory: Starting write operation with %0d cycle delay (Addr: 0x%h)",
                             $time, DELAY_CYCLES, write_addr);
                end
            end
            
            S_READ: begin
                if (delay_counter >= DELAY_CYCLES) begin
                    next_state = S_IDLE;
                end
            end
            
            S_WRITE: begin
                if (delay_counter >= DELAY_CYCLES) begin
                    next_state = S_IDLE;
                end
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
endmodule 