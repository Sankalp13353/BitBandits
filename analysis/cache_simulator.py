#!/usr/bin/env python3
"""
Direct-Mapped Cache Controller: Cycle & State Simulator
Author: Ronit (Senior Computer Architecture Performance Analyst)
Project: Design and Analysis of a Direct-Mapped Cache Controller

Accurately models the direct-mapped cache hardware architecture and maintains
an independent Fully Associative reference model for rigorous 3C miss classification
(Compulsory, Capacity, Conflict) according to the Hill & Smith (1989) model.

Cache Geometry:
  - Capacity: 1024 Bytes (1 KB)
  - Block size: 16 Bytes (4 x 32-bit words)
  - Lines: 64
  - Tag: address[31:10] (22 bits)
  - Index: address[9:4] (6 bits)
  - Offset: address[3:0] (4 bits)
  - Word Select: address[3:2] (2 bits)
"""

from collections import OrderedDict
from dataclasses import dataclass
from typing import List, Optional, Dict, Any


@dataclass
class CacheLine:
    valid: bool = False
    tag: int = 0
    data: List[int] = None

    def __post_init__(self):
        if self.data is None:
            self.data = [0, 0, 0, 0]


@dataclass
class AccessRecord:
    access_id: int
    address: int
    tag: int
    index: int
    offset: int
    word_sel: int
    block_addr: int
    hit: bool
    miss: bool
    miss_type: Optional[str]  # "compulsory", "conflict", "capacity", or None
    refill: bool
    evicted_tag: Optional[int]
    returned_data: int


def compute_golden_word(addr: int) -> int:
    """
    Computes expected 32-bit word matching the RTL main_memory / tb reference model:
      word[0] = { block_addr[31:4], 4'h0, 12'hA01 }
      word[1] = { block_addr[31:4], 4'h4, 12'hB02 }
      word[2] = { block_addr[31:4], 4'h8, 12'hC03 }
      word[3] = { block_addr[31:4], 4'hC, 12'hD04 }
    """
    b_addr = addr & ~0xF
    w_sel = (addr >> 2) & 0x3
    suffix_map = {0: 0x0A01, 1: 0x4B02, 2: 0x8C03, 3: 0xCD04}
    # In 32-bit truncation: bits [31:16] are (b_addr >> 4) & 0xFFFF, bits [15:0] are suffix
    high_part = ((b_addr >> 4) & 0xFFFF) << 16
    low_part = suffix_map[w_sel]
    return (high_part | low_part) & 0xFFFFFFFF


class DirectMappedCacheSimulator:
    def __init__(self, capacity_bytes: int = 1024, block_size: int = 16):
        self.capacity_bytes = capacity_bytes
        self.block_size = block_size
        self.num_lines = capacity_bytes // block_size  # 64 lines for 1 KB / 16 B
        self.lines: List[CacheLine] = [CacheLine() for _ in range(self.num_lines)]

        # 3C Reference Model:
        # 1. Unbounded history set to identify Compulsory (Cold) misses
        self.seen_blocks = set()

        # 2. Fully Associative Cache of identical capacity (64 blocks) with LRU replacement
        # to distinguish Conflict misses from Capacity misses
        self.fa_cache = OrderedDict()  # block_addr -> None (OrderedDict used as LRU set)

        # Performance counters
        self.total_accesses = 0
        self.hits = 0
        self.misses = 0
        self.compulsory_misses = 0
        self.conflict_misses = 0
        self.capacity_misses = 0
        self.refills = 0
        self.history: List[AccessRecord] = []

    def reset(self):
        """Hardware reset: clears all valid bits and resets reference models."""
        for line in self.lines:
            line.valid = False
            line.tag = 0
            line.data = [0, 0, 0, 0]
        self.seen_blocks.clear()
        self.fa_cache.clear()
        self.total_accesses = 0
        self.hits = 0
        self.misses = 0
        self.compulsory_misses = 0
        self.conflict_misses = 0
        self.capacity_misses = 0
        self.refills = 0
        self.history.clear()

    def access(self, addr: int) -> AccessRecord:
        """Process a single CPU read access through the direct-mapped cache."""
        addr = addr & 0xFFFFFFFF
        tag = (addr >> 10) & 0x3FFFFF
        index = (addr >> 4) & 0x3F
        offset = addr & 0xF
        word_sel = (addr >> 2) & 0x3
        block_addr = addr & ~0xF

        line = self.lines[index]
        is_hit = False
        is_miss = False
        miss_type = None
        evicted_tag = None
        refill = False

        self.total_accesses += 1

        if line.valid and (line.tag == tag):
            # Cache Hit
            is_hit = True
            self.hits += 1
            returned_data = line.data[word_sel]
            # Update FA cache LRU ordering
            if block_addr in self.fa_cache:
                self.fa_cache.move_to_end(block_addr)
        else:
            # Cache Miss
            is_miss = True
            self.misses += 1
            refill = True
            self.refills += 1

            if line.valid:
                evicted_tag = line.tag

            # Classify Miss using Hill & Smith Reference Model
            if block_addr not in self.seen_blocks:
                # First time this block has ever been referenced -> Compulsory
                miss_type = "compulsory"
                self.compulsory_misses += 1
                self.seen_blocks.add(block_addr)
            else:
                # Block has been referenced before
                if block_addr in self.fa_cache:
                    # In a fully associative cache with identical capacity,
                    # this block would still be resident. Therefore, the miss
                    # in our direct-mapped cache is due to index collision!
                    miss_type = "conflict"
                    self.conflict_misses += 1
                else:
                    # Even in a fully associative cache with optimal/LRU replacement,
                    # this block was evicted because the working set of unique blocks
                    # exceeds cache capacity.
                    miss_type = "capacity"
                    self.capacity_misses += 1

            # Update Fully Associative reference cache
            if block_addr in self.fa_cache:
                self.fa_cache.move_to_end(block_addr)
            else:
                if len(self.fa_cache) >= self.num_lines:
                    self.fa_cache.popitem(last=False)  # Evict LRU block
                self.fa_cache[block_addr] = None

            # Simulate memory block fetch and refill into direct-mapped line
            refilled_block = [compute_golden_word(block_addr + (w * 4)) for w in range(4)]
            line.valid = True
            line.tag = tag
            line.data = refilled_block
            returned_data = refilled_block[word_sel]

        record = AccessRecord(
            access_id=self.total_accesses - 1,
            address=addr,
            tag=tag,
            index=index,
            offset=offset,
            word_sel=word_sel,
            block_addr=block_addr,
            hit=is_hit,
            miss=is_miss,
            miss_type=miss_type,
            refill=refill,
            evicted_tag=evicted_tag,
            returned_data=returned_data
        )
        self.history.append(record)
        return record

    def run_trace(self, addresses: List[int]) -> Dict[str, Any]:
        """Execute a full sequence of memory accesses."""
        for addr in addresses:
            self.access(addr)
        return self.get_summary()

    def get_summary(self) -> Dict[str, Any]:
        """Return quantitative cache performance statistics."""
        hit_ratio = (self.hits / self.total_accesses) if self.total_accesses > 0 else 0.0
        miss_ratio = (self.misses / self.total_accesses) if self.total_accesses > 0 else 0.0

        return {
            "total_accesses": self.total_accesses,
            "hits": self.hits,
            "misses": self.misses,
            "hit_ratio": hit_ratio,
            "miss_ratio": miss_ratio,
            "compulsory_misses": self.compulsory_misses,
            "conflict_misses": self.conflict_misses,
            "capacity_misses": self.capacity_misses,
            "refills": self.refills,
            "sum_check": (hit_ratio + miss_ratio)
        }


if __name__ == "__main__":
    # Self-test on conflict access pattern
    sim = DirectMappedCacheSimulator()
    test_addrs = [0x00000000, 0x00000400, 0x00000800, 0x00000C00,
                  0x00000000, 0x00000400, 0x00000800, 0x00000C00]
    res = sim.run_trace(test_addrs)
    print("Conflict Test Summary:", res)
    for h in sim.history:
        print(f"Addr=0x{h.address:08X} Tag=0x{h.tag:02X} Idx={h.index:02d} Hit={h.hit} Miss={h.miss} Type={h.miss_type} Data=0x{h.returned_data:08X}")
