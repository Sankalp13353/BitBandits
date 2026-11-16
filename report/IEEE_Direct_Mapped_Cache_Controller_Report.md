# DESIGN AND ANALYSIS OF A 1 KB DIRECT-MAPPED CACHE CONTROLLER USING VERILOG HDL

**Team Members:** Manas, Sankalp, Tejas, Anant, and Ronit  
**Department:** Computer Science and Engineering

## I. ABSTRACT

Cache memory improves processor performance by reducing average memory access time. This project presents the design and verification of a 1 KB direct-mapped cache controller using Verilog HDL. The architecture uses 32-bit addresses, 16-byte blocks, and 64 cache lines. It includes data, tag and valid-bit storage, an address decoder, tag comparator, controller FSM, and main-memory interface. The design supports read requests, cache hit/miss detection, memory access, and block refill. Its performance is evaluated using sequential, repeated, random, and conflict-based access patterns.

## II. LITERATURE REVIEW

Cache memory is an important part of the memory hierarchy, providing faster access to frequently or recently used data. Its effectiveness relies on temporal locality, where recently accessed data is likely to be accessed again, and spatial locality, where nearby memory locations are likely to be accessed.

In a direct-mapped cache, each memory block maps to exactly one cache line. The address is divided into tag, index, and block-offset fields. A cache hit occurs when the selected line is valid and its stored tag matches the requested tag. Otherwise, a cache miss occurs and data must be fetched from main memory.

Cache performance is commonly evaluated using hit ratio, miss ratio, and Average Memory Access Time (AMAT). These concepts form the foundation of the proposed design [1]–[3].

## III. PROPOSED SOLUTION

### A. Architecture and Configuration

The proposed cache has a capacity of 1 KB, divided into 64 lines of 16 bytes each. Every line stores four 32-bit words.

| Parameter | Specification |
|---|---|
| Cache capacity | 1 KB |
| Block size | 16 bytes |
| Number of lines | 64 |
| Address width | 32 bits |
| Tag / Index / Offset | 22 / 6 / 4 bits |
| Mapping | Direct-mapped |

### B. Address Mapping

The 32-bit address is divided into three fields:

- **Tag:** `address[31:10]` (22 bits)
- **Index:** `address[9:4]` (6 bits)
- **Block Offset:** `address[3:0]` (4 bits)

The index selects one of the 64 cache lines, while the tag identifies the memory block stored in that line. The word selector is obtained from `address[3:2]`.

### C. Cache Operation

The controller uses a six-state FSM:

`IDLE → LOOKUP → MEM_REQUEST → MEM_WAIT → REFILL → RESPOND`

When a CPU read request arrives, the controller checks the selected cache line. If the valid bit is set and the tag matches, the requested 32-bit word is returned. Otherwise, a miss occurs, and the controller requests the corresponding 16-byte block from main memory. The returned block is stored in the cache, the tag and valid bit are updated, and the requested word is returned.

The implementation is read-only and supports one outstanding request at a time.

### D. Verification Methodology

The design is verified using Verilog and SystemVerilog testbenches. Tests cover address decoding, storage operations, cache hits and misses, block refill, reset behavior, and top-level integration. Sequential, repeated, random, and conflict-oriented memory access patterns are used to evaluate cache behavior.

## IV. RESULTS AND DISCUSSION

### A. Functional Verification

The recorded regression results include:

| Test | Checks Passed |
|---|---:|
| Address Decoder | 72/72 |
| Cache Data RAM | 68/68 |
| Tag RAM | 68/68 |
| Valid-Bit RAM | 133/133 |
| Cache Storage | 205/205 |
| Top-Level Integration | 7/7 |
| Top-Level SystemVerilog | 332/332 |

The memory subsystem tests passed for TC1–TC4 and TC6–TC7. TC5 had a known testbench handshake mismatch and is not counted as a pass. Python cross-validation also matched the reference simulator across six scenarios.

### B. Cache Performance Analysis

The following results were obtained using the recorded access-pattern analysis.

| Access Pattern | Hit Ratio | Miss Ratio | AMAT (cycles) |
|---|---:|---:|---:|
| Sequential | 75.00% | 25.00% | 3.00 |
| Repeated | 96.88% | 3.12% | 1.25 |
| Conflict | 0.00% | 100.00% | 9.00 |
| Random | 20.60% | 79.40% | 7.35 |

AMAT is calculated using:

**AMAT = Hit Time + (Miss Rate × Miss Penalty)**

The analysis assumes a hit time of 1 cycle and a miss penalty of 8 cycles. These are analytical assumptions, not measured full transaction latencies of the controller FSM.

Repeated accesses achieve the highest hit ratio due to temporal locality, whereas conflict accesses result in repeated misses because multiple memory blocks compete for the same cache line.

### C. Synthesis Results

Yosys synthesis of the top-level design reported:

- Total inferred cells: 21,449
- Sequential flip-flops: 10,222
- Multiplexer bits: 10,100
- Inferred latches: 0
- Inferred memory bits: 0

These results describe the synthesis statistics from the recorded run and do not represent physical chip area or timing measurements.

## V. INDIVIDUAL CONTRIBUTIONS

- **Manas:** Cache controller FSM, top-level integration, and integration testing.
- **Sankalp:** Address decoder, cache data RAM, tag RAM, valid-bit RAM, cache storage, and related verification.
- **Ronit:** Tag comparator, Python cross-validation, AMAT analysis, and synthesis automation.
- **Anant:** Main-memory and memory-interface development, along with verification.
- **Tejas:** Memory-interface and main-memory subsystem development and testing.

## VI. CONCLUSION

The project demonstrates the implementation of a 1 KB direct-mapped cache controller using Verilog HDL. The design supports address decoding, cache lookup, hit/miss detection, memory requests, and block refill. Functional verification demonstrates the operation of the cache across multiple test scenarios. Performance analysis highlights the effect of temporal and spatial locality on cache hit ratios and AMAT. The current implementation focuses on read operations and can be extended with write support and additional performance optimizations in future work.

## VII. REFERENCES

[1] A. J. Smith, “Cache Memories,” *ACM Computing Surveys*, vol. 14, no. 3, pp. 473–530, Sept. 1982.

[2] N. P. Jouppi, “Improving Direct-Mapped Cache Performance by the Addition of a Small Fully-Associative Cache and Prefetch Buffers,” *Proceedings of the 17th Annual International Symposium on Computer Architecture*, 1990, pp. 364–373.

[3] D. A. Patterson and J. L. Hennessy, *Computer Organization and Design: The Hardware/Software Interface*, 2nd ed., RISC-V Edition. Morgan Kaufmann, 2021.

[4] J. L. Hennessy and D. A. Patterson, *Computer Architecture: A Quantitative Approach*, 6th ed. Morgan Kaufmann, 2019.

[5] YosysHQ, “Yosys Open SYnthesis Suite Documentation.” https://yosyshq.net/yosys/

[6] Icarus Verilog, “Icarus Verilog Documentation.” https://steveicarus.github.io/iverilog/
