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
    parser.add_argument("--pattern", choices=["sequential"], default="sequential", help="Access pattern")
    parser.add_argument("--start", type=lambda x: int(x, 0), default=0x00003000, help="Start address (hex or dec)")
    parser.add_argument("--count", type=int, default=128, help="Number of accesses")
    parser.add_argument("--stride", type=int, default=4, help="Byte stride between accesses")
    parser.add_argument("--out_txt", type=str, default="traces/sequential_trace.txt", help="Output text file")
    parser.add_argument("--out_csv", type=str, default="traces/sequential_trace.csv", help="Output CSV file")
    args = parser.parse_args()

    seq_trace = generate_sequential_trace(args.start, args.count, args.stride)
    save_trace_txt(seq_trace, args.out_txt)
    save_trace_csv(seq_trace, args.out_csv)
