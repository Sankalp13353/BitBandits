// =============================================================================
// Module Name: cache_controller
// Designer:    Manas
// Project:     Design and Analysis of a Direct-Mapped Cache Controller
// Description: Direct-mapped cache controller FSM orchestrating CPU requests,
//              tag lookup, cache hit/miss evaluation, memory refill sequencing,
//              and CPU response generation.
//
// Technical Ownership:
//   - Controller FSM implementation (IDLE, LOOKUP, MEM_REQUEST, MEM_WAIT, REFILL, RESPOND)
//   - Request latching and one-request-at-a-time protocol
//   - Cache hit/miss control logic
//   - Memory miss path and block alignment
//   - Refill sequencing and tag/valid storage write control
//   - CPU response generation and word selection
// =============================================================================

`timescale 1ns / 1ps

module cache_controller #(
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,
    parameter BLOCK_WIDTH      = 128,
    parameter TAG_WIDTH        = 22,
    parameter INDEX_WIDTH      = 6,
    parameter OFFSET_WIDTH     = 4,
    parameter USE_EXT_DECODER  = 0
)(
    input  wire                    clk,
    input  wire                    rst,

    // CPU Interface
    input  wire                    cpu_req_valid,
    input  wire [ADDR_WIDTH-1:0]   cpu_req_addr,
    output reg                     cpu_ready,
    output reg                     cpu_resp_valid,
    output reg  [DATA_WIDTH-1:0]   cpu_resp_data,

    // Address Decoder Interface (from address_decoder)
    input  wire [TAG_WIDTH-1:0]    dec_cpu_tag,
    input  wire [INDEX_WIDTH-1:0]  dec_cpu_index,
    input  wire [OFFSET_WIDTH-1:0] dec_cpu_offset,
    input  wire [1:0]              dec_cpu_word_sel,
    input  wire [1:0]              dec_cpu_byte_offset,
    input  wire [ADDR_WIDTH-1:0]   dec_cpu_block_addr,

    // Cache Storage Interface
    output wire [INDEX_WIDTH-1:0]  storage_read_index,
    input  wire                    storage_read_valid,
    input  wire [TAG_WIDTH-1:0]    storage_read_tag,
    input  wire [BLOCK_WIDTH-1:0]  storage_read_data,

    output reg                     storage_write_en,
    output reg  [INDEX_WIDTH-1:0]  storage_write_index,
    output reg  [TAG_WIDTH-1:0]    storage_write_tag,
    output reg  [BLOCK_WIDTH-1:0]  storage_write_data,
    output reg                     storage_write_valid,

    // Tag Comparator Interface
    output wire [TAG_WIDTH-1:0]    comp_stored_tag,
    output wire [TAG_WIDTH-1:0]    comp_req_tag,
    output wire                    comp_stored_valid,
    input  wire                    comp_hit,
    input  wire                    comp_miss,

    // Memory Interface
    output reg                     mem_req,
    output reg  [ADDR_WIDTH-1:0]   mem_addr,
    input  wire                    mem_req_ready,
    input  wire [BLOCK_WIDTH-1:0]  mem_data,

    // Status / Diagnostic outputs
    output wire [2:0]              fsm_state,
    output reg                     cache_hit_flag,
    output reg                     cache_miss_flag
);

    // =========================================================================
    // FSM State Encoding
    // =========================================================================
    localparam [2:0] S_IDLE        = 3'b000;
    localparam [2:0] S_LOOKUP      = 3'b001;
    localparam [2:0] S_MEM_REQUEST = 3'b010;
    localparam [2:0] S_MEM_WAIT    = 3'b011;
    localparam [2:0] S_REFILL      = 3'b100;
    localparam [2:0] S_RESPOND     = 3'b101;

    reg [2:0] current_state, next_state;

    // Export current state
    assign fsm_state = current_state;

    // =========================================================================
    // Internal Registers for Request Latching and Line Buffers
    // =========================================================================
    reg [ADDR_WIDTH-1:0]  latched_addr;
    reg [TAG_WIDTH-1:0]   latched_tag;
    reg [INDEX_WIDTH-1:0] latched_index;
    reg [1:0]             latched_word_sel;
    reg [ADDR_WIDTH-1:0]  latched_block_addr;
    reg [BLOCK_WIDTH-1:0] cached_block;
    reg [BLOCK_WIDTH-1:0] mem_block_buffer;

    // Address field decoding from latched registers or internal slicing
    wire [TAG_WIDTH-1:0]   req_tag      = USE_EXT_DECODER ? latched_tag        : latched_addr[31:10];
    wire [INDEX_WIDTH-1:0] req_index    = USE_EXT_DECODER ? latched_index      : latched_addr[9:4];
    wire [1:0]             req_word_sel = USE_EXT_DECODER ? latched_word_sel   : latched_addr[3:2];

    // Read index driven to storage
    assign storage_read_index = (current_state == S_IDLE && cpu_req_valid) ?
                                (USE_EXT_DECODER ? dec_cpu_index : cpu_req_addr[9:4]) : req_index;

    // Route storage signals and requested tag to comparator
    assign comp_stored_tag   = storage_read_tag;
    assign comp_req_tag      = req_tag;
    assign comp_stored_valid = storage_read_valid;

    // =========================================================================
    // Word Selection Multiplexer (Four 32-bit words within 128-bit block)
    // =========================================================================
    reg [DATA_WIDTH-1:0] selected_word;
    always @(*) begin
        case (req_word_sel)
            2'b00:   selected_word = cached_block[31:0];
            2'b01:   selected_word = cached_block[63:32];
            2'b10:   selected_word = cached_block[95:64];
            2'b11:   selected_word = cached_block[127:96];
            default: selected_word = cached_block[31:0];
        endcase
    end

    // =========================================================================
    // Sequential Process: State Transition, Latching, and Buffer Updates
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state      <= S_IDLE;
            latched_addr       <= {ADDR_WIDTH{1'b0}};
            latched_tag        <= {TAG_WIDTH{1'b0}};
            latched_index      <= {INDEX_WIDTH{1'b0}};
            latched_word_sel   <= 2'b00;
            latched_block_addr <= {ADDR_WIDTH{1'b0}};
            cached_block       <= {BLOCK_WIDTH{1'b0}};
            mem_block_buffer   <= {BLOCK_WIDTH{1'b0}};
        end else begin
            current_state <= next_state;

            // Latch CPU request address on entering from IDLE
            if (current_state == S_IDLE && cpu_req_valid) begin
                latched_addr       <= cpu_req_addr;
                latched_tag        <= USE_EXT_DECODER ? dec_cpu_tag        : cpu_req_addr[31:10];
                latched_index      <= USE_EXT_DECODER ? dec_cpu_index      : cpu_req_addr[9:4];
                latched_word_sel   <= USE_EXT_DECODER ? dec_cpu_word_sel   : cpu_req_addr[3:2];
                latched_block_addr <= USE_EXT_DECODER ? dec_cpu_block_addr : {cpu_req_addr[31:4], 4'b0000};
            end

            // On Cache Hit in LOOKUP, latch data block directly from storage
            if (current_state == S_LOOKUP && comp_hit) begin
                cached_block <= storage_read_data;
            end

            // Capture incoming block data from memory interface upon handshake completion
            if (current_state == S_MEM_WAIT && mem_req_ready) begin
                mem_block_buffer <= mem_data;
                cached_block     <= mem_data;
            end

            // Ensure cached_block is stable in REFILL
            if (current_state == S_REFILL) begin
                cached_block <= mem_block_buffer;
            end
        end
    end

    // =========================================================================
    // Next-State Logic (Combinational Process)
    // =========================================================================
    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if (cpu_req_valid)
                    next_state = S_LOOKUP;
                else
                    next_state = S_IDLE;
            end

            S_LOOKUP: begin
                if (comp_hit)
                    next_state = S_RESPOND;
                else
                    next_state = S_MEM_REQUEST;
            end

            S_MEM_REQUEST: begin
                next_state = S_MEM_WAIT;
            end

            S_MEM_WAIT: begin
                if (mem_req_ready)
                    next_state = S_REFILL;
                else
                    next_state = S_MEM_WAIT;
            end

            S_REFILL: begin
                next_state = S_RESPOND;
            end

            S_RESPOND: begin
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    // =========================================================================
    // Output Generation (Combinational Control & Data Steering)
    // =========================================================================
    always @(*) begin
        // CPU Handshake: Assert ready only when IDLE
        cpu_ready       = (current_state == S_IDLE);
        cpu_resp_valid  = (current_state == S_RESPOND);
        cpu_resp_data   = (current_state == S_RESPOND) ? selected_word : {DATA_WIDTH{1'b0}};

        // Hit / Miss diagnostic indicators during LOOKUP
        cache_hit_flag  = (current_state == S_LOOKUP && comp_hit);
        cache_miss_flag = (current_state == S_LOOKUP && comp_miss);

        // Cache Storage Write Controls: Active exclusively during REFILL state
        storage_write_en    = (current_state == S_REFILL);
        storage_write_valid = (current_state == S_REFILL);
        storage_write_index = req_index;
        storage_write_tag   = req_tag;
        storage_write_data  = mem_block_buffer;

        // Memory Request Controls: Asserted exclusively during MEM_REQUEST state
        mem_req  = (current_state == S_MEM_REQUEST);
        mem_addr = USE_EXT_DECODER ? latched_block_addr : {latched_addr[31:4], 4'b0000}; // Block aligned
    end

endmodule
