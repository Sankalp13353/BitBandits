#!/usr/bin/env python3
"""
Performance Statistics Analyzer for Direct-Mapped Cache Controller
Author: Ronit (Senior Computer Architecture Performance Analyst)
Project: Design and Analysis of a Direct-Mapped Cache Controller

Reads memory access traces, executes cache simulation with 3C miss classification,
and computes quantitative architectural performance metrics:
  - Total Accesses
  - Hits & Misses
  - Hit Ratio & Miss Ratio
  - Compulsory, Conflict, and Capacity Miss breakdown
  - Memory Block Refill Count
  - Mathematical integrity verification: Hit Ratio + Miss Ratio == 1.0
"""

import os
import csv
import json
import argparse
from typing import List, Dict, Any

from cache_simulator import DirectMappedCacheSimulator


def load_trace_txt(filepath: str) -> List[int]:
    """Load addresses from plain hex text file."""
    addresses = []
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            addr = int(line, 16)
            addresses.append(addr)
    return addresses


def load_trace_csv(filepath: str) -> List[int]:
    """Load addresses from CSV file."""
    addresses = []
    with open(filepath, "r", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if "Address_Hex" in row:
                addr = int(row["Address_Hex"], 16)
            elif "Address_Dec" in row:
                addr = int(row["Address_Dec"])
            elif "address" in row:
                addr = int(row["address"], 0)
            else:
                raise ValueError(f"Unrecognized CSV format in {filepath}")
            addresses.append(addr)
    return addresses


def load_trace(filepath: str) -> List[int]:
    """Load trace from text or CSV file based on extension."""
    if filepath.endswith(".csv"):
        return load_trace_csv(filepath)
    return load_trace_txt(filepath)


def analyze_workload(name: str, addresses: List[int]) -> Dict[str, Any]:
    """Simulate workload trace and return comprehensive statistical metrics."""
    sim = DirectMappedCacheSimulator()
    sim.run_trace(addresses)
    summary = sim.get_summary()

    # Integrity verification
    hit_ratio = summary["hit_ratio"]
    miss_ratio = summary["miss_ratio"]
    assert abs((hit_ratio + miss_ratio) - 1.0) < 1e-9, f"Hit/Miss Ratio sum error: {hit_ratio + miss_ratio}"
    assert summary["hits"] + summary["misses"] == summary["total_accesses"], "Hit + Miss != Total"
    assert summary["compulsory_misses"] + summary["conflict_misses"] + summary["capacity_misses"] == summary["misses"], "3C sum != Misses"

    summary["workload"] = name
    summary["access_count"] = summary["total_accesses"]
    return summary


def run_all_workloads(trace_dir: str = "traces") -> List[Dict[str, Any]]:
    """Analyze all standard workloads in the traces directory."""
    workload_files = [
        ("Sequential Access", os.path.join(trace_dir, "sequential_trace.txt")),
        ("Repeated Access", os.path.join(trace_dir, "repeated_trace.txt")),
        ("Random Access", os.path.join(trace_dir, "random_trace.txt")),
        ("Conflict Access", os.path.join(trace_dir, "conflict_trace.txt")),
    ]

    results = []
    for name, path in workload_files:
        if not os.path.exists(path):
            raise FileNotFoundError(f"Trace file not found: {path}. Run trace_generator.py first.")
        addrs = load_trace(path)
        stats = analyze_workload(name, addrs)
        results.append(stats)
    return results


def print_comparison_table(results: List[Dict[str, Any]]):
    """Print markdown-formatted comparison table."""
    headers = [
        "Workload", "Accesses", "Hits", "Misses", "Hit Ratio (%)", "Miss Ratio (%)",
        "Cold Misses", "Conflict Misses", "Capacity Misses", "Refills"
    ]
    print("\n" + "=" * 120)
    print("DIRECT-MAPPED CACHE PERFORMANCE & MISS CLASSIFICATION SUMMARY")
    print("=" * 120)
    row_fmt = "{:<18} | {:>8} | {:>6} | {:>6} | {:>13} | {:>14} | {:>11} | {:>15} | {:>15} | {:>7}"
    print(row_fmt.format(*headers))
    print("-" * 120)
    for r in results:
        print(row_fmt.format(
            r["workload"],
            r["total_accesses"],
            r["hits"],
            r["misses"],
            f"{r['hit_ratio'] * 100:.2f}%",
            f"{r['miss_ratio'] * 100:.2f}%",
            r["compulsory_misses"],
            r["conflict_misses"],
            r["capacity_misses"],
            r["refills"]
        ))
    print("=" * 120 + "\n")


def save_summary_files(results: List[Dict[str, Any]], out_dir: str = "analysis"):
    """Export summary metrics to JSON and CSV formats."""
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, "statistics_summary.json")
    csv_path = os.path.join(out_dir, "statistics_summary.csv")

    with open(json_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"[Statistics] Saved JSON summary to {json_path}")

    fieldnames = [
        "workload", "total_accesses", "hits", "misses", "hit_ratio", "miss_ratio",
        "compulsory_misses", "conflict_misses", "capacity_misses", "refills"
    ]
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for r in results:
            writer.writerow(r)
    print(f"[Statistics] Saved CSV summary to {csv_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Performance Statistics Analyzer for Cache Controller")
    parser.add_argument("--trace_dir", type=str, default="traces", help="Directory containing trace files")
    parser.add_argument("--trace_file", type=str, default=None, help="Specific trace file to analyze")
    parser.add_argument("--out_dir", type=str, default="analysis", help="Output directory for reports")
    args = parser.parse_args()

    if args.trace_file:
        name = os.path.splitext(os.path.basename(args.trace_file))[0]
        addrs = load_trace(args.trace_file)
        stats = analyze_workload(name, addrs)
        print_comparison_table([stats])
    else:
        results = run_all_workloads(args.trace_dir)
        print_comparison_table(results)
        save_summary_files(results, args.out_dir)
