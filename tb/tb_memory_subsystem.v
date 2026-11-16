// =============================================================================
// Testbench : tb_memory_subsystem
// Designer  : Tejas
// Project   : Design and Analysis of a Direct-Mapped Cache Controller
// Branch    : feature/main-memory-interface
// Date      : 2026-11-16
//
// Description :
//   Standalone verification suite for main_memory.v and memory_interface.v.
//
//   TC1 – Correct memory response for a given block address.
//   TC2 – Correct 128-bit block formation (all four words).
//   TC3 – Different addresses produce distinguishable blocks.
//   TC4 – Memory latency is respected (no early response).
//   TC5 – Sustained mem_req does not retrigger a transaction.
//   TC6 – Memory interface resets correctly.
//   TC7 – Consecutive requests work correctly.
//   TC8 – No response before configured latency expires.
// =============================================================================

`timescale 1ns / 1ps

module tb_memory_subsystem;

    parameter ADDR_WIDTH  = 32;
    parameter BLOCK_WIDTH = 128;
    parameter MEM_LATENCY = 10;

    // DUT signals
    reg clk;
    reg rst;

    reg mem_req;
    reg [ADDR_WIDTH-1:0] mem_addr;

    wire mem_req_ready;
    wire [BLOCK_WIDTH-1:0] mem_data;

    wire phy_mem_en;
    wire [ADDR_WIDTH-1:0] phy_mem_addr;
    wire phy_mem_ready;
    wire [BLOCK_WIDTH-1:0] phy_mem_rdata;

    // memory_interface instantiation
    memory_interface #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) u_memory_interface (
        .clk           (clk),
        .rst           (rst),
        .mem_req       (mem_req),
        .mem_addr      (mem_addr),
        .mem_req_ready (mem_req_ready),
        .mem_data      (mem_data),
        .phy_mem_en    (phy_mem_en),
        .phy_mem_addr  (phy_mem_addr),
        .phy_mem_ready (phy_mem_ready),
        .phy_mem_rdata (phy_mem_rdata)
    );

    // main_memory instantiation
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

    // 100 MHz clock: 10 ns period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Test tracking
    integer total_tests  = 0;
    integer passed_tests = 0;
    integer failed_tests = 0;

    reg [BLOCK_WIDTH-1:0] got_block;
    reg [BLOCK_WIDTH-1:0] exp_block;
    integer latency_cycles;

    // -------------------------------------------------------------------------
    // Expected block data function
    // -------------------------------------------------------------------------
    function [127:0] expected_block;
        input [31:0] b_addr;
        reg [31:0] w0, w1, w2, w3;
        begin
            w0 = {b_addr[31:4], 4'h0, 12'hA01};
            w1 = {b_addr[31:4], 4'h4, 12'hB02};
            w2 = {b_addr[31:4], 4'h8, 12'hC03};
            w3 = {b_addr[31:4], 4'hC, 12'hD04};

            expected_block = {w3, w2, w1, w0};
        end
    endfunction

    // -------------------------------------------------------------------------
    // Task: issue one request and wait for its response.
    // -------------------------------------------------------------------------
    task issue_request;
        input [ADDR_WIDTH-1:0] req_addr;
        output [BLOCK_WIDTH-1:0] got_data;
        output integer cycles;

        begin
            @(negedge clk);
            mem_req  = 1'b1;
            mem_addr = req_addr;

            @(negedge clk);
            mem_req = 1'b0;

            cycles = 0;

            while (mem_req_ready !== 1'b1) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end

            got_data = mem_data;

            // Leave the ready cycle before starting another request.
            @(negedge clk);
        end
    endtask

    // -------------------------------------------------------------------------
    // Task: apply and release reset.
    // -------------------------------------------------------------------------
    task apply_reset;
        begin
            @(negedge clk);
            rst = 1'b1;

            @(negedge clk);
            @(negedge clk);

            rst = 1'b0;

            @(posedge clk);
            #1;
        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    initial begin

        // Waveform setup
        $dumpfile("sim/memory_subsystem.vcd");
        $dumpvars(0, tb_memory_subsystem);

        $display("===========================================================================");
        $display("  MEMORY SUBSYSTEM VERIFICATION SUITE");
        $display("  main_memory + memory_interface");
        $display("  Designer : Tejas | LATENCY = %0d cycles", MEM_LATENCY);
        $display("==========================================================================\n");

        // Initial values and reset
        rst      = 1'b1;
        mem_req  = 1'b0;
        mem_addr = {ADDR_WIDTH{1'b0}};

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst = 1'b0;

        @(posedge clk);
        #1;

        // =====================================================================
        // TC1: Correct memory response
        // =====================================================================
        total_tests = total_tests + 1;

        $display("[TC1] Correct memory response for block address 0x0000_1000");

        exp_block = expected_block(32'h0000_1000);

        issue_request(
            32'h0000_1000,
            got_block,
            latency_cycles
        );

        if (got_block === exp_block) begin
            $display("      [PASS] Data matches expected block.");
            $display("             Received=0x%032h", got_block);
            passed_tests = passed_tests + 1;
        end else begin
            $display("      [FAIL] Data mismatch!");
            $display("             Got     : 0x%032h", got_block);
            $display("             Expected: 0x%032h", exp_block);
            failed_tests = failed_tests + 1;
        end

        // =====================================================================
        // TC2: Verify all four words of a 128-bit block
        // =====================================================================
        total_tests = total_tests + 1;

        $display("\n[TC2] Verify all four words of block 0x0000_2000");

        issue_request(
            32'h0000_2000,
            got_block,
            latency_cycles
        );

        begin : tc2_block
            reg [31:0] w0_got, w1_got, w2_got, w3_got;
            reg [31:0] w0_exp, w1_exp, w2_exp, w3_exp;
            reg [127:0] exp_block_tc2;
            reg tc2_pass;

            tc2_pass = 1'b1;

            w0_got = got_block[31:0];
            w1_got = got_block[63:32];
            w2_got = got_block[95:64];
            w3_got = got_block[127:96];

            exp_block_tc2 = expected_block(32'h0000_2000);

            w0_exp = exp_block_tc2[31:0];
            w1_exp = exp_block_tc2[63:32];
            w2_exp = exp_block_tc2[95:64];
            w3_exp = exp_block_tc2[127:96];

            if (w0_got !== w0_exp) begin
                $display("      [FAIL] Word0: got=0x%08h exp=0x%08h",
                         w0_got, w0_exp);
                tc2_pass = 1'b0;
            end else begin
                $display("      [PASS] Word0=0x%08h (marker A01)", w0_got);
            end

            if (w1_got !== w1_exp) begin
                $display("      [FAIL] Word1: got=0x%08h exp=0x%08h",
                         w1_got, w1_exp);
                tc2_pass = 1'b0;
            end else begin
                $display("      [PASS] Word1=0x%08h (marker B02)", w1_got);
            end

            if (w2_got !== w2_exp) begin
                $display("      [FAIL] Word2: got=0x%08h exp=0x%08h",
                         w2_got, w2_exp);
                tc2_pass = 1'b0;
            end else begin
                $display("      [PASS] Word2=0x%08h (marker C03)", w2_got);
            end

            if (w3_got !== w3_exp) begin
                $display("      [FAIL] Word3: got=0x%08h exp=0x%08h",
                         w3_got, w3_exp);
                tc2_pass = 1'b0;
            end else begin
                $display("      [PASS] Word3=0x%08h (marker D04)", w3_got);
            end

            if (tc2_pass)
                passed_tests = passed_tests + 1;
            else
                failed_tests = failed_tests + 1;
        end

        // =====================================================================
        // TC3: Different addresses return distinguishable blocks
        // =====================================================================
        total_tests = total_tests + 1;

        $display("\n[TC3] Different addresses produce distinguishable blocks");

        begin : tc3_block
            reg [BLOCK_WIDTH-1:0] block_A, block_B, block_C;
            integer dummy_lat;

            issue_request(32'h0000_3000, block_A, dummy_lat);
            issue_request(32'h0000_4000, block_B, dummy_lat);
            issue_request(32'hDEAD_B000, block_C, dummy_lat);

            if ((block_A !== block_B) &&
                (block_B !== block_C) &&
                (block_A !== block_C)) begin

                $display("      [PASS] All three blocks are unique:");
                $display("             Block@3000=0x%032h", block_A);
                $display("             Block@4000=0x%032h", block_B);
                $display("             Block@DEADB000=0x%032h", block_C);

                passed_tests = passed_tests + 1;
            end else begin
                $display("      [FAIL] Block collision detected.");
                failed_tests = failed_tests + 1;
            end
        end

        // =====================================================================
        // TC4 + TC8: Check no early response during configured latency
        // =====================================================================
        total_tests = total_tests + 1;

        $display("\n[TC4+TC8] Latency verification: expect %0d cycles",
                 MEM_LATENCY);

        begin : tc4_block
            integer early_ready;
            integer actual_cycles;
            integer c;

            early_ready   = 0;
            actual_cycles = 0;

            @(negedge clk);
            mem_req  = 1'b1;
            mem_addr = 32'h0000_5000;

            @(negedge clk);
            mem_req = 1'b0;

            // Check the first MEM_LATENCY cycles.
            for (c = 0; c < MEM_LATENCY; c = c + 1) begin
                @(posedge clk);
                #1;

                actual_cycles = actual_cycles + 1;

                if (mem_req_ready)
                    early_ready = early_ready + 1;
            end

            // Continue waiting until the response arrives.
            while (mem_req_ready !== 1'b1) begin
                @(posedge clk);
                #1;

                actual_cycles = actual_cycles + 1;
            end

            if (early_ready == 0) begin
                $display("      [PASS] No premature ready assertion.");
                $display("             Actual wait cycles = %0d (configured = %0d)",
                         actual_cycles, MEM_LATENCY);

                passed_tests = passed_tests + 1;
            end else begin
                $display("      [FAIL] Ready asserted prematurely %0d time(s).",
                         early_ready);

                failed_tests = failed_tests + 1;
            end

            @(negedge clk);
        end

        // =====================================================================
        // TC5: Sustained request must not retrigger a transaction
        // =====================================================================
        total_tests = total_tests + 1;

        $display("\n[TC5] In-flight guard: sustained mem_req does not retrigger");

        begin : tc5_block
            integer ready_count;
            integer k;

            ready_count = 0;

            // Keep mem_req HIGH throughout the complete observation window.
            @(negedge clk);
            mem_req  = 1'b1;
            mem_addr = 32'h0000_6000;

            // Observe long enough for the first response and any possible
            // duplicate response to appear.
            for (k = 0; k < (MEM_LATENCY + 20); k = k + 1) begin
                @(posedge clk);
                #1;

                if (mem_req_ready)
                    ready_count = ready_count + 1;
            end

            // Deassert only after the observation window.
            @(negedge clk);
            mem_req = 1'b0;

            @(posedge clk);
            #1;

            if (ready_count == 1) begin
                $display("      [PASS] mem_req_ready fired exactly once.");
                passed_tests = passed_tests + 1;
            end else begin
                $display("      [FAIL] mem_req_ready fired %0d times; expected 1.",
                         ready_count);
                failed_tests = failed_tests + 1;
            end
        end

        // Allow interface to settle.
        repeat (3) @(posedge clk);

        // =====================================================================
        // TC6: Reset correctness
        // =====================================================================
        total_tests = total_tests + 1;

        $display("\n[TC6] Reset correctness: outputs cleared after reset");

        begin : tc6_block
            reg outputs_clear;

            outputs_clear = 1'b1;

            // Start a request.
            @(negedge clk);
            mem_req  = 1'b1;
            mem_addr = 32'h0000_7000;

            @(negedge clk);
            mem_req = 1'b0;

            repeat (3) @(posedge clk);

            // Reset in the middle of the transaction.
            apply_reset();

            @(posedge clk);
            #1;

            if (mem_req_ready !== 1'b0) begin
                $display("      [FAIL] mem_req_ready was not cleared.");
                outputs_clear = 1'b0;
            end

            if (phy_mem_en !== 1'b0) begin
                $display("      [FAIL] phy_mem_en was not cleared.");
                outputs_clear = 1'b0;
            end

            if (mem_data !== {BLOCK_WIDTH{1'b0}}) begin
                $display("      [FAIL] mem_data was not cleared.");
                outputs_clear = 1'b0;
            end

            if (outputs_clear) begin
                $display("      [PASS] Interface outputs correctly cleared.");
                passed_tests = passed_tests + 1;
            end else begin
                failed_tests = failed_tests + 1;
            end
        end

        // =====================================================================
        // TC7: Consecutive requests
        // =====================================================================
        total_tests = total_tests + 1;

        $display("\n[TC7] Consecutive requests: three sequential transactions");

        begin : tc7_block
            reg [BLOCK_WIDTH-1:0] blk1, blk2, blk3;
            reg [BLOCK_WIDTH-1:0] exp1, exp2, exp3;
            integer lat1, lat2, lat3;
            reg tc7_pass;

            tc7_pass = 1'b1;

            exp1 = expected_block(32'h0000_A000);
            exp2 = expected_block(32'h0000_B000);
            exp3 = expected_block(32'hCAFE_B000);

            issue_request(32'h0000_A000, blk1, lat1);
            issue_request(32'h0000_B000, blk2, lat2);
            issue_request(32'hCAFE_B000, blk3, lat3);

            if (blk1 !== exp1) begin
                $display("      [FAIL] Transaction 1 data mismatch.");
                tc7_pass = 1'b0;
            end

            if (blk2 !== exp2) begin
                $display("      [FAIL] Transaction 2 data mismatch.");
                tc7_pass = 1'b0;
            end

            if (blk3 !== exp3) begin
                $display("      [FAIL] Transaction 3 data mismatch.");
                tc7_pass = 1'b0;
            end

            if (tc7_pass) begin
                $display("      [PASS] All 3 transactions returned correct data.");
                $display("             Latencies: T1=%0d T2=%0d T3=%0d cycles",
                         lat1, lat2, lat3);

                passed_tests = passed_tests + 1;
            end else begin
                failed_tests = failed_tests + 1;
            end
        end

        // =====================================================================
        // Final summary
        // =====================================================================
        $display("\n===========================================================================");
        $display("  MEMORY SUBSYSTEM VERIFICATION SUMMARY");
        $display("  Passed: %0d / %0d    Failed: %0d",
                 passed_tests, total_tests, failed_tests);
        $display("===========================================================================");

        if (failed_tests == 0)
            $display("  >>> ALL MEMORY SUBSYSTEM TESTS PASSED <<<");
        else
            $display("  >>> FAILURES DETECTED — REVIEW LOG ABOVE <<<");

        $display("===========================================================================\n");

        $finish;
    end

endmodule