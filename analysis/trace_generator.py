#!/usr/bin/env python3
"""
Trace Generator Module for Direct-Mapped Cache Controller
Author: Ronit (Senior Computer Architecture Performance Analyst)
Project: Design and Analysis of a Direct-Mapped Cache Controller

Generates memory access traces to evaluate spatial and temporal locality,
conflict thrashing, and random access patterns for a 1 KB direct-mapped cache.

Cache Geometry:
  - Capacity: 1024 Bytes (1 KB)
  - Block size: 16 Bytes (128 bits)
  - Number of lines: 64
  - Tag: address[31:10] (22 bits)
  - Index: address[9:4] (6 bits)
  - Offset: address[3:0] (4 bits)
  - Word Select: address[3:2] (2 bits)
"""

import os
import csv
import random
import argparse

TAG_WIDTH = 22
INDEX_WIDTH = 6
OFFSET_WIDTH = 4
BLOCK_SIZE = 16
NUM_LINES = 64


def decode_address(addr: int):
    """Decompose 32-bit address into architectural cache fields."""
    addr = addr & 0xFFFFFFFF
    tag = (addr >> 10) & 0x3FFFFF
    index = (addr >> 4) & 0x3F
    offset = addr & 0xF
    word_sel = (addr >> 2) & 0x3
    byte_offset = addr & 0x3
    block_addr = addr & ~0xF
    return {
        "address": addr,
        "tag": tag,
        "index": index,
        "offset": offset,
        "word_sel": word_sel,
        "byte_offset": byte_offset,
        "block_addr": block_addr
    }


def generate_sequential_trace(start_addr: int = 0x00003000, num_accesses: int = 128, stride: int = 4):
    """
    Generate sequential word accesses to evaluate spatial locality.
    With stride=4 (word access), every 4 consecutive accesses map to the same
    16-byte block, demonstrating 75% theoretical spatial hit rate after cold miss.
    """
    addresses = []
    for i in range(num_accesses):
        addr = (start_addr + (i * stride)) & 0xFFFFFFFF
        addresses.append(addr)
    return addresses


def generate_repeated_trace(base_addr: int = 0x00002004, num_accesses: int = 128, loop_size: int = 1):
    """
    Generate repeated accesses to the same address or small set of addresses
    to evaluate temporal locality.
    If loop_size=1, accesses the exact same address repeatedly (1 cold miss + (N-1) hits).
    If loop_size>1, cycles through a small loop of addresses fitting within cache.
    """
    addresses = []
    loop_addrs = [(base_addr + (i * 4)) & 0xFFFFFFFF for i in range(loop_size)]
    for i in range(num_accesses):
        addresses.append(loop_addrs[i % loop_size])
    return addresses


def generate_random_trace(num_accesses: int = 128, seed: int = 0x5EEDC0DE, tag_pool_size: int = 16):
    """
    Generate reproducible pseudo-random word-aligned addresses using a configurable seed.
    Uses constrained index and tag distributions to evaluate cache behavior under
    irregular, less predictable memory access patterns.
    """
    rng = random.Random(seed)
    addresses = []
    for _ in range(num_accesses):
        rnd_tag = rng.randint(0, tag_pool_size - 1)
        rnd_idx = rng.randint(0, NUM_LINES - 1)
        rnd_word = rng.randint(0, 3)
        addr = ((rnd_tag << 10) | (rnd_idx << 4) | (rnd_word << 2)) & 0xFFFFFFFF
        addresses.append(addr)
    return addresses


def generate_conflict_trace(num_accesses: int = 128, target_index: int = 0, num_conflicting_tags: int = 4, word_offset: int = 0):
    """
    Generate memory accesses that map to the exact same cache index but possess distinct tags.
    In our 1 KB cache (64 lines * 16 bytes = 1024 = 0x400 bytes), stride of 0x400 preserves
    the exact same index bits [9:4] and offset bits [3:0] while incrementing the tag [31:10].
    
    Example for target_index=0:
      0x00000000 (Tag 0, Index 0)
      0x00000400 (Tag 1, Index 0)
      0x00000800 (Tag 2, Index 0)
      0x00000C00 (Tag 3, Index 0)
      
    Alternating across these addresses forces continuous ping-pong eviction (thrashing),
    demonstrating direct-mapped conflict misses.
    """
    conflicting_addrs = []
    for tag_val in range(num_conflicting_tags):
        addr = ((tag_val << 10) | (target_index << 4) | (word_offset << 2)) & 0xFFFFFFFF
        conflicting_addrs.append(addr)
    
    addresses = []
    for i in range(num_accesses):
        addresses.append(conflicting_addrs[i % num_conflicting_tags])
    return addresses


def save_trace_txt(addresses, filepath: str):
    """Save addresses to plain text file (one hex address per line)."""
    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    with open(filepath, "w") as f:
        for addr in addresses:
            f.write(f"0x{addr:08X}\n")
    print(f"[TraceGenerator] Saved {len(addresses)} accesses to {filepath}")


def save_trace_csv(addresses, filepath: str):
    """Save addresses with decoded cache fields to CSV file."""
    os.makedirs(os.path.dirname(os.path.abspath(filepath)), exist_ok=True)
    with open(filepath, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Access_ID", "Address_Hex", "Address_Dec", "Tag_Hex", "Tag_Dec", "Index_Dec", "Offset_Dec", "Word_Sel"])
        for idx, addr in enumerate(addresses):
            fields = decode_address(addr)
            writer.writerow([
                idx,
                f"0x{fields['address']:08X}",
                fields['address'],
                f"0x{fields['tag']:06X}",
                fields['tag'],
                fields['index'],
                fields['offset'],
                fields['word_sel']
            ])
    print(f"[TraceGenerator] Saved {len(addresses)} decoded records to {filepath}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Trace Generator for Direct-Mapped Cache Controller")
    parser.add_argument("--pattern", choices=["sequential", "repeated", "random", "conflict", "all"], default="all", help="Access pattern")
    parser.add_argument("--start", type=lambda x: int(x, 0), default=0x00003000, help="Start address (hex or dec)")
    parser.add_argument("--count", type=int, default=128, help="Number of accesses")
    parser.add_argument("--stride", type=int, default=4, help="Byte stride between accesses")
    parser.add_argument("--seed", type=lambda x: int(x, 0), default=0x5EEDC0DE, help="Random seed")
    parser.add_argument("--loop_size", type=int, default=1, help="Loop size for repeated pattern")
    parser.add_argument("--target_index", type=int, default=0, help="Cache index for conflict pattern (0-63)")
    parser.add_argument("--conflict_tags", type=int, default=4, help="Number of conflicting tags")
    parser.add_argument("--output_dir", type=str, default="traces", help="Output directory")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    if args.pattern in ["sequential", "all"]:
        seq_trace = generate_sequential_trace(args.start, args.count, args.stride)
        save_trace_txt(seq_trace, os.path.join(args.output_dir, "sequential_trace.txt"))
        save_trace_csv(seq_trace, os.path.join(args.output_dir, "sequential_trace.csv"))

    if args.pattern in ["repeated", "all"]:
        rep_trace = generate_repeated_trace(0x00002004, args.count, args.loop_size)
        save_trace_txt(rep_trace, os.path.join(args.output_dir, "repeated_trace.txt"))
        save_trace_csv(rep_trace, os.path.join(args.output_dir, "repeated_trace.csv"))

    if args.pattern in ["random", "all"]:
        rand_trace = generate_random_trace(args.count, args.seed)
        save_trace_txt(rand_trace, os.path.join(args.output_dir, "random_trace.txt"))
        save_trace_csv(rand_trace, os.path.join(args.output_dir, "random_trace.csv"))

    if args.pattern in ["conflict", "all"]:
        conf_trace = generate_conflict_trace(args.count, args.target_index, args.conflict_tags)
        save_trace_txt(conf_trace, os.path.join(args.output_dir, "conflict_trace.txt"))
        save_trace_csv(conf_trace, os.path.join(args.output_dir, "conflict_trace.csv"))
