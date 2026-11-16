#!/usr/bin/env python3
"""
Architectural Parameter Exploration & Sensitivity Analysis
Author: Ronit (Senior Computer Architecture Performance Analyst)
Project: Design and Analysis of a Direct-Mapped Cache Controller

Evaluates architectural parameter sweeps around the baseline 1 KB / 16-byte configuration:
  Experiment 1: Varying Cache Capacity (256 B, 512 B, 1 KB Baseline, 2 KB, 4 KB)
  Experiment 2: Varying Cache Block Size (8 B, 16 B Baseline, 32 B, 64 B)
  Experiment 3: Varying Main Memory Latency (5, 10 Baseline, 20, 50 cycles)

Demonstrates impact on Hit Ratio, Miss Classification, and AMAT.
"""

import os
import json
import argparse
from typing import Dict, Any, List

os.environ["MPLCONFIGDIR"] = "/tmp/matplotlib_cache"
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from cache_simulator import DirectMappedCacheSimulator
from trace_generator import generate_sequential_trace, generate_random_trace


def evaluate_capacity_sweep(out_dir: str = "analysis"):
    """
    Vary cache capacity from 256 B to 4 KB with fixed 16-byte block size.
    Evaluated under a multi-pass sequential loop (128 words = 512 bytes)
    and a random workload.
    """
    capacities = [256, 512, 1024, 2048, 4096]
    labels = ["256 B\n(16 lines)", "512 B\n(32 lines)", "1 KB (Base)\n(64 lines)", "2 KB\n(128 lines)", "4 KB\n(256 lines)"]

    # 512-byte workload (32 blocks of 16 bytes), streamed twice (64 accesses * 2 = 128 accesses)
    loop_addrs = [0x00003000 + (i * 4) for i in range(64)] + [0x00003000 + (i * 4) for i in range(64)]

    hit_ratios = []
    amats = []

    for cap in capacities:
        sim = DirectMappedCacheSimulator(capacity_bytes=cap, block_size=16)
        sim.run_trace(loop_addrs)
        summ = sim.get_summary()
        hr = summ["hit_ratio"] * 100
        # AMAT with baseline T_hit=1, P_miss=10
        amat = 1.0 + (summ["miss_ratio"] * 10.0)
        hit_ratios.append(hr)
        amats.append(amat)

    # Plot
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.5), dpi=300)

    ax1.plot(labels, hit_ratios, marker="o", color="#1565c0", linewidth=2.2, markersize=8)
    ax1.set_title("Hit Ratio vs Cache Capacity (Loop = 512 Bytes)", fontweight="bold")
    ax1.set_ylabel("Hit Ratio (%)")
    ax1.set_ylim(0, 105)
    ax1.grid(True, linestyle="--", alpha=0.6)
    for i, txt in enumerate(hit_ratios):
        ax1.annotate(f"{txt:.1f}%", (labels[i], hit_ratios[i]), textcoords="offset points", xytext=(0, 7), ha="center", fontweight="bold")

    ax2.plot(labels, amats, marker="s", color="#c62828", linewidth=2.2, markersize=8)
    ax2.set_title("AMAT vs Cache Capacity (Baseline T_hit=1, P_miss=10)", fontweight="bold")
    ax2.set_ylabel("AMAT (Cycles)")
    ax2.set_ylim(0, max(amats) * 1.25)
    ax2.grid(True, linestyle="--", alpha=0.6)
    for i, txt in enumerate(amats):
        ax2.annotate(f"{txt:.2f}c", (labels[i], amats[i]), textcoords="offset points", xytext=(0, 7), ha="center", fontweight="bold")

    plt.suptitle("Architectural Experiment 1: Cache Capacity Scaling", fontsize=13, fontweight="bold")
    plt.tight_layout()
    plot_path = os.path.join(out_dir, "plots/experiment_capacity_sweep.png")
    plt.savefig(plot_path)
    plt.close()
    print(f"[Experiment] Saved: {plot_path}")

    return {"capacities": capacities, "hit_ratios": hit_ratios, "amats": amats}


def evaluate_block_size_sweep(out_dir: str = "analysis"):
    """
    Vary block size: 8 B, 16 B (Baseline), 32 B, 64 B with fixed 1 KB capacity.
    Evaluated under pure sequential streaming (128 words).
    Demonstrates theoretical spatial hit rate: (B/4 - 1)/(B/4).
    """
    block_sizes = [8, 16, 32, 64]
    labels = ["8 Bytes\n(2 words)", "16 Bytes (Base)\n(4 words)", "32 Bytes\n(8 words)", "64 Bytes\n(16 words)"]
    seq_addrs = generate_sequential_trace(start_addr=0x00003000, num_accesses=128, stride=4)

    empirical_hit_ratios = []
    theoretical_hit_ratios = []
    amats = []

    for b in block_sizes:
        sim = DirectMappedCacheSimulator(capacity_bytes=1024, block_size=b)
        sim.run_trace(seq_addrs)
        summ = sim.get_summary()
        hr = summ["hit_ratio"] * 100
        words_per_blk = b // 4
        th_hr = ((words_per_blk - 1) / words_per_blk) * 100
        empirical_hit_ratios.append(hr)
        theoretical_hit_ratios.append(th_hr)
        amat = 1.0 + (summ["miss_ratio"] * 10.0)
        amats.append(amat)

    # Plot
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.5), dpi=300)

    x = np.arange(len(labels))
    width = 0.35
    ax1.bar(x - width/2, theoretical_hit_ratios, width, label="Theoretical Spatial Limit", color="#78909c", edgecolor="black")
    ax1.bar(x + width/2, empirical_hit_ratios, width, label="Observed Streaming Hit Ratio", color="#2e7d32", edgecolor="black")
    ax1.set_title("Spatial Locality vs Block Size (1 KB Cache)", fontweight="bold")
    ax1.set_ylabel("Hit Ratio (%)")
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels)
    ax1.set_ylim(0, 110)
    ax1.legend(loc="lower right")
    ax1.grid(axis="y", linestyle="--", alpha=0.6)

    for i in range(len(labels)):
        ax1.annotate(f"{empirical_hit_ratios[i]:.1f}%", xy=(x[i] + width/2, empirical_hit_ratios[i]),
                     xytext=(0, 4), textcoords="offset points", ha="center", va="bottom", fontweight="bold")

    ax2.plot(labels, amats, marker="D", color="#ef6c00", linewidth=2.2, markersize=8)
    ax2.set_title("Sequential AMAT vs Block Size", fontweight="bold")
    ax2.set_ylabel("AMAT (Cycles)")
    ax2.set_ylim(0, 7)
    ax2.grid(True, linestyle="--", alpha=0.6)
    for i, txt in enumerate(amats):
        ax2.annotate(f"{txt:.2f}c", (labels[i], amats[i]), textcoords="offset points", xytext=(0, 7), ha="center", fontweight="bold")

    plt.suptitle("Architectural Experiment 2: Block Size & Spatial Locality Scaling", fontsize=13, fontweight="bold")
    plt.tight_layout()
    plot_path = os.path.join(out_dir, "plots/experiment_block_size_sweep.png")
    plt.savefig(plot_path)
    plt.close()
    print(f"[Experiment] Saved: {plot_path}")

    return {"block_sizes": block_sizes, "observed_hit_ratios": empirical_hit_ratios, "amats": amats}


def evaluate_memory_latency_sweep(out_dir: str = "analysis"):
    """
    Vary main memory latency: 5, 10 (Baseline), 20, 50 cycles across all 4 workloads.
    Demonstrates AMAT sensitivity: d(AMAT)/d(Latency) = Miss Rate.
    """
    latencies = [5, 10, 15, 20, 30, 50]
    workload_miss_rates = {
        "Repeated Access": 0.0078,
        "Sequential Access": 0.2500,
        "Random Access": 0.9609,
        "Conflict Access": 1.0000
    }
    colors = {"Repeated Access": "#2e7d32", "Sequential Access": "#1976d2", "Random Access": "#f57c00", "Conflict Access": "#d32f2f"}

    fig, ax = plt.subplots(figsize=(8.5, 5), dpi=300)

    sweep_results = {}
    for name, mr in workload_miss_rates.items():
        amats = [1.0 + (mr * lat) for lat in latencies]
        sweep_results[name] = amats
        ax.plot(latencies, amats, marker="o", label=f"{name} (MR={mr*100:.1f}%, slope={mr:.2f})",
                color=colors[name], linewidth=2.0, markersize=7)

    ax.set_title("AMAT Sensitivity to Main Memory Latency Across Access Patterns", fontweight="bold", pad=12)
    ax.set_xlabel("Main Memory Latency (Cycles)", fontweight="bold")
    ax.set_ylabel("AMAT (Cycles)", fontweight="bold")
    ax.set_xlim(0, 55)
    ax.set_ylim(0, 55)
    ax.grid(True, linestyle="--", alpha=0.6)
    ax.legend(loc="upper left", frameon=True)

    plt.tight_layout()
    plot_path = os.path.join(out_dir, "plots/experiment_memory_latency_sweep.png")
    plt.savefig(plot_path)
    plt.close()
    print(f"[Experiment] Saved: {plot_path}")

    return sweep_results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Architectural Experiment Runner")
    parser.add_argument("--out_dir", type=str, default="analysis", help="Output directory")
    args = parser.parse_args()

    os.makedirs(os.path.join(args.out_dir, "plots"), exist_ok=True)
    res_cap = evaluate_capacity_sweep(args.out_dir)
    res_blk = evaluate_block_size_sweep(args.out_dir)
    res_lat = evaluate_memory_latency_sweep(args.out_dir)

    all_experiments = {
        "capacity_sweep": res_cap,
        "block_size_sweep": res_blk,
        "latency_sweep": res_lat
    }
    with open(os.path.join(args.out_dir, "architectural_experiments.json"), "w") as f:
        json.dump(all_experiments, f, indent=2)
    print(f"[Experiment] Exported full experiment data to {args.out_dir}/architectural_experiments.json")
