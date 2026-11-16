// =============================================================================
// Module Name: cache_top
// Designer:    Manas (Integration Lead & Controller Specialist)
// Project:     Design and Analysis of a Direct-Mapped Cache Controller
// Description: Top-level system integration combining all five team modules:
//              1. address_decoder   (Sankalp) - Address field extraction
//              2. cache_storage     (Tejas)   - 1KB direct-mapped cache array
//              3. tag_comparator    (Ronit)   - Validated tag match logic
//              4. cache_controller  (Manas)   - Central 6-state FSM coordinator
//              5. memory_interface  (Anant)   - Handshake bridge to main memory
//              6. main_memory       (Anant)   - 128-bit block main memory model
// =============================================================================

`timescale 1ns / 1ps

module cache_top #(
    parameter ADDR_WIDTH   = 32,
    parameter DATA_WIDTH   = 32,
    parameter BLOCK_WIDTH  = 128,
    parameter TAG_WIDTH    = 22,
    parameter INDEX_WIDTH  = 6,
    parameter OFFSET_WIDTH = 4,
    parameter NUM_LINES    = 64,
    parameter MEM_LATENCY  = 2
)(
    input  wire                  clk,
    input  wire                  rst,

    // CPU Memory Request / Response Interface
    input  wire                  cpu_req_valid,
    input  wire [ADDR_WIDTH-1:0] cpu_req_addr,
    output wire                  cpu_ready,
    output wire                  cpu_resp_valid,
    output wire [DATA_WIDTH-1:0] cpu_resp_data,

    // System Status & Diagnostic Observability
    output wire [2:0]            fsm_state,
    output wire                  cache_hit,
    output wire                  cache_miss
);

    // =========================================================================
    // Internal Interconnect Wires
    // =========================================================================

    // Sankalp's Address Decoder outputs for CPU request address
    wire [TAG_WIDTH-1:0]    dec_cpu_tag;
    wire [INDEX_WIDTH-1:0]  dec_cpu_index;
    wire [OFFSET_WIDTH-1:0] dec_cpu_offset;
    wire [1:0]              dec_cpu_word_sel;
    wire [1:0]              dec_cpu_byte_offset;
    wire [ADDR_WIDTH-1:0]   dec_cpu_block_addr;

    // Cache Storage <-> Controller & Comparator wires
    wire [INDEX_WIDTH-1:0]  storage_read_index;
    wire                    storage_read_valid;
    wire [TAG_WIDTH-1:0]    storage_read_tag;
    wire [BLOCK_WIDTH-1:0]  storage_read_data;

    wire                    storage_write_en;
    wire [INDEX_WIDTH-1:0]  storage_write_index;
    wire [TAG_WIDTH-1:0]    storage_write_tag;
    wire [BLOCK_WIDTH-1:0]  storage_write_data;
    wire                    storage_write_valid;

    // Tag Comparator <-> Controller wires
    wire [TAG_WIDTH-1:0]    comp_stored_tag;
    wire [TAG_WIDTH-1:0]    comp_req_tag;
    wire                    comp_stored_valid;
    wire                    comp_hit;
    wire                    comp_miss;

    // Cache Controller <-> Memory Interface wires
    wire                    ctrl_mem_req;
    wire [ADDR_WIDTH-1:0]   ctrl_mem_addr;
    wire                    mem_intf_ready;
    wire [BLOCK_WIDTH-1:0]  mem_intf_data;

    // Memory Interface <-> Physical Main Memory wires
    wire                    phy_mem_en;
    wire [ADDR_WIDTH-1:0]   phy_mem_addr;
    wire                    phy_mem_ready;
    wire [BLOCK_WIDTH-1:0]  phy_mem_rdata;

    // Diagnostic assignments
    assign cache_hit  = (fsm_state == 3'b001) ? comp_hit  : 1'b0;
    assign cache_miss = (fsm_state == 3'b001) ? comp_miss : 1'b0;

    // =========================================================================
    // 1. Address Decoder (Sankalp)
    // =========================================================================
    address_decoder #(
        .ADDR_WIDTH        (ADDR_WIDTH),
        .TAG_WIDTH         (TAG_WIDTH),
        .INDEX_WIDTH       (INDEX_WIDTH),
        .OFFSET_WIDTH      (OFFSET_WIDTH),
        .WORD_SEL_WIDTH    (2),
        .BYTE_OFFSET_WIDTH (2)
    ) u_addr_decoder (
        .addr         (cpu_req_addr),
        .tag          (dec_cpu_tag),
        .index        (dec_cpu_index),
        .block_offset (dec_cpu_offset),
        .word_sel     (dec_cpu_word_sel),
        .byte_offset  (dec_cpu_byte_offset),
        .block_addr   (dec_cpu_block_addr)
    );

    // =========================================================================
    // 2. Cache Storage Array (Tejas)
    // =========================================================================
    cache_storage #(
        .NUM_LINES   (NUM_LINES),
        .INDEX_WIDTH (INDEX_WIDTH),
        .TAG_WIDTH   (TAG_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) u_cache_storage (
        .clk         (clk),
        .rst         (rst),
        .read_index  (storage_read_index),
        .read_valid  (storage_read_valid),
        .read_tag    (storage_read_tag),
        .read_data   (storage_read_data),
        .write_en    (storage_write_en),
        .write_index (storage_write_index),
        .write_tag   (storage_write_tag),
        .write_data  (storage_write_data),
        .write_valid (storage_write_valid)
    );

    // =========================================================================
    // 3. Tag Comparator (Ronit)
    // =========================================================================
    tag_comparator #(
        .TAG_WIDTH   (TAG_WIDTH)
    ) u_tag_comparator (
        .tag_stored  (comp_stored_tag),
        .tag_req     (comp_req_tag),
        .valid_stored(comp_stored_valid),
        .hit         (comp_hit),
        .miss        (comp_miss)
    );

    // =========================================================================
    // 4. Cache Controller (Manas)
    // =========================================================================
    cache_controller #(
        .ADDR_WIDTH          (ADDR_WIDTH),
        .DATA_WIDTH          (DATA_WIDTH),
        .BLOCK_WIDTH         (BLOCK_WIDTH),
        .TAG_WIDTH           (TAG_WIDTH),
        .INDEX_WIDTH         (INDEX_WIDTH),
        .OFFSET_WIDTH        (OFFSET_WIDTH),
        .USE_EXT_DECODER     (1)
    ) u_cache_controller (
        .clk                 (clk),
        .rst                 (rst),
        .cpu_req_valid       (cpu_req_valid),
        .cpu_req_addr        (cpu_req_addr),
        .cpu_ready           (cpu_ready),
        .cpu_resp_valid      (cpu_resp_valid),
        .cpu_resp_data       (cpu_resp_data),
        .dec_cpu_tag         (dec_cpu_tag),
        .dec_cpu_index       (dec_cpu_index),
        .dec_cpu_offset      (dec_cpu_offset),
        .dec_cpu_word_sel    (dec_cpu_word_sel),
        .dec_cpu_byte_offset (dec_cpu_byte_offset),
        .dec_cpu_block_addr  (dec_cpu_block_addr),
        .storage_read_index  (storage_read_index),
        .storage_read_valid  (storage_read_valid),
        .storage_read_tag    (storage_read_tag),
        .storage_read_data   (storage_read_data),
        .storage_write_en    (storage_write_en),
        .storage_write_index (storage_write_index),
        .storage_write_tag   (storage_write_tag),
        .storage_write_data  (storage_write_data),
        .storage_write_valid (storage_write_valid),
        .comp_stored_tag     (comp_stored_tag),
        .comp_req_tag        (comp_req_tag),
        .comp_stored_valid   (comp_stored_valid),
        .comp_hit            (comp_hit),
        .comp_miss           (comp_miss),
        .mem_req             (ctrl_mem_req),
        .mem_addr            (ctrl_mem_addr),
        .mem_req_ready       (mem_intf_ready),
        .mem_data            (mem_intf_data),
        .fsm_state           (fsm_state),
        .cache_hit_flag      (),
        .cache_miss_flag     ()
    );

    // =========================================================================
    // 5. Memory Interface (Anant)
    // =========================================================================
    memory_interface #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) u_memory_interface (
        .clk           (clk),
        .rst           (rst),
        .mem_req       (ctrl_mem_req),
        .mem_addr      (ctrl_mem_addr),
        .mem_req_ready (mem_intf_ready),
        .mem_data      (mem_intf_data),
        .phy_mem_en    (phy_mem_en),
        .phy_mem_addr  (phy_mem_addr),
        .phy_mem_ready (phy_mem_ready),
        .phy_mem_rdata (phy_mem_rdata)
    );

    // =========================================================================
    // 6. Main Memory Model (Anant)
    // =========================================================================
    main_memory #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH),
        .LATENCY     (MEM_LATENCY)
    ) u_main_memory (
        .clk       (clk),
        .rst       (rst),
        .mem_en    (phy_mem_en),
        .mem_addr  (phy_mem_addr),
        .mem_ready (phy_mem_ready),
        .mem_rdata (phy_mem_rdata)
    );

endmodule
