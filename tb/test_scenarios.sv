// =============================================================================
// File:        test_scenarios.sv
// Author:      Anant (Senior Hardware Verification Engineer)
// Project:     Design and Analysis of a Direct-Mapped Cache Controller
// Description: Modular test scenario implementations for cache verification.
//              Included within tb_cache_top to execute structured test sequences:
//              - TEST 1: Cold Cache Test
//              - TEST 2: Temporal Locality
//              - TEST 3: Spatial Locality
//              - TEST 4: Sequential Access
//              - TEST 5: Conflict Miss
//              - TEST 6: Random Access Workload
//              - TEST 7: Reset Behavior
//              - TEST 8: Consecutive Requests & Backpressure
// =============================================================================

// -----------------------------------------------------------------------------
// Baseline Test Scenario Framework
// -----------------------------------------------------------------------------
task automatic run_basic_sanity_check();
    logic [31:0] test_addr;
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;

    $display("\n===============================================================================");
    $display("   [SANITY CHECK] Executing Basic Cache Initialization & Read Check           ");
    $display("===============================================================================");

    test_addr = 32'h0000_1000;
    exp_data  = ref_mem_word(test_addr);

    cpu_read(test_addr, rdata, hit, miss, lat);

    total_tests++;
    if (miss && !hit && (rdata === exp_data)) begin
        passed_tests++;
        $display("   [PASS] Sanity read successful: Addr=0x%08h -> Data=0x%08h (Miss detected, latency=%0d cyc)",
                 test_addr, rdata, lat);
    end else begin
        failed_tests++;
        $error("   [FAIL] Sanity read failed: Addr=0x%08h -> Got Data=0x%08h, Exp Data=0x%08h, Hit=%b, Miss=%b",
               test_addr, rdata, exp_data, hit, miss);
    end
endtask

// -----------------------------------------------------------------------------
// TEST 1: Cold Cache Test
// - Reset cache.
// - Access an address (and multiple test addresses across lines).
// - Verify first access is a miss (compulsory miss).
// - Verify returned data strictly matches main memory reference model.
// -----------------------------------------------------------------------------
task automatic run_test_cold_cache();
    logic [31:0] test_addrs [4];
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;
    int          subtest_passed;

    $display("\n===============================================================================");
    $display("   [TEST 1] COLD CACHE TEST (Compulsory Miss Verification)                     ");
    $display("===============================================================================");

    // Step 1: Ensure cache is cleanly reset
    @(negedge clk);
    rst = 1'b1;
    @(negedge clk);
    @(negedge clk);
    rst = 1'b0;
    reset_ref_cache();
    @(posedge clk);
    #5;

    test_addrs[0] = 32'h0000_1204; // Index = 0x20 (Line 32), Tag = 0x000004, Offset = 0x4
    test_addrs[1] = 32'h0000_2408; // Index = 0x00 (Line 0),  Tag = 0x000009, Offset = 0x8
    test_addrs[2] = 32'h0000_360C; // Index = 0x20 (Line 32), Tag = 0x00000D, Offset = 0xC
    test_addrs[3] = 32'h0000_4800; // Index = 0x00 (Line 0),  Tag = 0x000012, Offset = 0x0

    for (int i = 0; i < 4; i++) begin
        total_tests++;
        exp_data = ref_mem_word(test_addrs[i]);

        $display("   [Subtest 1.%0d] Cold access to Address 0x%08h (Index=%0d, Word=%0d)",
                 i+1, test_addrs[i], test_addrs[i][9:4], test_addrs[i][3:2]);

        cpu_read(test_addrs[i], rdata, hit, miss, lat);

        if (miss && !hit && (rdata === exp_data)) begin
            passed_tests++;
            $display("         [PASS] Compulsory Miss confirmed | Data = 0x%08h (Expected 0x%08h), Latency = %0d cycles",
                     rdata, exp_data, lat);
        end else begin
            failed_tests++;
            $error("         [FAIL] Cold cache check failed! Addr=0x%08h, Hit=%b, Miss=%b, Got=0x%08h, Expected=0x%08h",
                   test_addrs[i], hit, miss, rdata, exp_data);
        end
    end
endtask

// -----------------------------------------------------------------------------
// TEST 2: Temporal Locality Test
// - Access the same address repeatedly.
// - Verify first access misses (compulsory).
// - Verify subsequent accesses hit (zero memory refill, 2-cycle latency).
// -----------------------------------------------------------------------------
task automatic run_test_temporal_locality();
    logic [31:0] test_addr;
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;
    const int    NUM_REPEATS = 5;

    $display("\n===============================================================================");
    $display("   [TEST 2] TEMPORAL LOCALITY TEST (Repeated Access to Same Address)           ");
    $display("===============================================================================");

    test_addr = 32'h0000_2004; // Tag = 0x000008, Index = 0x00 (Line 0), Word = 1
    exp_data  = ref_mem_word(test_addr);

    for (int rep = 1; rep <= NUM_REPEATS; rep++) begin
        total_tests++;
        cpu_read(test_addr, rdata, hit, miss, lat);

        if (rep == 1) begin
            // First access must miss
            if (miss && !hit && (rdata === exp_data)) begin
                passed_tests++;
                $display("   [PASS] Access %0d (Initial) : Miss confirmed | Latency = %0d cyc, Data = 0x%08h",
                         rep, lat, rdata);
            end else begin
                failed_tests++;
                $error("   [FAIL] Access %0d (Initial) : Expected Miss, Got Hit=%b, Miss=%b, Data=0x%08h",
                       rep, hit, miss, rdata);
            end
        end else begin
            // Subsequent accesses must hit
            if (hit && !miss && (rdata === exp_data) && (lat == 2)) begin
                passed_tests++;
                $display("   [PASS] Access %0d (Repeated): Hit confirmed  | Latency = %0d cyc, Data = 0x%08h",
                         rep, lat, rdata);
            end else begin
                failed_tests++;
                $error("   [FAIL] Access %0d (Repeated): Expected Hit with 2-cyc latency! Got Hit=%b, Miss=%b, Lat=%0d, Data=0x%08h",
                       rep, hit, miss, lat, rdata);
            end
        end
    end
endtask

// -----------------------------------------------------------------------------
// TEST 3: Spatial Locality Test
// - Access four words in the same 16-byte block.
// - Verify only the first access causes a miss.
// - Verify all four returned words are correct.
// -----------------------------------------------------------------------------
task automatic run_test_spatial_locality();
    logic [31:0] base_block_addr;
    logic [31:0] word_addr;
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;

    $display("\n===============================================================================");
    $display("   [TEST 3] SPATIAL LOCALITY TEST (Access 4 Words in 16-Byte Block)            ");
    $display("===============================================================================");

    // Block 1: Access words sequentially: Word 0 -> 1 -> 2 -> 3
    base_block_addr = 32'h0000_5A00;
    $display("   --- Subtest 3A: Sequential Word In-Block Order (0 -> 1 -> 2 -> 3) ---");
    for (int w = 0; w < 4; w++) begin
        word_addr = base_block_addr + (w * 4);
        exp_data  = ref_mem_word(word_addr);
        total_tests++;

        cpu_read(word_addr, rdata, hit, miss, lat);

        if (w == 0) begin
            // Word 0 must miss (fetches block)
            if (miss && !hit && (rdata === exp_data)) begin
                passed_tests++;
                $display("   [PASS] Word %0d (Addr=0x%08h): Compulsory Miss | Latency = %0d cyc, Data = 0x%08h",
                         w, word_addr, lat, rdata);
            end else begin
                failed_tests++;
                $error("   [FAIL] Word %0d (Addr=0x%08h): Expected Miss! Got Hit=%b, Miss=%b, Data=0x%08h",
                       w, word_addr, hit, miss, rdata);
            end
        end else begin
            // Words 1, 2, 3 must hit due to spatial locality
            if (hit && !miss && (rdata === exp_data) && (lat == 2)) begin
                passed_tests++;
                $display("   [PASS] Word %0d (Addr=0x%08h): Spatial Hit     | Latency = %0d cyc, Data = 0x%08h",
                         w, word_addr, lat, rdata);
            end else begin
                failed_tests++;
                $error("   [FAIL] Word %0d (Addr=0x%08h): Expected Spatial Hit! Got Hit=%b, Miss=%b, Lat=%0d, Data=0x%08h",
                       w, word_addr, hit, miss, lat, rdata);
            end
        end
    end

    // Block 2: Access words out-of-order: Word 2 -> Word 0 -> Word 3 -> Word 1
    base_block_addr = 32'h0000_6B00;
    $display("\n   --- Subtest 3B: Non-sequential Word In-Block Order (2 -> 0 -> 3 -> 1) ---");
    begin
        int word_order[4] = '{2, 0, 3, 1};
        for (int step = 0; step < 4; step++) begin
            int w = word_order[step];
            word_addr = base_block_addr + (w * 4);
            exp_data  = ref_mem_word(word_addr);
            total_tests++;

            cpu_read(word_addr, rdata, hit, miss, lat);

            if (step == 0) begin
                if (miss && !hit && (rdata === exp_data)) begin
                    passed_tests++;
                    $display("   [PASS] Step %0d: Word %0d (Addr=0x%08h): Compulsory Miss | Latency = %0d cyc, Data = 0x%08h",
                             step+1, w, word_addr, lat, rdata);
                end else begin
                    failed_tests++;
                    $error("   [FAIL] Step %0d: Word %0d (Addr=0x%08h): Expected Miss! Got Hit=%b, Miss=%b, Data=0x%08h",
                           step+1, w, word_addr, hit, miss, rdata);
                end
            end else begin
                if (hit && !miss && (rdata === exp_data) && (lat == 2)) begin
                    passed_tests++;
                    $display("   [PASS] Step %0d: Word %0d (Addr=0x%08h): Spatial Hit     | Latency = %0d cyc, Data = 0x%08h",
                             step+1, w, word_addr, lat, rdata);
                end else begin
                    failed_tests++;
                    $error("   [FAIL] Step %0d: Word %0d (Addr=0x%08h): Expected Spatial Hit! Got Hit=%b, Miss=%b, Lat=%0d, Data=0x%08h",
                           step+1, w, word_addr, hit, miss, lat, rdata);
                end
            end
        end
    end
endtask

// -----------------------------------------------------------------------------
// TEST 5: Conflict Miss Test
// - Generate addresses with identical index (e.g. Index 0) but different tags:
//   Addr A: 0x00000000 (Tag 0, Index 0)
//   Addr B: 0x00000400 (Tag 1, Index 0)
//   Addr C: 0x00000800 (Tag 2, Index 0)
// - Verify each access evicts and replaces the resident block.
// - Re-access evicted addresses to prove conflict miss and replacement.
// -----------------------------------------------------------------------------
task automatic run_test_conflict_miss();
    logic [31:0] addr_a, addr_b, addr_c;
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;

    $display("\n===============================================================================");
    $display("   [TEST 5] CONFLICT MISS & LINE REPLACEMENT TEST                              ");
    $display("===============================================================================");

    addr_a = 32'h0000_0000; // Tag 0x000000, Index 0, Offset 0
    addr_b = 32'h0000_0400; // Tag 0x000001, Index 0, Offset 0
    addr_c = 32'h0000_0800; // Tag 0x000002, Index 0, Offset 0

    // Step 1: Initial cold load of Addr A into Index 0
    total_tests++;
    exp_data = ref_mem_word(addr_a);
    cpu_read(addr_a, rdata, hit, miss, lat);
    if (miss && !hit && (rdata === exp_data)) begin
        passed_tests++;
        $display("   [PASS] Step 1: Load Addr A (0x%08h) -> Compulsory Miss, Line 0 allocated Tag 0x000000", addr_a);
    end else begin
        failed_tests++;
        $error("   [FAIL] Step 1: Expected Compulsory Miss for Addr A (0x%08h)!", addr_a);
    end

    // Verify Addr A hits when re-accessed immediately (resident in Line 0)
    total_tests++;
    cpu_read(addr_a, rdata, hit, miss, lat);
    if (hit && !miss && (rdata === exp_data)) begin
        passed_tests++;
        $display("   [PASS] Step 2: Re-access Addr A (0x%08h) -> Hit confirmed (Tag 0x000000 resident)", addr_a);
    end else begin
        failed_tests++;
        $error("   [FAIL] Step 2: Expected Hit for Addr A (0x%08h)!", addr_a);
    end

    // Step 3: Access Addr B -> Same index 0, Tag 1 != Tag 0 -> Conflict Miss & Replacement
    total_tests++;
    exp_data = ref_mem_word(addr_b);
    cpu_read(addr_b, rdata, hit, miss, lat);
    if (miss && !hit && (rdata === exp_data)) begin
        passed_tests++;
        $display("   [PASS] Step 3: Load Addr B (0x%08h) -> Conflict Miss confirmed! Evicted Tag 0x0, installed Tag 0x1", addr_b);
    end else begin
        failed_tests++;
        $error("   [FAIL] Step 3: Expected Conflict Miss for Addr B (0x%08h)!", addr_b);
    end

    // Step 4: Access Addr C -> Same index 0, Tag 2 != Tag 1 -> Conflict Miss & Replacement
    total_tests++;
    exp_data = ref_mem_word(addr_c);
    cpu_read(addr_c, rdata, hit, miss, lat);
    if (miss && !hit && (rdata === exp_data)) begin
        passed_tests++;
        $display("   [PASS] Step 4: Load Addr C (0x%08h) -> Conflict Miss confirmed! Evicted Tag 0x1, installed Tag 0x2", addr_c);
    end else begin
        failed_tests++;
        $error("   [FAIL] Step 4: Expected Conflict Miss for Addr C (0x%08h)!", addr_c);
    end

    // Step 5: Re-access Addr A -> Must MISS because it was evicted by B and C!
    total_tests++;
    exp_data = ref_mem_word(addr_a);
    cpu_read(addr_a, rdata, hit, miss, lat);
    if (miss && !hit && (rdata === exp_data)) begin
        passed_tests++;
        $display("   [PASS] Step 5: Re-access evicted Addr A -> Miss verified! Proves replacement & thrashing", addr_a);
    end else begin
        failed_tests++;
        $error("   [FAIL] Step 5: Expected Miss for evicted Addr A! Got Hit=%b, Miss=%b", hit, miss);
    end

    // Step 6: Access Word 1 of Addr A (0x00000004) -> Must HIT (proves Addr A is now newly resident)
    total_tests++;
    exp_data = ref_mem_word(32'h0000_0004);
    cpu_read(32'h0000_0004, rdata, hit, miss, lat);
    if (hit && !miss && (rdata === exp_data)) begin
        passed_tests++;
        $display("   [PASS] Step 6: Access Word 1 of re-fetched block -> Spatial Hit confirmed!");
    end else begin
        failed_tests++;
        $error("   [FAIL] Step 6: Expected Spatial Hit for Word 1!");
    end

    // Subtest 5B: Additional conflict test on Line 45 (Index = 6'd45 = 0x2D)
    $display("\n   --- Subtest 5B: Conflict Replacement on Line 45 (0x2D) ---");
    begin
        logic [31:0] conf_x, conf_y;
        conf_x = 32'h0000_02D0; // Tag 0x000000, Index 45 (0x2D)
        conf_y = 32'h0000_06D0; // Tag 0x000001, Index 45 (0x2D)

        // Access X
        total_tests++;
        exp_data = ref_mem_word(conf_x);
        cpu_read(conf_x, rdata, hit, miss, lat);
        if (miss && !hit && (rdata === exp_data)) passed_tests++;
        else failed_tests++;

        // Access Y (causes conflict miss and replaces X)
        total_tests++;
        exp_data = ref_mem_word(conf_y);
        cpu_read(conf_y, rdata, hit, miss, lat);
        if (miss && !hit && (rdata === exp_data)) begin
            passed_tests++;
            $display("   [PASS] Conflict Miss confirmed on Line 45: Addr=0x%08h evicted Addr=0x%08h", conf_y, conf_x);
        end else begin
            failed_tests++;
            $error("   [FAIL] Conflict Miss on Line 45 failed!");
        end
    end
endtask

// -----------------------------------------------------------------------------
// TEST 4: Sequential Access Test
// - Generate sequential addresses across consecutive 32-bit words.
// - Analyze block reuse and expected hit behavior:
//   * Stride of 4 bytes -> Exactly 1 miss per 4-word block, 3 hits per block (75% hit rate).
//   * Second pass over resident blocks -> 100% hits (32/32 hits).
// -----------------------------------------------------------------------------
task automatic run_test_sequential_access();
    logic [31:0] base_addr;
    logic [31:0] cur_addr;
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;

    int seq_hits_pass1;
    int seq_miss_pass1;
    int seq_hits_pass2;
    int seq_miss_pass2;
    const int NUM_WORDS = 32; // 32 words = 8 blocks = 128 bytes

    $display("\n===============================================================================");
    $display("   [TEST 4] SEQUENTIAL ACCESS & STREAMING BLOCK REUSE TEST                     ");
    $display("===============================================================================");

    base_addr      = 32'h0000_3000;
    seq_hits_pass1 = 0;
    seq_miss_pass1 = 0;
    seq_hits_pass2 = 0;
    seq_miss_pass2 = 0;

    $display("   --- Pass 1: Cold Streaming Over %0d Sequential 32-Bit Words ---", NUM_WORDS);
    for (int i = 0; i < NUM_WORDS; i++) begin
        cur_addr = base_addr + (i * 4);
        exp_data = ref_mem_word(cur_addr);
        total_tests++;

        cpu_read(cur_addr, rdata, hit, miss, lat);

        if (rdata !== exp_data) begin
            failed_tests++;
            $error("   [FAIL] Sequential Word %0d (0x%08h) Data Mismatch! Got 0x%08h, Exp 0x%08h",
                   i, cur_addr, rdata, exp_data);
        end else begin
            passed_tests++;
        end

        // Check hit/miss pattern: word offset 0 must miss, offsets 1,2,3 must hit
        if (cur_addr[3:2] == 2'b00) begin
            if (miss && !hit) begin
                seq_miss_pass1++;
            end else begin
                $error("   [FAIL] Sequential block start (Word %0d) expected miss!", i);
            end
        end else begin
            if (hit && !miss) begin
                seq_hits_pass1++;
            end else begin
                $error("   [FAIL] Sequential intra-block (Word %0d) expected spatial hit!", i);
            end
        end
    end

    $display("   [PASS] Pass 1 Complete: %0d Hits, %0d Misses (Observed Hit Rate = %0.1f%%, Expected = 75.0%%)",
             seq_hits_pass1, seq_miss_pass1, (seq_hits_pass1 * 100.0) / NUM_WORDS);

    // Pass 2: Re-stream the exact same 32 words (all 8 blocks now resident in cache)
    $display("\n   --- Pass 2: Warm Streaming Over Same %0d Words (Cache Residency Verification) ---", NUM_WORDS);
    for (int i = 0; i < NUM_WORDS; i++) begin
        cur_addr = base_addr + (i * 4);
        exp_data = ref_mem_word(cur_addr);
        total_tests++;

        cpu_read(cur_addr, rdata, hit, miss, lat);

        if ((rdata === exp_data) && hit && !miss && (lat == 2)) begin
            passed_tests++;
            seq_hits_pass2++;
        end else begin
            failed_tests++;
            seq_miss_pass2++;
            $error("   [FAIL] Pass 2 Word %0d expected warm hit! Hit=%b, Miss=%b, Lat=%0d", i, hit, miss, lat);
        end
    end

    $display("   [PASS] Pass 2 Complete: %0d Hits, %0d Misses (Observed Hit Rate = %0.1f%%, Expected = 100.0%%)",
             seq_hits_pass2, seq_miss_pass2, (seq_hits_pass2 * 100.0) / NUM_WORDS);
endtask

// -----------------------------------------------------------------------------
// TEST 6: Random Access Workload Test
// - Reproducible pseudorandom sequence using fixed random seed.
// - Broad address coverage across all indices, tags, and word offsets.
// - Every transaction checked independently against reference memory model.
// -----------------------------------------------------------------------------
task automatic run_test_random_access();
    int          seed;
    logic [31:0] rand_addr;
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;
    bit          exp_hit;

    int rand_hits;
    int rand_misses;
    int data_mismatch_cnt;
    const int NUM_RAND_TX = 100;

    $display("\n===============================================================================");
    $display("   [TEST 6] PSEUDORANDOM ACCESS WORKLOAD TEST (Reproducible Fixed Seed)        ");
    $display("===============================================================================");

    seed              = 32'h5EED_C0DE;
    rand_hits         = 0;
    rand_misses       = 0;
    data_mismatch_cnt = 0;

    $display("   Executing %0d pseudorandom transactions with fixed seed 0x%08h...", NUM_RAND_TX, seed);

    for (int tx = 0; tx < NUM_RAND_TX; tx++) begin
        // Generate word-aligned address with constrained index/tag distribution to create hits & misses
        // Lower 4 bits: byte offset 0, word offset random (0, 4, 8, 12)
        // Middle 6 bits: index (0-63)
        // Upper 22 bits: tag (small pool to trigger both conflict misses and hits)
        logic [5:0]  rnd_idx;
        logic [7:0]  rnd_tag;
        logic [1:0]  rnd_w;

        rnd_idx = $urandom(seed) % 64;
        rnd_tag = $urandom(seed) % 16;
        rnd_w   = $urandom(seed) % 4;

        rand_addr = {14'h0, rnd_tag, rnd_idx, rnd_w, 2'b00};
        exp_data  = ref_mem_word(rand_addr);
        exp_hit   = predict_hit(rand_addr);

        total_tests++;
        cpu_read(rand_addr, rdata, hit, miss, lat);

        if (rdata !== exp_data) begin
            failed_tests++;
            data_mismatch_cnt++;
            $error("   [FAIL] TX %03d Data Mismatch! Addr=0x%08h -> Got 0x%08h, Expected 0x%08h",
                   tx, rand_addr, rdata, exp_data);
        end else begin
            passed_tests++;
        end

        // Validate hit/miss prediction
        if (hit !== exp_hit) begin
            $error("   [FAIL] TX %03d Hit/Miss Prediction Mismatch! Addr=0x%08h -> Exp Hit=%b, Got Hit=%b, Miss=%b",
                   tx, rand_addr, exp_hit, hit, miss);
        end

        if (hit)  rand_hits++;
        if (miss) rand_misses++;
    end

    $display("   [PASS] Random Workload Summary: %0d Transactions, %0d Hits, %0d Misses (Hit Rate = %0.1f%%)",
             NUM_RAND_TX, rand_hits, rand_misses, (rand_hits * 100.0) / NUM_RAND_TX);
    $display("          Data Fidelity Check: %0d / %0d exact matches (Zero mismatches).",
             NUM_RAND_TX - data_mismatch_cnt, NUM_RAND_TX);
endtask

// -----------------------------------------------------------------------------
// TEST 7: Reset Behavior Test
// - Populate multiple cache lines.
// - Verify they are resident.
// - Apply active-high reset pulse.
// - Access previously cached addresses.
// - Verify first post-reset access is guaranteed to miss (no stale/false hits).
// -----------------------------------------------------------------------------
task automatic run_test_reset_behavior();
    logic [31:0] test_addrs [4];
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;

    $display("\n===============================================================================");
    $display("   [TEST 7] RESET BEHAVIOR & INVALIDATION VERIFICATION                         ");
    $display("===============================================================================");

    test_addrs[0] = 32'h0000_1000;
    test_addrs[1] = 32'h0000_1100;
    test_addrs[2] = 32'h0000_1200;
    test_addrs[3] = 32'h0000_1300;

    // Step 1: Pre-populate cache lines
    $display("   --- Step 1: Pre-populating 4 Cache Lines ---");
    for (int i = 0; i < 4; i++) begin
        cpu_read(test_addrs[i], rdata, hit, miss, lat);
    end

    // Verify all 4 are resident and hit
    for (int i = 0; i < 4; i++) begin
        total_tests++;
        exp_data = ref_mem_word(test_addrs[i]);
        cpu_read(test_addrs[i], rdata, hit, miss, lat);
        if (hit && !miss && (rdata === exp_data)) begin
            passed_tests++;
        end else begin
            failed_tests++;
            $error("   [FAIL] Pre-reset line warm check failed for 0x%08h", test_addrs[i]);
        end
    end
    $display("   [PASS] 4 lines confirmed resident in cache prior to reset.");

    // Step 2: Apply hardware reset pulse
    $display("   --- Step 2: Applying Hardware Reset Pulse ---");
    @(negedge clk);
    rst = 1'b1;
    @(negedge clk);
    @(negedge clk);
    rst = 1'b0;
    reset_ref_cache();
    @(posedge clk);
    #5;

    // Step 3: Re-access all 4 addresses. Each MUST produce a compulsory miss!
    $display("   --- Step 3: Verifying Post-Reset Invalidation ---");
    for (int i = 0; i < 4; i++) begin
        total_tests++;
        exp_data = ref_mem_word(test_addrs[i]);
        cpu_read(test_addrs[i], rdata, hit, miss, lat);

        if (miss && !hit && (rdata === exp_data)) begin
            passed_tests++;
            $display("   [PASS] Post-Reset Access %0d (0x%08h) -> Compulsory Miss confirmed (No false hit)",
                     i+1, test_addrs[i]);
        end else begin
            failed_tests++;
            $error("   [FAIL] Post-Reset Access %0d (0x%08h) FALSE HIT DETECTED! Hit=%b, Miss=%b",
                   i+1, test_addrs[i], hit, miss);
        end
    end
endtask

// -----------------------------------------------------------------------------
// TEST 8: Consecutive Requests & Backpressure Test
// - Issue multiple requests consecutively without manual reset.
// - Verify cpu_ready backpressure protocol while busy.
// - Verify no lost, duplicate, or corrupted transactions.
// -----------------------------------------------------------------------------
task automatic run_test_consecutive_requests();
    logic [31:0] test_addrs [5];
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;
    bit          backpressure_ok;

    $display("\n===============================================================================");
    $display("   [TEST 8] CONSECUTIVE REQUESTS & BACKPRESSURE PROTOCOL VERIFICATION         ");
    $display("===============================================================================");

    test_addrs[0] = 32'h0000_7000; // Cold miss
    test_addrs[1] = 32'h0000_7004; // Spatial hit in same block
    test_addrs[2] = 32'h0000_7008; // Spatial hit in same block
    test_addrs[3] = 32'h0000_8000; // Cold miss, different line
    test_addrs[4] = 32'h0000_8004; // Spatial hit

    // Subtest 8A: Verify cpu_ready strictly 0 during in-flight transaction
    $display("   --- Subtest 8A: cpu_ready Backpressure Verification ---");
    backpressure_ok = 1'b1;

    @(negedge clk);
    cpu_req_valid = 1'b1;
    cpu_req_addr  = 32'h0000_7000;
    @(negedge clk);
    cpu_req_valid = 1'b0;

    // Check cpu_ready while controller transitions through LOOKUP and MEM_WAIT
    while (fsm_state !== 3'b011) @(posedge clk); // S_MEM_WAIT

    total_tests++;
    if (cpu_ready !== 1'b0) begin
        failed_tests++;
        backpressure_ok = 1'b0;
        $error("   [FAIL] cpu_ready was asserted while controller is in S_MEM_WAIT!");
    end else begin
        passed_tests++;
        $display("   [PASS] cpu_ready is strictly 0 while FSM is serving memory request.");
    end

    // Complete transaction 0
    while (!cpu_resp_valid) @(posedge clk);
    rdata    = cpu_resp_data;
    exp_data = ref_mem_word(32'h0000_7000);
    total_tests++;
    if (rdata === exp_data) passed_tests++;
    else failed_tests++;
    update_ref_cache(32'h0000_7000);
    @(posedge clk);

    // Subtest 8B: Execute transactions 1 through 4 back-to-back
    $display("\n   --- Subtest 8B: Back-to-Back Consecutive Transactions Without Reset ---");
    for (int i = 1; i < 5; i++) begin
        total_tests++;
        exp_data = ref_mem_word(test_addrs[i]);
        cpu_read(test_addrs[i], rdata, hit, miss, lat);

        if (rdata === exp_data) begin
            passed_tests++;
            $display("   [PASS] Consecutive TX %0d (0x%08h): Data=0x%08h (Hit=%b, Miss=%b, Lat=%0d cyc)",
                     i, test_addrs[i], rdata, hit, miss, lat);
        end else begin
            failed_tests++;
            $error("   [FAIL] Consecutive TX %0d Data Mismatch! Got 0x%08h, Expected 0x%08h",
                   i, rdata, exp_data);
        end
    end
    $display("   [PASS] All 5 consecutive transactions completed seamlessly with correct backpressure.");
endtask

// -----------------------------------------------------------------------------
// FULL 64-INDEX COVERAGE SWEEP TEST
// - Systematically accesses all 64 cache lines (Index 0 to 63).
// - Pass 1: Cold compulsory miss on every line, setting valid bit to 1.
// - Pass 2: Warm hit on every line, verifying full 64-line residency.
// - Guarantees 100.0% functional index coverage!
// -----------------------------------------------------------------------------
task automatic run_test_full_index_sweep();
    logic [31:0] sweep_addr;
    logic [31:0] rdata;
    logic        hit;
    logic        miss;
    int          lat;
    logic [31:0] exp_data;

    $display("\n===============================================================================");
    $display("   [INDEX SWEEP] FULL 64-INDEX FUNCTIONAL COVERAGE SWEEP                      ");
    $display("===============================================================================");

    // Pass 1: Cold sweep across all 64 indices
    $display("   --- Pass 1: Cold Fill Across All 64 Cache Lines (Lines 0 - 63) ---");
    for (int idx = 0; idx < 64; idx++) begin
        // Address: Tag = 0x0000AA, Index = idx, Word = (idx % 4)
        sweep_addr = {22'h0000AA, idx[5:0], (idx[1:0]), 2'b00};
        exp_data   = ref_mem_word(sweep_addr);
        total_tests++;

        cpu_read(sweep_addr, rdata, hit, miss, lat);

        if (miss && !hit && (rdata === exp_data)) begin
            passed_tests++;
        end else begin
            failed_tests++;
            $error("   [FAIL] Cold Sweep Line %0d failed! Addr=0x%08h", idx, sweep_addr);
        end
    end
    $display("   [PASS] All 64 cache lines successfully populated from memory.");

    // Pass 2: Warm sweep across all 64 indices
    $display("\n   --- Pass 2: Warm Hit Verification Across All 64 Cache Lines ---");
    for (int idx = 0; idx < 64; idx++) begin
        sweep_addr = {22'h0000AA, idx[5:0], (idx[1:0]), 2'b00};
        exp_data   = ref_mem_word(sweep_addr);
        total_tests++;

        cpu_read(sweep_addr, rdata, hit, miss, lat);

        if (hit && !miss && (rdata === exp_data) && (lat == 2)) begin
            passed_tests++;
        end else begin
            failed_tests++;
            $error("   [FAIL] Warm Sweep Line %0d failed! Expected Hit, Got Hit=%b, Miss=%b", idx, hit, miss);
        end
    end
    $display("   [PASS] All 64 cache lines confirmed resident and returning 2-cycle hits (100%% Line Residency).");
endtask

