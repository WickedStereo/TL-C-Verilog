`include "tl_pkg.vh"

// L1 adapter module implementing TileLink Master interface
module tl_l1_adapter (
    input clk,
    input rst_n,

    // Control signals
    input        start_transaction,  // Pulse to start a new transaction
    input [1:0]  transaction_type,   // 0: GET, 1: PUTFULL, 2: PUTPARTIAL, 3: reserved
    output reg   transaction_done,   // Pulses when transaction is complete
    
    // Transaction parameters as inputs
    input [`TL_ADDR_BITS-1:0]     address,    // Address for any operation
    input [`TL_SIZE_BITS-1:0]     size,       // Size for any operation
    input [`TL_SOURCE_BITS-1:0]   source,     // Source for any operation
    input [`TL_DATA_BYTES*8-1:0]  write_data, // Data for PUT operations
    input [`TL_DATA_BYTES-1:0]    write_mask, // Mask for PUTPARTIAL operation
    output [`TL_DATA_BYTES*8-1:0] read_data,  // Data returned from GET operation

    // TileLink Interface (Master Port)
    // Channel A (Master -> Slave)
    output reg         a_valid,
    input              a_ready,
    output reg [2:0]   a_opcode,
    output reg [2:0]   a_param,
    output reg [`TL_SIZE_BITS-1:0]   a_size,
    output reg [`TL_SOURCE_BITS-1:0] a_source,
    output reg [`TL_ADDR_BITS-1:0]   a_address,
    output reg [`TL_DATA_BYTES-1:0]  a_mask,
    output reg [`TL_DATA_BYTES*8-1:0] a_data,

    // Channel D (Slave -> Master)
    input              d_valid,
    output reg         d_ready,
    input [3:0]        d_opcode,
    input [1:0]        d_param,
    input [`TL_SIZE_BITS-1:0]   d_size,
    input [`TL_SOURCE_BITS-1:0] d_source,
    input [`TL_SINK_BITS-1:0]   d_sink,
    input              d_denied,
    input [`TL_DATA_BYTES*8-1:0] d_data
);

    // --- Internal Logic ---

    // State machine definitions
    localparam S_IDLE           = 3'b000;
    localparam S_SEND_REQ       = 3'b001;
    localparam S_WAIT_RESP      = 3'b010;
    localparam S_COMPLETE       = 3'b011;

    // Transaction type definitions
    localparam TX_GET           = 2'b00;
    localparam TX_PUTFULL       = 2'b01;
    localparam TX_PUTPARTIAL    = 2'b10;

    // Control path registers
    reg [2:0] state, next_state;
    reg [1:0] current_tx_type;

    // Data path registers
    reg [`TL_DATA_BYTES*8-1:0] read_data_reg;

    // Parameter registers
    reg [`TL_SIZE_BITS-1:0]    reg_size;
    reg [`TL_SOURCE_BITS-1:0]  reg_source;
    reg [`TL_ADDR_BITS-1:0]    reg_address;
    reg [`TL_DATA_BYTES*8-1:0] reg_write_data;
    reg [`TL_DATA_BYTES-1:0]   reg_write_mask;
    
    // Output assignments
    assign read_data = read_data_reg;

    // 1. Control path sequential logic - State registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            current_tx_type <= TX_GET;
        end else begin
            state <= next_state;
            
            // Capture transaction type only when needed
            if (state == S_IDLE && start_transaction) begin
                current_tx_type <= transaction_type;
            end
        end
    end

    // 2. Data path sequential logic - Data registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_data_reg <= {(`TL_DATA_BYTES*8){1'b0}};
            transaction_done <= 1'b0;
            
            // Reset parameter registers
            reg_size <= {`TL_SIZE_BITS{1'b0}};
            reg_source <= {`TL_SOURCE_BITS{1'b0}};
            reg_address <= {`TL_ADDR_BITS{1'b0}};
            reg_write_data <= {(`TL_DATA_BYTES*8){1'b0}};
            reg_write_mask <= {`TL_DATA_BYTES{1'b0}};
        end else begin
            // Default: transaction_done is only asserted for one cycle
            transaction_done <= (state == S_COMPLETE);
            
            // Latch input parameters when starting a new transaction
            if (state == S_IDLE && start_transaction) begin
                reg_size <= size;
                reg_source <= source;
                reg_address <= address;
                reg_write_data <= write_data;
                reg_write_mask <= write_mask;
            end
            
            // Capture read data when we receive AccessAckData for a GET transaction
            if (state == S_WAIT_RESP && d_valid && d_ready && 
                current_tx_type == TX_GET && d_opcode == `TL_D_ACCESSACKDATA) begin
                read_data_reg <= d_data;
            end
        end
    end

    // 3. Next state logic
    always @(*) begin
        // Default assignment
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start_transaction) begin
                    next_state = S_SEND_REQ;
                end
            end

            S_SEND_REQ: begin
                if (a_valid && a_ready) begin
                    next_state = S_WAIT_RESP;
                end
            end

            S_WAIT_RESP: begin
                if (d_valid && d_ready) begin
                    // Check for correct response opcode based on transaction type
                    case (current_tx_type)
                        TX_GET: begin
                            // For GET, we expect AccessAckData
                            if (d_opcode == `TL_D_ACCESSACKDATA) begin
                                next_state = S_COMPLETE;
                            end else begin
                                // Incorrect response type for GET
                                next_state = S_WAIT_RESP; // Stay in this state
                                $display("Error: Expected AccessAckData response for GET, received opcode %0d", d_opcode);
                            end
                        end
                        
                        TX_PUTFULL, TX_PUTPARTIAL: begin
                            // For PUTFULL or PUTPARTIAL, we expect AccessAck
                            if (d_opcode == `TL_D_ACCESSACK) begin
                                next_state = S_COMPLETE;
                            end else begin
                                // Incorrect response type for PUT
                                next_state = S_WAIT_RESP; // Stay in this state
                                $display("Error: Expected AccessAck response for PUT, received opcode %0d", d_opcode);
                            end
                        end
                        
                        default: begin
                            // Unknown transaction type
                            next_state = S_COMPLETE; // Complete anyway
                            $display("Warning: Unknown transaction type %0d", current_tx_type);
                        end
                    endcase
                end
            end
            
            S_COMPLETE: begin
                // Single cycle completion state
                next_state = S_IDLE;
            end
            
            default: next_state = S_IDLE;
        endcase
    end

    // 4. Output logic - TileLink signals
    always @(*) begin
        // Default assignments for outputs
        a_valid    = 1'b0;
        a_opcode   = `TL_A_GET; // Default, will be overridden
        a_param    = 3'b0;
        a_size     = reg_size;
        a_source   = reg_source;
        a_address  = reg_address;
        a_mask     = {`TL_DATA_BYTES{1'b1}}; // Default full mask
        a_data     = reg_write_data;
        d_ready    = 1'b0;

        case (state)
            S_IDLE: begin
                // No active outputs in idle state
            end

            S_SEND_REQ: begin
                a_valid = 1'b1;
                
                // Set opcode and mask based on transaction type
                case (current_tx_type)
                    TX_GET: begin
                        a_opcode = `TL_A_GET;
                        a_mask = {`TL_DATA_BYTES{1'b1}}; // Full mask for GET
                    end
                    
                    TX_PUTFULL: begin
                        a_opcode = `TL_A_PUTFULL;
                        a_mask = {`TL_DATA_BYTES{1'b1}}; // Full mask for PUTFULL
                    end
                    
                    TX_PUTPARTIAL: begin
                        a_opcode = `TL_A_PUTPARTIAL;
                        a_mask = reg_write_mask; // Partial mask as specified
                    end
                    
                    default: begin
                        a_opcode = `TL_A_GET; // Default
                    end
                endcase
            end

            S_WAIT_RESP: begin
                d_ready = 1'b1; // Ready to accept response
            end
            
            S_COMPLETE: begin
                // No active outputs in completion state
            end
            
            default: begin
                // Safe defaults for undefined states
                a_valid = 1'b0;
                d_ready = 1'b0;
            end
        endcase
    end

endmodule 