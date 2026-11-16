// =============================================================================
// Module Name : memory_interface
// Designer    : Tejas
// Project     : Design and Analysis of a Direct-Mapped Cache Controller
//
// Description :
//   Protocol bridge between cache_controller and main_memory.
//   A request is accepted once, the physical memory enable is pulsed once,
//   and the returned block is presented with a one-cycle ready pulse.
//
//   request_armed prevents a continuously asserted mem_req from being
//   accepted again after the current transaction completes. It is re-armed
//   only after mem_req is observed LOW.
// =============================================================================

`timescale 1ns / 1ps

module memory_interface #(
    parameter ADDR_WIDTH  = 32,
    parameter BLOCK_WIDTH = 128
)(
    input  wire                    clk,
    input  wire                    rst,

    input  wire                    mem_req,
    input  wire [ADDR_WIDTH-1:0]   mem_addr,
    output reg                     mem_req_ready,
    output reg  [BLOCK_WIDTH-1:0]  mem_data,

    output reg                     phy_mem_en,
    output reg  [ADDR_WIDTH-1:0]   phy_mem_addr,
    input  wire                    phy_mem_ready,
    input  wire [BLOCK_WIDTH-1:0]  phy_mem_rdata
);

    // FSM state encoding
    localparam [1:0] MI_IDLE     = 2'b00;
    localparam [1:0] MI_ACCESS   = 2'b01;
    localparam [1:0] MI_RESPONSE = 2'b10;

    reg [1:0]            mi_state;
    reg [ADDR_WIDTH-1:0] latched_addr;
    reg                  en_pulse_sent;

    // 1 = a new request may be accepted.
    // 0 = wait until mem_req goes LOW before accepting another request.
    reg request_armed;

    // Sequential FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mi_state       <= MI_IDLE;
            mem_req_ready  <= 1'b0;
            mem_data       <= {BLOCK_WIDTH{1'b0}};
            phy_mem_en     <= 1'b0;
            phy_mem_addr   <= {ADDR_WIDTH{1'b0}};
            latched_addr   <= {ADDR_WIDTH{1'b0}};
            en_pulse_sent  <= 1'b0;
            request_armed  <= 1'b1;
        end else begin

            // Rearm only after the requester deasserts its request.
            // This works independently of the FSM state.
            if (!mem_req)
                request_armed <= 1'b1;

            case (mi_state)

                // ---------------------------------------------------------
                // MI_IDLE: Wait for a new request.
                // ---------------------------------------------------------
                MI_IDLE: begin
                    mem_req_ready <= 1'b0;
                    phy_mem_en    <= 1'b0;
                    en_pulse_sent <= 1'b0;

                    if (mem_req && request_armed) begin
                        latched_addr  <= mem_addr;
                        mi_state      <= MI_ACCESS;
                        request_armed <= 1'b0;

                        `ifdef SIMULATION
                        $display("[MEM_INTF @%0t] Request captured: addr=0x%08h",
                                 $time, mem_addr);
                        `endif
                    end
                end

                // ---------------------------------------------------------
                // MI_ACCESS: Send one enable pulse and wait for memory.
                // ---------------------------------------------------------
                MI_ACCESS: begin
                    mem_req_ready <= 1'b0;

                    if (!en_pulse_sent) begin
                        phy_mem_en    <= 1'b1;
                        phy_mem_addr  <= latched_addr;
                        en_pulse_sent <= 1'b1;
                    end else begin
                        phy_mem_en <= 1'b0;
                    end

                    if (phy_mem_ready) begin
                        mem_data <= phy_mem_rdata;
                        mi_state <= MI_RESPONSE;

                        `ifdef SIMULATION
                        $display("[MEM_INTF @%0t] Data received: addr=0x%08h data=0x%032h",
                                 $time, latched_addr, phy_mem_rdata);
                        `endif
                    end
                end

                // ---------------------------------------------------------
                // MI_RESPONSE: Assert ready for one cycle.
                // ---------------------------------------------------------
                MI_RESPONSE: begin
                    mem_req_ready <= 1'b1;
                    phy_mem_en    <= 1'b0;
                    mi_state      <= MI_IDLE;

                    `ifdef SIMULATION
                    $display("[MEM_INTF @%0t] Ready asserted: addr=0x%08h",
                             $time, latched_addr);
                    `endif
                end

                // ---------------------------------------------------------
                // Default recovery.
                // ---------------------------------------------------------
                default: begin
                    mi_state      <= MI_IDLE;
                    mem_req_ready <= 1'b0;
                    phy_mem_en    <= 1'b0;
                    en_pulse_sent <= 1'b0;
                end

            endcase
        end
    end

endmodule