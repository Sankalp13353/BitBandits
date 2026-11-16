// =============================================================================
// File:        tb_cache_storage.sv
// Author:      Anant (Senior Hardware Verification Engineer)
// Project:     Design and Analysis of a Direct-Mapped Cache Controller
// Description: Comprehensive SystemVerilog verification testbench for the
//              cache_storage subsystem and address decoder:
//              - Self-checking read/write verification across all 64 lines
//              - Reset invalidation and valid-bit behavior
//              - Neighbor line isolation (write to line i doesn't corrupt i-1/i+1)
//              - Conflict miss replacement at storage level
//              - Boundary address decoding and storage alignment
//              - SystemVerilog immediate assertions and functional coverage
// =============================================================================

`timescale 1ns / 1ps

module tb_cache_storage;

    // Architectural Parameters
    localparam int NUM_LINES    = 64;
    localparam int INDEX_WIDTH  = 6;
    localparam int TAG_WIDTH    = 22;
    localparam int BLOCK_WIDTH  = 128;
    localparam int ADDR_WIDTH   = 32;
    localparam int OFFSET_WIDTH = 4;

    // Clock and Reset
    logic clk;
    logic rst;

    // Cache Storage Read Port
    logic [INDEX_WIDTH-1:0] read_index;
    wire                    read_valid;
    wire  [TAG_WIDTH-1:0]   read_tag;
    wire  [BLOCK_WIDTH-1:0] read_data;

    // Cache Storage Write Port
    logic                   write_en;
    logic [INDEX_WIDTH-1:0] write_index;
    logic [TAG_WIDTH-1:0]   write_tag;
    logic [BLOCK_WIDTH-1:0] write_data;
    logic                   write_valid;

    // Address Decoder Wires
    logic [ADDR_WIDTH-1:0]  dec_test_addr;
    wire  [TAG_WIDTH-1:0]   dec_tag;
    wire  [INDEX_WIDTH-1:0] dec_index;
    wire  [3:0]             dec_block_offset;
    wire  [1:0]             dec_word_sel;
    wire  [1:0]             dec_byte_offset;
    wire  [ADDR_WIDTH-1:0]  dec_block_addr;

    // Verification statistics & coverage counters
    int total_checks      = 0;
    int passed_checks     = 0;
    int failed_checks     = 0;
    int lines_written_cov = 0;
    int lines_read_cov    = 0;
    bit line_written[NUM_LINES];
    bit line_read[NUM_LINES];

    // Clock generator (100MHz -> 10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================================
    // Device Under Test (DUT) Instantiation
    // =========================================================================
    cache_storage #(
        .NUM_LINES   (NUM_LINES),
        .INDEX_WIDTH (INDEX_WIDTH),
        .TAG_WIDTH   (TAG_WIDTH),
        .BLOCK_WIDTH (BLOCK_WIDTH)
    ) dut_storage (
        .clk         (clk),
        .rst         (rst),
        .read_index  (read_index),
        .read_valid  (read_valid),
        .read_tag    (read_tag),
        .read_data   (read_data),
        .write_en    (write_en),
        .write_index (write_index),
        .write_tag   (write_tag),
        .write_data  (write_data),
        .write_valid (write_valid)
    );

    address_decoder #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .TAG_WIDTH   (TAG_WIDTH),
        .INDEX_WIDTH (INDEX_WIDTH)
    ) dut_decoder (
        .addr         (dec_test_addr),
        .tag          (dec_tag),
        .index        (dec_index),
        .block_offset (dec_block_offset),
        .word_sel     (dec_word_sel),
        .byte_offset  (dec_byte_offset),
        .block_addr   (dec_block_addr)
    );

    // =========================================================================
    // Verification Tasks
    // =========================================================================

    // Task: Synchronous Write to Cache Storage Line
    task automatic write_line(
        input [INDEX_WIDTH-1:0] idx,
        input [TAG_WIDTH-1:0]   tag_val,
        input [BLOCK_WIDTH-1:0] data_val,
        input                   valid_val
    );
        begin
            @(posedge clk);
            write_index <= idx;
            write_tag   <= tag_val;
            write_data  <= data_val;
            write_valid <= valid_val;
            write_en    <= 1'b1;
            line_written[idx] = 1'b1;
            @(posedge clk);
            write_en    <= 1'b0;
            #1;
        end
    endtask

    // Task: Self-Checking Combinational Read with SystemVerilog Assertions
    task automatic check_line(
        input [INDEX_WIDTH-1:0] idx,
        input                   exp_valid,
        input [TAG_WIDTH-1:0]   exp_tag,
        input [BLOCK_WIDTH-1:0] exp_data,
        input string            test_desc
    );
        begin
            read_index = idx;
            line_read[idx] = 1'b1;
            #2; // Allow combinational read settling

            total_checks++;
            if ((read_valid === exp_valid) &&
                (!exp_valid || ((read_tag === exp_tag) && (read_data === exp_data)))) begin
                passed_checks++;
                $display("[PASS] %s | Line %02d: V=%b Tag=0x%06h Data=0x%032h",
                         test_desc, idx, read_valid, read_tag, read_data);
            end else begin
                failed_checks++;
                $error("[FAIL] %s | Line %02d Mismatch!", test_desc, idx);
                if (read_valid !== exp_valid)
                    $display("       Valid Bit Mismatch: Expected %b, Got %b", exp_valid, read_valid);
                if (exp_valid && (read_tag !== exp_tag))
                    $display("       Tag Mismatch: Expected 0x%06h, Got 0x%06h", exp_tag, read_tag);
                if (exp_valid && (read_data !== exp_data))
                    $display("       Data Mismatch: Expected 0x%032h, Got 0x%032h", exp_data, read_data);
            end

            // SystemVerilog Immediate Assertion
            assert (read_valid === exp_valid) else $error("Assertion Violation: read_valid mismatch!");
            if (exp_valid) begin
                assert (read_tag === exp_tag) else $error("Assertion Violation: read_tag mismatch!");
                assert (read_data === exp_data) else $error("Assertion Violation: read_data mismatch!");
            end
        end
    endtask

    // =========================================================================
    // Main Verification Flow
    // =========================================================================
    initial begin
        $dumpfile("sim/cache_storage_sv.vcd");
        $dumpvars(0, tb_cache_storage);

        $display("===============================================================================");
        $display("   STARTING SYSTEMVERILOG CACHE STORAGE & DECODER TESTBENCH (ANANT)          ");
        $display("===============================================================================");

        // Initialize signals
        rst           = 1'b1;
        read_index    = '0;
        write_en      = 1'b0;
        write_index   = '0;
        write_tag     = '0;
        write_data    = '0;
        write_valid   = 1'b0;
        dec_test_addr = '0;

        for (int i = 0; i < NUM_LINES; i++) begin
            line_written[i] = 1'b0;
            line_read[i]    = 1'b0;
        end

        // Apply hardware reset
        #25;
        @(negedge clk);
        rst = 1'b0;
        #15;

        // ---------------------------------------------------------------------
        // TEST 1: Power-On Reset Invalidation Across All 64 Lines
        // ---------------------------------------------------------------------
        $display("\n>>> TEST 1: Verifying All 64 Lines Initialized to Invalid (valid=0) <<<");
        for (int i = 0; i < NUM_LINES; i++) begin
            read_index = i[INDEX_WIDTH-1:0];
            #2;
            total_checks++;
            if (read_valid === 1'b0) begin
                passed_checks++;
            end else begin
                failed_checks++;
                $error("[FAIL] Reset violation: Line %0d has valid bit = %b", i, read_valid);
            end
            assert (read_valid === 1'b0) else $error("Assertion: Line %0d valid bit non-zero on reset!", i);
        end
        $display("[INFO] Reset Invalidation: All %0d lines confirmed empty (valid=0).", NUM_LINES);

        // ---------------------------------------------------------------------
        // TEST 2: Full 64-Line Sweep (Unique Data & Tags)
        // ---------------------------------------------------------------------
        $display("\n>>> TEST 2: Writing and Reading Unique Tags & Data Across All 64 Lines <<<");
        for (int i = 0; i < NUM_LINES; i++) begin
            logic [TAG_WIDTH-1:0]   t_val;
            logic [BLOCK_WIDTH-1:0] d_val;
            t_val = 22'h200000 + (i << 2);
            d_val = {32'hDEAD0000 + i, 32'hBEEF0000 + i, 32'hCAFE0000 + i, 32'hFEED0000 + i};
            write_line(i[INDEX_WIDTH-1:0], t_val, d_val, 1'b1);
        end

        // Verify readback
        for (int i = 0; i < NUM_LINES; i++) begin
            logic [TAG_WIDTH-1:0]   t_val;
            logic [BLOCK_WIDTH-1:0] d_val;
            t_val = 22'h200000 + (i << 2);
            d_val = {32'hDEAD0000 + i, 32'hBEEF0000 + i, 32'hCAFE0000 + i, 32'hFEED0000 + i};
            check_line(i[INDEX_WIDTH-1:0], 1'b1, t_val, d_val, "Sweep Readback");
        end

        // ---------------------------------------------------------------------
        // TEST 3: Neighbor Isolation Verification
        // ---------------------------------------------------------------------
        $display("\n>>> TEST 3: Verifying Neighbor Line Isolation (Lines 31, 32, 33) <<<");
        // Overwrite line 32
        write_line(6'd32, 22'h1FFFFF, 128'h1111_2222_3333_4444_5555_6666_7777_8888, 1'b1);

        // Verify line 32 updated
        check_line(6'd32, 1'b1, 22'h1FFFFF, 128'h1111_2222_3333_4444_5555_6666_7777_8888, "Line 32 Updated ");

        // Verify line 31 is untouched
        check_line(6'd31, 1'b1, 22'h200000 + (22'd31 << 2),
                   {32'hDEAD0000 + 32'd31, 32'hBEEF0000 + 32'd31, 32'hCAFE0000 + 32'd31, 32'hFEED0000 + 32'd31},
                   "Line 31 Untouched");

        // Verify line 33 is untouched
        check_line(6'd33, 1'b1, 22'h200000 + (22'd33 << 2),
                   {32'hDEAD0000 + 32'd33, 32'hBEEF0000 + 32'd33, 32'hCAFE0000 + 32'd33, 32'hFEED0000 + 32'd33},
                   "Line 33 Untouched");

        // ---------------------------------------------------------------------
        // TEST 4: Conflict Miss Replacement at Storage Level
        // ---------------------------------------------------------------------
        $display("\n>>> TEST 4: Conflict Replacement on Line 0 (Same Index, Different Tags) <<<");
        write_line(6'd0, 22'h000001, 128'hAAAA_AAAA_BBBB_BBBB_CCCC_CCCC_DDDD_DDDD, 1'b1);
        check_line(6'd0, 1'b1, 22'h000001, 128'hAAAA_AAAA_BBBB_BBBB_CCCC_CCCC_DDDD_DDDD, "Conflict Tag 1  ");

        write_line(6'd0, 22'h000002, 128'h5555_5555_6666_6666_7777_7777_8888_8888, 1'b1);
        check_line(6'd0, 1'b1, 22'h000002, 128'h5555_5555_6666_6666_7777_7777_8888_8888, "Conflict Tag 2  ");

        // ---------------------------------------------------------------------
        // TEST 5: Address Decoder Boundary Checks
        // ---------------------------------------------------------------------
        $display("\n>>> TEST 5: Address Decoder Boundary and Field Alignment Checks <<<");
        dec_test_addr = 32'h0000_0000;
        #2;
        total_checks++;
        if (dec_tag == 22'h0 && dec_index == 6'h0 && dec_block_offset == 4'h0 && dec_block_addr == 32'h0) begin
            passed_checks++;
            $display("[PASS] Decoder Zero Boundary | Addr=0x00000000 -> Tag=0x%06h, Idx=%0d, Off=%0d",
                     dec_tag, dec_index, dec_block_offset);
        end else begin
            failed_checks++;
            $error("[FAIL] Decoder Zero Boundary Mismatch!");
        end

        dec_test_addr = 32'hFFFF_FFFF;
        #2;
        total_checks++;
        if (dec_tag == 22'h3FFFFF && dec_index == 6'h3F && dec_block_offset == 4'hF && dec_block_addr == 32'hFFFF_FFF0) begin
            passed_checks++;
            $display("[PASS] Decoder Max Boundary  | Addr=0xFFFFFFFF -> Tag=0x%06h, Idx=%0d, Off=%0d",
                     dec_tag, dec_index, dec_block_offset);
        end else begin
            failed_checks++;
            $error("[FAIL] Decoder Max Boundary Mismatch!");
        end

        // ---------------------------------------------------------------------
        // TEST 6: Runtime Reset Invalidation Check
        // ---------------------------------------------------------------------
        $display("\n>>> TEST 6: Runtime Reset Dynamic Invalidation <<<");
        @(negedge clk);
        rst = 1'b1;
        @(negedge clk);
        rst = 1'b0;
        #10;

        for (int i = 0; i < NUM_LINES; i++) begin
            read_index = i[INDEX_WIDTH-1:0];
            #2;
            total_checks++;
            if (read_valid === 1'b0) begin
                passed_checks++;
            end else begin
                failed_checks++;
                $error("[FAIL] Post-runtime-reset: Line %0d valid bit = %b", i, read_valid);
            end
        end
        $display("[INFO] Runtime reset successfully cleared all 64 valid bits.");

        // ---------------------------------------------------------------------
        // Functional Coverage Calculation
        // ---------------------------------------------------------------------
        lines_written_cov = 0;
        lines_read_cov    = 0;
        for (int i = 0; i < NUM_LINES; i++) begin
            if (line_written[i]) lines_written_cov++;
            if (line_read[i])    lines_read_cov++;
        end

        $display("\n===============================================================================");
        $display("   CACHE STORAGE VERIFICATION SUMMARY (ANANT)                                 ");
        $display("===============================================================================");
        $display("Total Checks Executed : %0d", total_checks);
        $display("Checks Passed         : %0d", passed_checks);
        $display("Checks Failed         : %0d", failed_checks);
        $display("Line Write Coverage   : %0d / %0d (%0.1f%%)", lines_written_cov, NUM_LINES, (lines_written_cov * 100.0) / NUM_LINES);
        $display("Line Read Coverage    : %0d / %0d (%0.1f%%)", lines_read_cov, NUM_LINES, (lines_read_cov * 100.0) / NUM_LINES);
        $display("===============================================================================");

        if (failed_checks == 0) begin
            $display(">>> CACHE STORAGE VERIFICATION: PASSED (100%%) <<<");
        end else begin
            $display(">>> CACHE STORAGE VERIFICATION: FAILED <<<");
        end

        $finish;
    end

endmodule
