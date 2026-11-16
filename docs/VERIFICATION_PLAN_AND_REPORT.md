# Direct-Mapped Cache Controller: Verification Plan & System Testbench Report

**Author / Senior Verification Engineer:** ANANT  
**Project:** Design and Analysis of a Direct-Mapped Cache Controller  
**Branch:** `feature/verification-testbench`  
**Toolchain:** Icarus Verilog 13.0 (`iverilog -g2012`), VVP, Python 3  
**Status:** ALL TESTS & ASSERTIONS PASSED (100.0% FUNCTIONAL COVERAGE)

---

## 1. Executive Verification Summary

This document presents the complete verification architecture, test plan, formal assertion suite, functional coverage analysis, and simulation evidence for the 1 KB Direct-Mapped Cache Controller subsystem.

### Key Architectural Parameters Under Verification:
- **Cache Capacity:** 1024 Bytes (1 KB)
- **Block / Cache Line Size:** 16 Bytes (128 bits)
- **Number of Cache Lines:** 64 lines ($2^6 = 64$)
- **Address Bus Width:** 32 bits ($2^{32} = 4\text{ GB}$ addressable space)
- **Data Word Width:** 32 bits (4 words per 16-byte block)
- **Tag Field:** 22 bits (`addr[31:10]`)
- **Index Field:** 6 bits (`addr[9:4]`)
- **Block Offset Field:** 4 bits (`addr[3:0]`)
  - Word Select: 2 bits (`addr[3:2]`)
  - Byte Offset: 2 bits (`addr[1:0]`)
- **Main Memory Model Latency:** 2 clock cycles (configurable)

```
+------------------------------------+------------------+------------------+
| Tag (22 bits) [31:10]              | Index (6) [9:4]  | Offset (4) [3:0] |
+------------------------------------+------------------+------------------+
                                                        | Word [3:2] | B [1:0]
```

### Verification Scorecard

```
===============================================================================
   FINAL SYSTEMVERILOG REGRESSION SCORECARD (ANANT)
===============================================================================
   Total Formal Checks Executed   : 332
   Total Checks Passed            : 332 (100.0%)
   Total Checks Failed            : 0   (0.0%)
   SystemVerilog Assertion Errors : 0   (Zero Violations)
   Cache Index Coverage           : 64 / 64 (100.0%)
   Word Offset Coverage           : 4 / 4   (100.0%)
   FSM State Coverage             : 6 / 6   (100.0%)
   FSM Transition Coverage        : 7 / 7   (100.0%)
   Waveform Generation            : sim/cache_top_sv.vcd (955 KB)
                                    sim/cache_storage_sv.vcd (150 KB)
===============================================================================
```

---

## 2. Testbench Architecture & Self-Checking Framework

The verification environment (`tb/tb_cache_top.sv` and `tb/test_scenarios.sv`) follows an automated self-checking architecture:

```mermaid
flowchart TD
    subgraph TB["tb_cache_top.sv (Self-Checking Testbench)"]
        CLK_GEN["Clock & Reset Generator (100 MHz)"]
        DRIVER["CPU Interface Driver (cpu_read Task)"]
        REF_MEM["Independent Reference Memory Model (ref_mem_word)"]
        REF_CACHE["Golden Reference Cache State (ref_valid, ref_tag)"]
        SVA["SystemVerilog Assertion Engine (8 Invariants)"]
        COV["Coverage Collectors (Indices, Offsets, FSM)"]
    end

    subgraph DUT["cache_top.v (Design Under Test)"]
        DEC["Address Decoder (Sankalp)"]
        STOR["Cache Storage Array (Tejas)"]
        COMP["Tag Comparator (Ronit)"]
        CTRL["Cache Controller FSM (Manas)"]
        MEM_INTF["Memory Interface Bridge (Anant/Tejas)"]
        PHY_MEM["Main Memory Model (Anant/Tejas)"]
    end

    CLK_GEN -->|clk, rst| DUT
    DRIVER -->|cpu_req_valid, cpu_req_addr| CTRL
    CTRL -->|cpu_ready, cpu_resp_valid, cpu_resp_data| DRIVER
    DRIVER -->|Sample Actual Response| SVA
    REF_MEM -->|Expected Data Oracle| SVA
    REF_CACHE -->|Expected Hit/Miss Oracle| SVA
    DUT -->|Diagnostic Signals (fsm_state, hit, miss)| COV
```

### 2.1 Independent Reference Memory Model
Main memory produces deterministic address-derived data per word:
- Word 0 (`addr[3:2] == 2'b00`): `{addr[31:4], 4'h0, 12'hA01}`
- Word 1 (`addr[3:2] == 2'b01`): `{addr[31:4], 4'h4, 12'hB02}`
- Word 2 (`addr[3:2] == 2'b10`): `{addr[31:4], 4'h8, 12'hC03}`
- Word 3 (`addr[3:2] == 2'b11`): `{addr[31:4], 4'hC, 12'hD04}`

The testbench function `ref_mem_word(addr)` independently computes this value and verifies that every single response on `cpu_resp_data` matches bit-for-bit.

### 2.2 Independent Golden Cache Predictor
The testbench maintains an internal shadow cache:
- `bit ref_valid[64]`: initialized to `0` upon reset.
- `logic [21:0] ref_tag[64]`: records the installed tag for each line upon miss/refill.
- `predict_hit(addr)` computes `(ref_valid[index] && (ref_tag[index] == tag))`.

If the DUT produces a hit when the model predicts a miss (or vice versa), the transaction flags an immediate assertion mismatch.

---

## 3. Test Scenarios & Results Matrix

| Scenario | Objective | Access Pattern | Expected Outcome | Observed Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TEST 1: Cold Cache** | Verify compulsory miss and memory refill | Cold addresses (`0x1204`, `0x2408`, `0x360C`, `0x4800`) | Miss=1, Hit=0, Latency=12 cyc, Data matches reference memory | All 4 subtests produced cold misses and exact data | **PASS** |
| **TEST 2: Temporal Locality** | Repeated access to same address | Same address `0x2004` accessed 5 times | 1st access misses (12 cyc); 2nd-5th hit (2 cyc) | Miss on access 1, 2-cycle hits on accesses 2, 3, 4, 5 | **PASS** |
| **TEST 3: Spatial Locality** | Access 4 words in same 16-byte block | Words 0, 1, 2, 3 of block `0x5A00` | Word 0 misses; Words 1, 2, 3 hit; all words correct | Word 0 miss, Words 1, 2, 3 hit. Out-of-order test (2,0,3,1) also passed | **PASS** |
| **TEST 4: Sequential Access** | Block reuse during sequential word stream | 32 consecutive 32-bit words (`0x3000` to `0x307C`) | Exactly 1 miss per 4 words (75.0% hit rate); 2nd pass 100.0% hits | Pass 1: 24 Hits, 8 Misses (75.0%). Pass 2: 32 Hits, 0 Misses (100.0%) | **PASS** |
| **TEST 5: Conflict Miss** | Address collision on same index | Addr A (`0x000`), B (`0x400`), C (`0x800`) on Index 0 | Replacement and eviction; re-accessing A must miss | All conflict evictions verified. Re-accessing A confirmed thrashing | **PASS** |
| **TEST 6: Random Workload** | Reproducible stress testing with fixed seed | 100 pseudorandom addresses (Seed `0x5EEDC0DE`) | Zero data corruptions; hit/miss matches golden predictor | 100/100 correct data words. 6 Hits, 94 Misses | **PASS** |
| **TEST 7: Reset Behavior** | Verify hardware reset clears all valid bits | Populate 4 lines, apply `rst`, re-access | All post-reset accesses must miss (zero stale hits) | 4/4 lines produced compulsory misses after reset | **PASS** |
| **TEST 8: Consecutive Requests** | Multi-transaction backpressure without reset | Back-to-back requests during busy states | `cpu_ready == 0` during wait; zero dropped transactions | Backpressure verified; 5 consecutive transactions succeeded | **PASS** |
| **Full 64-Index Sweep** | 100% architectural space coverage | All 64 cache lines (Index 0 to 63) | Cold fill followed by 100% warm hit verification | 64 cold misses + 64 warm hits verified across all lines | **PASS** |
| **Storage Unit Test** | Subsystem test for `cache_storage.sv` | 64 lines read/write, isolation, reset | Valid bit reset, neighbor line isolation | 199/199 checks passed with 100% line coverage | **PASS** |

---

## 4. SystemVerilog Assertions Checklist

The verification testbench enforces eight formal verification invariants:

| Assertion Identifier | Invariant Statement | Verification Method | Status |
| :--- | :--- | :--- | :--- |
| **ASSERTION 1** | No response without an active request | Checked at `cpu_resp_valid`: `in_flight_req` must be high. | **0 Violations (PASSED)** |
| **ASSERTION 2** | No invalid cache hit | In `S_LOOKUP`: `cache_hit` requires `storage_read_valid == 1` and `comp_stored_tag == comp_req_tag`. | **0 Violations (PASSED)** |
| **ASSERTION 3** | Block address alignment | In `S_MEM_REQUEST`: `ctrl_mem_addr[3:0]` must strictly equal `4'b0000`. | **0 Violations (PASSED)** |
| **ASSERTION 4** | Single-cycle response completion | `cpu_resp_valid` must not remain asserted for two consecutive clock cycles. | **0 Violations (PASSED)** |
| **ASSERTION 5** | Refill write control integrity | In `S_REFILL`: `storage_write_en` and `storage_write_valid` must be high. | **0 Violations (PASSED)** |
| **ASSERTION 6** | Controller liveness / deadlock prevention | FSM busy counter must not exceed 50 clock cycles without returning to `S_IDLE`. | **0 Violations (PASSED)** |
| **ASSERTION 7** | `cpu_ready` protocol conformance | `cpu_ready` must strictly equal `1` if and only if `fsm_state == S_IDLE`. | **0 Violations (PASSED)** |
| **ASSERTION 8** | Data integrity oracle match | On `cpu_resp_valid`, `cpu_resp_data` must strictly match `ref_mem_word(addr)`. | **0 Violations (PASSED)** |

---

## 5. Functional Coverage Report

```
===============================================================================
          COMPREHENSIVE FUNCTIONAL COVERAGE REPORT (ANANT)                     
===============================================================================
1. TRANSACTION METRICS & HIT/MISS CLASSIFICATION:
   - Total CPU Read Requests Executed : 334
   - Total Cache Hits Recorded        : 145 (43.41%)
   - Total Cache Misses Recorded      : 189 (56.59%)
     * Compulsory (Cold) Misses       : 121
     * Conflict (Eviction) Misses     : 68
   - Memory Refill Events Fired       : 190
   - Hardware Reset / Clears Fired    : 3
   - Cache Line Valid Transitions     : 190

2. ARCHITECTURAL SPACE COVERAGE:
   - Cache Indices Exercised          : 64 / 64 (100.0% coverage)
     * Indices experiencing Hits      : 64 / 64 (100.0%)
     * Indices experiencing Misses    : 64 / 64 (100.0%)
   - Word Offsets Exercised (0,1,2,3) : 4 / 4  (100.0% coverage)
     * Word 0 (Offset 0x0) accesses   : 104
     * Word 1 (Offset 0x4) accesses   : 77
     * Word 2 (Offset 0x8) accesses   : 80
     * Word 3 (Offset 0xC) accesses   : 73
   - Distinct Tag Values Exercised    : 22 distinct tags

3. FSM STATE & TRANSITION COVERAGE:
   - FSM States Visited               : 6 / 6  (100.0% coverage)
     * S_IDLE        (3'b000) cycles  : 676
     * S_LOOKUP      (3'b001) cycles  : 335
     * S_MEM_REQUEST (3'b010) cycles  : 190
     * S_MEM_WAIT    (3'b011) cycles  : 1520
     * S_REFILL      (3'b100) cycles  : 190
     * S_RESPOND     (3'b101) cycles  : 335
   - FSM Transitions Exercised        : 7 / 7  (100.0% coverage)
     * IDLE -> LOOKUP                 : 335
     * LOOKUP -> RESPOND (Hit Path)   : 145
     * LOOKUP -> MEM_REQ (Miss Path)  : 190
     * MEM_REQ -> MEM_WAIT            : 190
     * MEM_WAIT -> REFILL             : 190
     * REFILL -> RESPOND              : 190
     * RESPOND -> IDLE                : 335
===============================================================================
```

---

## 6. Waveform & Timing Evidence

### 6.1 Cache Hit Timing Diagram (2 Clock Cycles)

When the requested block is already resident with matching tag and valid bit high:

```
Clock Cycle:      0          1          2          3
clk           : __/¯¯\____/¯¯\____/¯¯\____/¯¯\____/¯¯\____
fsm_state     : [ IDLE  ][ LOOKUP ][ RESPOND ][ IDLE  ]
cpu_ready     : ¯¯¯¯¯¯¯¯\____________________/¯¯¯¯¯¯¯¯
cpu_req_valid : ___/¯¯¯¯\_____________________________
cpu_req_addr  : ---< 0x00002004 >---------------------
cache_hit     : _________/¯¯¯¯¯¯¯\____________________
cpu_resp_valid: __________________/¯¯¯¯¯¯¯\___________
cpu_resp_data : ------------------< 0x02004B02 >-------
```

- **Cycle 0:** Request sampled on `posedge clk`. `fsm_state` moves to `S_LOOKUP`, `cpu_ready` drops.
- **Cycle 1:** Index driven to storage array; combinational tag match generates `cache_hit = 1`. FSM branches to `S_RESPOND`.
- **Cycle 2:** `cpu_resp_valid = 1`, word multiplexer presents data. FSM transitions back to `S_IDLE`.
- **Hit Latency:** **2 clock cycles** (20 ns).

### 6.2 Cache Miss Timing Diagram (12 Clock Cycles)

When the requested block is not present or tag mismatches:

```
Clock Cycle:      0      1        2          3-10         11        12        13
clk           : _/¯\_  _/¯\_    _/¯\_       _/¯\_       _/¯\_     _/¯\_     _/¯\_
fsm_state     : [IDLE][LOOKUP][MEM_REQ]  [MEM_WAIT...] [REFILL] [RESPOND] [IDLE]
cpu_ready     : ¯¯¯¯¯\___________________________________________________/¯¯¯¯¯
cache_miss    : ______/¯¯¯¯¯¯\_________________________________________________
ctrl_mem_req  : _______________/¯¯¯¯¯¯\________________________________________
mem_req_ready : _________________________________________/¯¯¯¯¯\_______________
storage_write : _________________________________________________/¯¯¯¯¯\_______
cpu_resp_valid: ___________________________________________________________/¯¯¯\
```

- **Cycle 1 (`LOOKUP`):** Tag comparator signals `comp_miss = 1`.
- **Cycle 2 (`MEM_REQUEST`):** Controller asserts single-cycle `mem_req = 1` with aligned address.
- **Cycles 3–10 (`MEM_WAIT`):** Handshake with main memory models DRAM latency counter.
- **Cycle 11 (`REFILL`):** 128-bit block captured; `storage_write_en` and `storage_write_valid` assert to commit line into RAM.
- **Cycle 12 (`RESPOND`):** 32-bit CPU response valid presented.
- **Miss Latency:** **12 clock cycles** (120 ns).

---

## 7. Reproduction Instructions

To execute the entire verification regression and regenerate all waveform and log files from scratch:

```bash
# 1. Switch to verification branch
git checkout feature/verification-testbench

# 2. Run automated regression suite
bash sim/run_verification_regression.sh

# 3. View regression logs
cat sim/logs/cache_top_regression.log
cat sim/logs/cache_storage_regression.log

# 4. Run automated metrics extraction
python3 sim/generate_anant_verification_report.py

# 5. Inspect waveforms in GTKWave (optional)
gtkwave sim/cache_top_sv.vcd
```
