#!/usr/bin/env python3
"""
Average Memory Access Time (AMAT) Calculator for Direct-Mapped Cache Controller
Author: Ronit (Senior Computer Architecture Performance Analyst)
Project: Design and Analysis of a Direct-Mapped Cache Controller

Evaluates AMAT across memory access workloads:
  AMAT = Hit Time + (Miss Rate * Miss Penalty)

Conventions & Distinction:
  1. Baseline Academic / Architectural Model:
     - Hit Time (T_hit) = 1.0 cycle (tag comparison & SRAM lookup)
     - Raw Memory Latency = 10.0 cycles
     - Miss Penalty (P_miss) = Raw Memory Latency = 10.0 cycles
     - AMAT_baseline = 1.0 + (Miss_Rate * 10.0)

  2. Cycle-Accurate RTL Hardware Controller Model:
     - Hit Latency (T_hit_hw) = 2.0 cycles (IDLE -> LOOKUP -> RESPOND)
     - Miss Latency (T_miss_hw) = 14.0 cycles:
         IDLE (1) -> LOOKUP (1) -> MEM_REQUEST (1) -> MEM_WAIT (10) -> REFILL (1) -> RESPOND (1)
     - Hardware Miss Penalty = T_miss_hw - T_hit_hw = 12.0 cycles
       (or 14.0 cycles if considering total un-overlapped stall)
     - AMAT_hw = 2.0 + (Miss_Rate * 12.0)
"""

import os
import json
import csv
import argparse
from typing import Dict, Any, List

from statistics import run_all_workloads


class AMATCalculator:
    def __init__(self, hit_time: float = 1.0, mem_latency: float = 10.0, controller_overhead: float = 0.0):
        self.hit_time = hit_time
        self.mem_latency = mem_latency
        self.controller_overhead = controller_overhead
        self.miss_penalty = mem_latency + controller_overhead

    def compute(self, miss_rate: float) -> float:
        """Compute AMAT = Hit Time + (Miss Rate * Miss Penalty)."""
        return self.hit_time + (miss_rate * self.miss_penalty)

    def evaluate_workload(self, stats: Dict[str, Any]) -> Dict[str, Any]:
        """Attach AMAT metrics to workload performance dictionary."""
        miss_rate = stats["miss_ratio"]
        amat_val = self.compute(miss_rate)
        record = dict(stats)
        record["hit_time_cycles"] = self.hit_time
        record["mem_latency_cycles"] = self.mem_latency
        record["miss_penalty_cycles"] = self.miss_penalty
        record["amat_cycles"] = round(amat_val, 4)
        return record


def compute_all_amat(stats_list: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Compute AMAT under both baseline and cycle-accurate hardware conventions."""
    baseline_calc = AMATCalculator(hit_time=1.0, mem_latency=10.0, controller_overhead=0.0)
    hw_calc = AMATCalculator(hit_time=2.0, mem_latency=10.0, controller_overhead=2.0)  # Total penalty = 12 cyc

    enriched = []
    for s in stats_list:
        rec = dict(s)
        miss_rate = s["miss_ratio"]

        # Baseline: T_hit=1, P_miss=10
        rec["amat_baseline"] = round(baseline_calc.compute(miss_rate), 4)

        # Hardware Cycle-Accurate: T_hit=2, P_miss=12 (T_miss=14)
        rec["amat_hardware"] = round(hw_calc.compute(miss_rate), 4)

        enriched.append(rec)
    return enriched


def print_amat_table(results: List[Dict[str, Any]]):
    """Print comparative AMAT analysis table."""
    print("\n" + "=" * 115)
    print("AVERAGE MEMORY ACCESS TIME (AMAT) PERFORMANCE EVALUATION")
    print("  Baseline Model: Hit Time = 1 cyc, Miss Penalty = 10 cyc")
    print("  Hardware Model: Hit Time = 2 cyc, Miss Penalty = 12 cyc (Total Miss Latency = 14 cyc)")
    print("=" * 115)
    header = "{:<18} | {:>10} | {:>10} | {:>14} | {:>16} | {:>14} | {:>15}"
    print(header.format("Workload", "Hits", "Misses", "Hit Ratio (%)", "Miss Ratio (%)", "AMAT Baseline", "AMAT Hardware"))
    print("-" * 115)
    for r in results:
        print(header.format(
            r["workload"],
            r["hits"],
            r["misses"],
            f"{r['hit_ratio'] * 100:.2f}%",
            f"{r['miss_ratio'] * 100:.2f}%",
            f"{r['amat_baseline']:.4f} cyc",
            f"{r['amat_hardware']:.4f} cyc"
        ))
    print("=" * 115 + "\n")


def save_amat_reports(results: List[Dict[str, Any]], out_dir: str = "analysis"):
    """Save enriched AMAT results to JSON and CSV."""
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, "amat_summary.json")
    csv_path = os.path.join(out_dir, "amat_summary.csv")

    with open(json_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"[AMATCalculator] Saved JSON AMAT report to {json_path}")

    fieldnames = [
        "workload", "total_accesses", "hits", "misses", "hit_ratio", "miss_ratio",
        "amat_baseline", "amat_hardware", "compulsory_misses", "conflict_misses", "capacity_misses", "refills"
    ]
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for r in results:
            writer.writerow(r)
    print(f"[AMATCalculator] Saved CSV AMAT report to {csv_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AMAT Calculator for Direct-Mapped Cache")
    parser.add_argument("--stats_json", type=str, default="analysis/statistics_summary.json", help="Input statistics JSON")
    parser.add_argument("--trace_dir", type=str, default="traces", help="Directory containing trace files if JSON missing")
    parser.add_argument("--out_dir", type=str, default="analysis", help="Output directory")
    args = parser.parse_args()

    if os.path.exists(args.stats_json):
        with open(args.stats_json, "r") as f:
            stats = json.load(f)
    else:
        stats = run_all_workloads(args.trace_dir)

    amat_results = compute_all_amat(stats)
    print_amat_table(amat_results)
    save_amat_reports(amat_results, args.out_dir)
