`timescale 1ns / 1ps

`include "tl_pkg.vh"

// L2 adapter module implementing TileLink Slave interface
module tl_l2_adapter (
    input clk,
    input rst_n,

    // TileLink Interface (Slave Port)
    // Channel A (Master -> Slave)
    input              a_valid,
    output reg         a_ready,
    input [2:0]        a_opcode,
    input [2:0]        a_param,
    input [`TL_SIZE_BITS-1:0] a_size,
    input [`TL_SOURCE_BITS-1:0] a_source,
    input [`TL_ADDR_BITS-1:0] a_address,
    input [`TL_DATA_BYTES-1:0] a_mask,
    input [`TL_DATA_BYTES*8-1:0] a_data,

    // Channel D (Slave -> Master)
    output reg         d_valid,
    input              d_ready,
    output reg [3:0]   d_opcode,
    output reg [1:0]   d_param,
    output reg [`TL_SIZE_BITS-1:0] d_size,
    output reg [`TL_SOURCE_BITS-1:0] d_source,
    output reg [`TL_SINK_BITS-1:0] d_sink,
    output reg         d_denied,
    output reg [`TL_DATA_BYTES*8-1:0] d_data,
    
    // Memory monitoring outputs
    output                              mem_write_valid,
    output [`TL_ADDR_BITS-1:0]          mem_write_addr,
    output [`TL_DATA_BYTES*8-1:0]       mem_write_data,
    output [`TL_DATA_BYTES-1:0]         mem_write_mask,
    
    output                              mem_read_valid,
    output [`TL_ADDR_BITS-1:0]          mem_read_addr,
    output [`TL_DATA_BYTES*8-1:0]       mem_read_data,
    
    // Response monitoring outputs  
    output reg                              resp_valid,
    output reg [3:0]                        resp_opcode,
    output reg [`TL_SOURCE_BITS-1:0]        resp_source,
    output reg [`TL_DATA_BYTES*8-1:0]       resp_data
);

    // --- Internal Logic ---

    // State machine for handling requests and sending responses
    localparam S_IDLE        = 2'b00;
    localparam S_WAIT_READ   = 2'b01;
    localparam S_WAIT_WRITE  = 2'b10;
    localparam S_SEND_RESP   = 2'b11;

    // Control path registers
    reg [1:0] state, next_state;

    // Input capture registers
    reg [2:0]                   req_opcode_reg;
    reg [`TL_SIZE_BITS-1:0]     req_size_reg;
    reg [`TL_SOURCE_BITS-1:0]   req_source_reg;
    reg [`TL_ADDR_BITS-1:0]     req_address_reg;
    
    // Memory interface signals
    wire                        mem_write_ready;
    wire [`TL_DATA_BYTES*8-1:0] mem_read_data_out;
    wire                        mem_read_data_valid;
    
    // Memory to adapter signals
    reg                         write_valid;
    reg [`TL_ADDR_BITS-1:0]     write_addr;
    reg [`TL_DATA_BYTES*8-1:0]  write_data;
    reg [`TL_DATA_BYTES-1:0]    write_mask;
    
    reg                         read_valid;
    reg [`TL_ADDR_BITS-1:0]     read_addr;
    
    // Instantiate the memory module
    tl_memory memory (
        .clk(clk),
        .rst_n(rst_n),
        
        // Memory interface
        .write_valid(write_valid),
        .write_addr(write_addr),
        .write_data(write_data),
        .write_mask(write_mask),
        .write_ready(mem_write_ready),
        
        .read_valid(read_valid),
        .read_addr(read_addr),
        .read_data(mem_read_data_out),
        .read_data_valid(mem_read_data_valid),
        
        // Memory monitoring outputs
        .mem_write_valid(mem_write_valid),
        .mem_write_addr(mem_write_addr),
        .mem_write_data(mem_write_data),
        .mem_write_mask(mem_write_mask),
        
        .mem_read_valid(mem_read_valid),
        .mem_read_addr(mem_read_addr),
        .mem_read_data(mem_read_data)
    );

    // -- 1. Control Path: State Register Updates --
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            
            // Reset request registers
            req_opcode_reg <= 3'b0;
            req_size_reg <= {`TL_SIZE_BITS{1'b0}};
            req_source_reg <= {`TL_SOURCE_BITS{1'b0}};
            req_address_reg <= {`TL_ADDR_BITS{1'b0}};
            
            // Reset response monitoring
            resp_valid <= 1'b0;
            resp_opcode <= 4'b0;
            resp_source <= {`TL_SOURCE_BITS{1'b0}};
            resp_data <= {(`TL_DATA_BYTES*8){1'b0}};
        end else begin
            state <= next_state;
            
            // Default value for response monitoring
            resp_valid <= 1'b0;
            
            // Capture request parameters when accepting a new request
            if (state == S_IDLE && a_valid && a_ready) begin
                req_opcode_reg <= a_opcode;
                req_size_reg <= a_size;
                req_source_reg <= a_source;
                req_address_reg <= a_address;
                
                $display("[%0t ns] L2 Adapter: Received %s request (Addr: 0x%h, Src: %d)",
                         $time, 
                         (a_opcode == `TL_A_GET) ? "GET" : 
                         (a_opcode == `TL_A_PUTFULL) ? "PUTFULL" : 
                         (a_opcode == `TL_A_PUTPARTIAL) ? "PUTPARTIAL" : "UNKNOWN",
                         a_address, a_source);
            end
            
            // Update response monitoring when sending response
            if (state == S_SEND_RESP && d_valid && d_ready) begin
                resp_valid <= 1'b1;
                resp_opcode <= d_opcode;
                resp_source <= d_source;
                resp_data <= d_data;
            end
        end
    end

    // -- 2. Next State Logic --
    always @(*) begin
        // Default assignment
        next_state = state;

        case (state)
            S_IDLE: begin
                if (a_valid && a_ready) begin
                    if (a_opcode == `TL_A_GET) begin
                        next_state = S_WAIT_READ;
                    end
                    else if (a_opcode == `TL_A_PUTFULL || a_opcode == `TL_A_PUTPARTIAL) begin
                        next_state = S_WAIT_WRITE;
                    end
                end
            end
            
            S_WAIT_READ: begin
                if (mem_read_data_valid) begin
                    next_state = S_SEND_RESP;
                end
            end
            
            S_WAIT_WRITE: begin
                if (mem_write_ready) begin
                    next_state = S_SEND_RESP;
                end
            end

            S_SEND_RESP: begin
                if (d_valid && d_ready) begin
                    next_state = S_IDLE;
                    $display("[%0t ns] L2 Adapter: Sent %s response (Src: %d)",
                             $time,
                             (req_opcode_reg == `TL_A_GET) ? "AccessAckData" : "AccessAck", 
                             req_source_reg);
                end
            end
            
            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // -- 3. Memory Interface Logic --
    always @(*) begin
        // Default values for memory control signals
        write_valid = 1'b0;
        write_addr = req_address_reg;
        write_data = a_data;
        write_mask = a_mask;
        
        read_valid = 1'b0;
        read_addr = req_address_reg;
        
        case (state)
            S_IDLE: begin
                // Initiate memory operation immediately when receiving a request
                if (a_valid && a_ready) begin
                    if (a_opcode == `TL_A_GET) begin
                        read_valid = 1'b1;
                        read_addr = a_address;
                    end else if (a_opcode == `TL_A_PUTFULL || a_opcode == `TL_A_PUTPARTIAL) begin
                        write_valid = 1'b1;
                        write_addr = a_address;
                        write_data = a_data;
                        write_mask = a_mask;
                    end
                end
            end
            
            // No memory operations during other states
            S_WAIT_READ, S_WAIT_WRITE, S_SEND_RESP: begin
                // Keep memory signals inactive
            end
            
            default: begin
                // Default inactive memory signals
            end
        endcase
    end

    // -- 4. Output Logic --
    always @(*) begin
        // Default output assignments
        a_ready = 1'b0;
        d_valid = 1'b0;
        d_opcode = `TL_D_ACCESSACK; // Default
        d_param = 2'b0;
        d_size = req_size_reg;
        d_source = req_source_reg;
        d_sink = `TL_SINK_BITS'd0;
        d_denied = 1'b0;
        d_data = mem_read_data_out; // Always connect to memory read data
        
        case (state)
            S_IDLE: begin
                // In idle state, we're ready to accept new requests
                a_ready = 1'b1;
            end
            
            S_WAIT_READ, S_WAIT_WRITE: begin
                // Not accepting new requests while waiting for memory
            end

            S_SEND_RESP: begin
                d_valid = 1'b1;
                
                // Set response opcode based on request type
                if (req_opcode_reg == `TL_A_GET) begin
                    d_opcode = `TL_D_ACCESSACKDATA;
                end else begin
                    d_opcode = `TL_D_ACCESSACK;
                end
            end
            
            default: begin
                // Safe defaults for undefined states
                a_ready = 1'b0;
                d_valid = 1'b0;
            end
        endcase
    end

endmodule 