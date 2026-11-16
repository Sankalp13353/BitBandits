# Synthesis Evaluation & Hardware Resource Utilization Report

**Project Title:** Design and Analysis of a Direct-Mapped Cache Controller  
**Technical Role:** Senior Computer Architecture Performance Analyst & Digital Synthesis Engineer (RONIT)  
**Synthesis Toolchain:** Yosys Open SYnthesis Suite 0.71+ (Release, AppleClang)  
**Target Technology:** Generic Synthesizable Gate-Level Standard Cells & Inferred Primitives  
**Status:** Fully Verified RTL & Gate-Level Synthesized  

---

## 1. Executive Synthesis Summary

All RTL modules across the 5-member team architecture were evaluated using Yosys.
The design adheres strictly to synthesizable Verilog-2005 / SystemVerilog constructs without non-synthesizable timing delays (`#delay`) or simulation-only pragmas in synthesizable modules.

| Module Name | Designer | Module Architectural Role | Total Cells | Sequential Elements (DFFs) | Combinational Logic Cells | Synthesis Status |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| `tag_comparator` | **Ronit** | Combinational / Validation | 46 | 0 | 46 | **PASS** |
| `address_decoder` | **Sankalp** | Combinational / Bit-Slicing | 0 | 0 | 0 | **PASS** |
| `cache_controller` | **Manas** | Sequential FSM & Datapath | 1024 | 289 | 735 | **PASS** |
| `valid_bit_ram` | **Tejas** | Storage Submodule (64 x 1-bit) | 481 | 64 | 417 | **PASS** |
| `tag_ram` | **Tejas** | Storage Submodule (64 x 22-bit) | 2980 | 1408 | 1572 | **PASS** |
| `cache_data_ram` | **Tejas** | Storage Submodule (64 x 128-bit) | 16548 | 8192 | 8356 | **PASS** |
| `cache_storage` | **Tejas** | Integrated 1 KB Storage Subsystem | 6 | 19328 | 60738 | **PASS** |
| `memory_interface` | **Anant / Tejas** | Bus Protocol Bridge FSM | 227 | 197 | 30 | **PASS** |
| `cache_top` | **Manas (Integration Lead)** | Top-Level Integrated Subsystem | 5 | 20380 | 65309 | **PASS** |

---

## 2. In-Depth Submodule Resource Breakdown

### 2.1 Module: `tag_comparator` (Ronit)
- **Top-Level Entity:** `tag_comparator`
- **Architectural Classification:** Combinational / Validation
- **Total Gate / Cell Count:** 46
- **Sequential Elements (Flip-Flops):** 0
- **Combinational Gate Elements:** 46
- **Interconnect Wires:** 12 (91 wire bits, 6 public wires)
- **Cell Breakdown:**
  * `$_XOR_`: 22
  * `$_OR_`: 21
  * `$_NOT_`: 2
  * `$_AND_`: 1
- **Synthesis Diagnostics / Warnings:** 0 warnings recorded.

### 2.2 Module: `address_decoder` (Sankalp)
- **Top-Level Entity:** `address_decoder`
- **Architectural Classification:** Combinational / Bit-Slicing
- **Total Gate / Cell Count:** 0
- **Sequential Elements (Flip-Flops):** 0
- **Combinational Gate Elements:** 0
- **Interconnect Wires:** 7 (100 wire bits, 7 public wires)
- **Cell Breakdown:**
  * *Pure wire passthrough / constant propagation*
- **Synthesis Diagnostics / Warnings:** 0 warnings recorded.

### 2.3 Module: `cache_controller` (Manas)
- **Top-Level Entity:** `cache_controller`
- **Architectural Classification:** Sequential FSM & Datapath
- **Total Gate / Cell Count:** 1024
- **Sequential Elements (Flip-Flops):** 289
- **Combinational Gate Elements:** 735
- **Interconnect Wires:** 276 (1615 wire bits, 37 public wires)
- **Cell Breakdown:**
  * `$_MUX_`: 457
  * `$_DFFE_PP0P_`: 286
  * `$_AND_`: 134
  * `$_OR_`: 127
  * `$_NOT_`: 17
  * `$_DFF_PP0_`: 3
- **Synthesis Diagnostics / Warnings:** 0 warnings recorded.

### 2.4 Module: `valid_bit_ram` (Tejas)
- **Top-Level Entity:** `valid_bit_ram`
- **Architectural Classification:** Storage Submodule (64 x 1-bit)
- **Total Gate / Cell Count:** 481
- **Sequential Elements (Flip-Flops):** 64
- **Combinational Gate Elements:** 417
- **Interconnect Wires:** 371 (541 wire bits, 71 public wires)
- **Cell Breakdown:**
  * `$_OR_`: 218
  * `$_AND_`: 128
  * `$_NOT_`: 70
  * `$_DFFE_PP0P_`: 64
  * `$_MUX_`: 1
- **Synthesis Diagnostics / Warnings:** 1 warnings recorded.
  > [!NOTE] Warning: Replacing memory \valid_mem with list of registers. See rtl/valid_bit_ram.v:54

### 2.5 Module: `tag_ram` (Tejas)
- **Top-Level Entity:** `tag_ram`
- **Architectural Classification:** Storage Submodule (64 x 22-bit)
- **Total Gate / Cell Count:** 2980
- **Sequential Elements (Flip-Flops):** 1408
- **Combinational Gate Elements:** 1572
- **Interconnect Wires:** 291 (3010 wire bits, 69 public wires)
- **Cell Breakdown:**
  * `$_MUX_`: 1414
  * `$_DFFE_PP_`: 1408
  * `$_AND_`: 152
  * `$_NOT_`: 6
- **Synthesis Diagnostics / Warnings:** 0 warnings recorded.

### 2.6 Module: `cache_data_ram` (Tejas)
- **Top-Level Entity:** `cache_data_ram`
- **Architectural Classification:** Storage Submodule (64 x 128-bit)
- **Total Gate / Cell Count:** 16548
- **Sequential Elements (Flip-Flops):** 8192
- **Combinational Gate Elements:** 8356
- **Interconnect Wires:** 291 (16684 wire bits, 69 public wires)
- **Cell Breakdown:**
  * `$_MUX_`: 8198
  * `$_DFFE_PP_`: 8192
  * `$_AND_`: 152
  * `$_NOT_`: 6
- **Synthesis Diagnostics / Warnings:** 0 warnings recorded.

### 2.7 Module: `cache_storage` (Tejas)
- **Top-Level Entity:** `cache_storage`
- **Architectural Classification:** Integrated 1 KB Storage Subsystem
- **Total Gate / Cell Count:** 6
- **Sequential Elements (Flip-Flops):** 19328
- **Combinational Gate Elements:** 60738
- **Interconnect Wires:** 12 (323 wire bits, 12 public wires)
- **Cell Breakdown:**
  * `cache_storage`: 20015
  * `$_MUX_`: 9619
  * `$_DFFE_PP_`: 9600
  * `$_AND_`: 432
  * `$_OR_`: 218
  * `$_NOT_`: 82
  * `$_DFFE_PP0P_`: 64
  * `submodules`: 3
  * `$paramod$4272797ce548d98f6eb5f4683daa4c769f75ab46\cache_data_ram`: 1
  * `$paramod$795f81b8c403f716819727ed3a467264497cdaf7\tag_ram`: 1
  * `$paramod$e019f90c0ea90be45f7788f2829c919ea374a9da\valid_bit_ram`: 1
- **Synthesis Diagnostics / Warnings:** 2 warnings recorded.
  > [!NOTE] Warning: Replacing memory \valid_mem with list of registers. See rtl/valid_bit_ram.v:54
  > [!NOTE] Warning: Replacing memory \valid_mem with list of registers. See rtl/valid_bit_ram.v:54

### 2.8 Module: `memory_interface` (Anant / Tejas)
- **Top-Level Entity:** `memory_interface`
- **Architectural Classification:** Bus Protocol Bridge FSM
- **Total Gate / Cell Count:** 227
- **Sequential Elements (Flip-Flops):** 197
- **Combinational Gate Elements:** 30
- **Interconnect Wires:** 40 (391 wire bits, 13 public wires)
- **Cell Breakdown:**
  * `$_DFFE_PP0P_`: 195
  * `$_AND_`: 8
  * `$_MUX_`: 8
  * `$_OR_`: 8
  * `$_NOT_`: 6
  * `$_DFF_PP0_`: 2
- **Synthesis Diagnostics / Warnings:** 0 warnings recorded.

### 2.9 Module: `cache_top` (Manas (Integration Lead))
- **Top-Level Entity:** `cache_top`
- **Architectural Classification:** Top-Level Integrated Subsystem
- **Total Gate / Cell Count:** 5
- **Sequential Elements (Flip-Flops):** 20380
- **Combinational Gate Elements:** 65309
- **Interconnect Wires:** 35 (763 wire bits, 32 public wires)
- **Cell Breakdown:**
  * `cache_top`: 21417
  * `$paramod$4272797ce548d98f6eb5f4683daa4c769f75ab46\cache_data_ram`: 16548
  * `$_MUX_`: 10100
  * `$_DFFE_PP_`: 9600
  * `$paramod$795f81b8c403f716819727ed3a467264497cdaf7\tag_ram`: 2980
  * `$_AND_`: 590
  * `$_DFFE_PP0P_`: 584
  * `$paramod$e019f90c0ea90be45f7788f2829c919ea374a9da\valid_bit_ram`: 481
  * `$_OR_`: 394
  * `$_NOT_`: 118
  * `$_XOR_`: 25
  * `$_DFF_PP0_`: 6
  * `submodules`: 5
  * `$paramod$4140376369aa40eb58e681ba60da649abb503600\memory_interface`: 1
  * `$paramod$619ea51db917bc78d7ceaa65c1b82f64266c127e\cache_storage`: 1
  * `$paramod$b9ec6491c0f390d6d50b95dea23a2a749aeab6f4\cache_controller`: 1
  * `$paramod$bf14abd7464082e86250c6aa763cddd59997452a\main_memory`: 1
  * `$paramod\tag_comparator\TAG_WIDTH=s32'00000000000000000000000000010110`: 1
- **Synthesis Diagnostics / Warnings:** 2 warnings recorded.
  > [!NOTE] Warning: Replacing memory \valid_mem with list of registers. See rtl/valid_bit_ram.v:54
  > [!NOTE] Warning: Replacing memory \valid_mem with list of registers. See rtl/valid_bit_ram.v:54

---

## 3. Storage RAM Inference & Synthesis Characteristics

### 3.1 Analysis of Inferred RAM vs Dedicated Hardware Macrocells
A fundamental digital synthesis inquiry is whether the cache storage arrays (`valid_bit_ram`, `tag_ram`, `cache_data_ram`) infer dedicated synchronous Block RAMs (BRAM) or distributed discrete flip-flop / latch arrays:

1. **Valid-Bit RAM (`valid_bit_ram.v` - 64 x 1 bit):**
   - Features a synchronous full-array reset (`rst`) that clears all 64 lines in a single clock cycle (`for (i=0; i<64; i=i+1) valid_bits[i] <= 1'b0;`).
   - **Synthesis Implication:** FPGA dedicated BRAM primitives (e.g. Xilinx RAMB18/36 or Intel M10K) do NOT support clearing all addresses in a single cycle. Consequently, Yosys correctly synthesizes this structure into **64 discrete D-type Flip-Flops (DFFs)** with reset lines, augmented with 6-to-64 address decoding and multiplexing logic. This provides instantaneous single-cycle cold invalidation.

2. **Tag RAM (`tag_ram.v` - 64 x 22 bits = 1,408 bits) & Data RAM (`cache_data_ram.v` - 64 x 128 bits = 8,192 bits):**
   - Designed with synchronous clock-edge write (`posedge clk`) and asynchronous (combinational) read (`assign read_data = ram[read_index]`).
   - **Synthesis Implication:** Synchronous Block RAM blocks require synchronous (clocked) read ports (registered output). Because the direct-mapped cache controller requires asynchronous / combinational tag and data lookup in `S_LOOKUP` to minimize hit latency to 1-2 clock cycles, the memory compiler maps these storage arrays to distributed register flip-flops and wide multiplexers unless dedicated vendor asynchronous SRAM macros or Block RAM output registers are configured.
   - This behavior is fully documented and conforms strictly to standard digital IC synthesis rules.

### 3.2 Separation of Behavioral Main Memory vs Synthesizable Cache Subsystem
- `main_memory.v` is an architectural simulation/verification DRAM model. It synthesizes into combinational address-embedding logic and a 4-bit latency counter, rather than physical 4 GB DRAM, which correctly reflects modern SoC verification boundaries.
- The cache controller (`cache_controller.v`), tag comparator (`tag_comparator.v`), address decoder (`address_decoder.v`), and cache storage (`cache_storage.v`) form the true synthesizable ASIC/FPGA hardware core.

---

## 4. Hardware Gate Count Summary

```
+--------------------------------------------------------------------------------+
|                     SYNTHESIS GATE-LEVEL UTILIZATION                           |
+-----------------------+-------------+-------------+-------------+--------------+
| Module                | Total Cells | Sequential  | Combinat.   | Wires (Bits) |
+-----------------------+-------------+-------------+-------------+--------------+
| tag_comparator        |          46 |           0 |          46 |     12 (   91) |
| address_decoder       |           0 |           0 |           0 |      7 (  100) |
| cache_controller      |        1024 |         289 |         735 |    276 ( 1615) |
| valid_bit_ram         |         481 |          64 |         417 |    371 (  541) |
| tag_ram               |        2980 |        1408 |        1572 |    291 ( 3010) |
| cache_data_ram        |       16548 |        8192 |        8356 |    291 (16684) |
| cache_storage         |           6 |       19328 |       60738 |     12 (  323) |
| memory_interface      |         227 |         197 |          30 |     40 (  391) |
| cache_top             |           5 |       20380 |       65309 |     35 (  763) |
+-----------------------+-------------+-------------+-------------+--------------+
```
