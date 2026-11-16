#!/usr/bin/env python3
"""
Performance Visualization Script for Direct-Mapped Cache Controller
Author: Ronit (Senior Computer Architecture Performance Analyst)
Project: Design and Analysis of a Direct-Mapped Cache Controller

Generates high-resolution publication-quality graphs using matplotlib:
  1. Hit Ratio Comparison (analysis/plots/hit_ratio_comparison.png)
  2. Miss Ratio Comparison (analysis/plots/miss_ratio_comparison.png)
  3. AMAT Comparison (analysis/plots/amat_comparison.png)
  4. Hits versus Misses (analysis/plots/hits_vs_misses.png)
  5. Miss Classification Breakdown (analysis/plots/miss_classification_breakdown.png)
  6. Comprehensive 2x2 Performance Dashboard (analysis/plots/comprehensive_dashboard.png)
"""

import os
import json
import argparse

# Set environment for headless rendering
os.environ["MPLCONFIGDIR"] = "/tmp/matplotlib_cache"
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def load_data(json_path: str):
    """Load AMAT summary data."""
    with open(json_path, "r") as f:
        return json.load(f)


def set_plot_style():
    """Configure clean, professional IEEE publication aesthetics."""
    plt.style.use("seaborn-v0_8-whitegrid" if "seaborn-v0_8-whitegrid" in plt.style.available else "default")
    plt.rcParams["font.family"] = "sans-serif"
    plt.rcParams["font.size"] = 11
    plt.rcParams["axes.labelsize"] = 12
    plt.rcParams["axes.titlesize"] = 13
    plt.rcParams["xtick.labelsize"] = 11
    plt.rcParams["ytick.labelsize"] = 11
    plt.rcParams["legend.fontsize"] = 11
    plt.rcParams["figure.titlesize"] = 15


def plot_hit_ratio(data, out_dir: str):
    """1. Hit ratio comparison bar chart."""
    workloads = [d["workload"] for d in data]
    hit_ratios = [d["hit_ratio"] * 100 for d in data]
    colors = ["#2b5c8f", "#2e7d32", "#d84315", "#c62828"]

    fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
    bars = ax.bar(workloads, hit_ratios, color=colors, width=0.55, edgecolor="black", linewidth=1.2)

    ax.set_ylabel("Hit Ratio (%)", fontweight="bold")
    ax.set_title("Cache Hit Ratio Comparison Across Workloads (1 KB Direct-Mapped)", fontweight="bold", pad=12)
    ax.set_ylim(0, 115)
    ax.grid(axis="y", linestyle="--", alpha=0.7)

    # Data labels on bars
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f"{height:.1f}%",
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 5),
                    textcoords="offset points",
                    ha="center", va="bottom", fontweight="bold", fontsize=11)

    plt.tight_layout()
    out_path = os.path.join(out_dir, "hit_ratio_comparison.png")
    plt.savefig(out_path)
    plt.close()
    print(f"[Plot] Saved: {out_path}")


def plot_miss_ratio(data, out_dir: str):
    """2. Miss ratio comparison bar chart."""
    workloads = [d["workload"] for d in data]
    miss_ratios = [d["miss_ratio"] * 100 for d in data]
    colors = ["#455a64", "#00897b", "#f57c00", "#b71c1c"]

    fig, ax = plt.subplots(figsize=(8, 5), dpi=300)
    bars = ax.bar(workloads, miss_ratios, color=colors, width=0.55, edgecolor="black", linewidth=1.2)

    ax.set_ylabel("Miss Ratio (%)", fontweight="bold")
    ax.set_title("Cache Miss Ratio Comparison Across Workloads (1 KB Direct-Mapped)", fontweight="bold", pad=12)
    ax.set_ylim(0, 115)
    ax.grid(axis="y", linestyle="--", alpha=0.7)

    for bar in bars:
        height = bar.get_height()
        ax.annotate(f"{height:.1f}%",
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 5),
                    textcoords="offset points",
                    ha="center", va="bottom", fontweight="bold", fontsize=11)

    plt.tight_layout()
    out_path = os.path.join(out_dir, "miss_ratio_comparison.png")
    plt.savefig(out_path)
    plt.close()
    print(f"[Plot] Saved: {out_path}")


def plot_amat_comparison(data, out_dir: str):
    """3. AMAT comparison grouped bar chart."""
    workloads = [d["workload"] for d in data]
    amat_baseline = [d["amat_baseline"] for d in data]
    amat_hw = [d["amat_hardware"] for d in data]

    x = np.arange(len(workloads))
    width = 0.35

    fig, ax = plt.subplots(figsize=(9, 5.5), dpi=300)
    bars1 = ax.bar(x - width/2, amat_baseline, width, label="Baseline Model (T_hit=1, P_miss=10)",
                   color="#1976d2", edgecolor="black", linewidth=1.0)
    bars2 = ax.bar(x + width/2, amat_hw, width, label="Hardware Controller (T_hit=2, P_miss=12)",
                   color="#d32f2f", edgecolor="black", linewidth=1.0)

    ax.set_ylabel("Average Memory Access Time (Cycles)", fontweight="bold")
    ax.set_title("AMAT Comparison: Baseline Theory vs RTL Hardware Model", fontweight="bold", pad=12)
    ax.set_xticks(x)
    ax.set_xticklabels(workloads)
    ax.set_ylim(0, max(amat_hw) * 1.25)
    ax.legend(loc="upper left", frameon=True)
    ax.grid(axis="y", linestyle="--", alpha=0.7)

    for bar in bars1:
        h = bar.get_height()
        ax.annotate(f"{h:.2f}c",
                    xy=(bar.get_x() + bar.get_width() / 2, h),
                    xytext=(0, 4), textcoords="offset points",
                    ha="center", va="bottom", fontsize=9.5, fontweight="bold")

    for bar in bars2:
        h = bar.get_height()
        ax.annotate(f"{h:.2f}c",
                    xy=(bar.get_x() + bar.get_width() / 2, h),
                    xytext=(0, 4), textcoords="offset points",
                    ha="center", va="bottom", fontsize=9.5, fontweight="bold")

    plt.tight_layout()
    out_path = os.path.join(out_dir, "amat_comparison.png")
    plt.savefig(out_path)
    plt.close()
    print(f"[Plot] Saved: {out_path}")


def plot_hits_vs_misses(data, out_dir: str):
    """4. Stacked bar chart of hits vs misses."""
    workloads = [d["workload"] for d in data]
    hits = [d["hits"] for d in data]
    misses = [d["misses"] for d in data]

    fig, ax = plt.subplots(figsize=(8.5, 5), dpi=300)
    p1 = ax.bar(workloads, hits, width=0.55, label="Hits", color="#388e3c", edgecolor="black", linewidth=1.0)
    p2 = ax.bar(workloads, misses, width=0.55, bottom=hits, label="Misses", color="#e53935", edgecolor="black", linewidth=1.0)

    ax.set_ylabel("Access Count", fontweight="bold")
    ax.set_title("Absolute Hits vs Misses Distribution (N=128 Accesses)", fontweight="bold", pad=12)
    ax.set_ylim(0, 150)
    ax.legend(loc="upper right", frameon=True)
    ax.grid(axis="y", linestyle="--", alpha=0.7)

    for i, (h, m) in enumerate(zip(hits, misses)):
        if h > 8:
            ax.text(i, h / 2, f"{h}\n({(h/128)*100:.1f}%)", ha="center", va="center", color="white", fontweight="bold", fontsize=10)
        elif h > 0:
            ax.text(i, h / 2, f"{h}", ha="center", va="center", color="white", fontweight="bold", fontsize=10)
        if m > 8:
            ax.text(i, h + m / 2, f"{m}\n({(m/128)*100:.1f}%)", ha="center", va="center", color="white", fontweight="bold", fontsize=10)
        elif m > 0:
            ax.text(i, h + m / 2, f"{m}", ha="center", va="center", color="white", fontweight="bold", fontsize=10)

    plt.tight_layout()
    out_path = os.path.join(out_dir, "hits_vs_misses.png")
    plt.savefig(out_path)
    plt.close()
    print(f"[Plot] Saved: {out_path}")


def plot_miss_breakdown(data, out_dir: str):
    """5. Detailed 3C Miss classification breakdown."""
    workloads = [d["workload"] for d in data]
    cold = [d["compulsory_misses"] for d in data]
    conf = [d["conflict_misses"] for d in data]
    cap = [d["capacity_misses"] for d in data]

    fig, ax = plt.subplots(figsize=(8.5, 5), dpi=300)
    p1 = ax.bar(workloads, cold, width=0.55, label="Compulsory (Cold) Misses", color="#0288d1", edgecolor="black", linewidth=1.0)
    p2 = ax.bar(workloads, conf, width=0.55, bottom=cold, label="Conflict Misses (Set Collision)", color="#f57c00", edgecolor="black", linewidth=1.0)
    bottom_cap = [c + f for c, f in zip(cold, conf)]
    p3 = ax.bar(workloads, cap, width=0.55, bottom=bottom_cap, label="Capacity Misses (Working Set > 1KB)", color="#7b1fa2", edgecolor="black", linewidth=1.0)

    ax.set_ylabel("Miss Count", fontweight="bold")
    ax.set_title("Hill & Smith 3C Miss Classification Across Workloads", fontweight="bold", pad=12)
    ax.set_ylim(0, 150)
    ax.legend(loc="upper left", frameon=True)
    ax.grid(axis="y", linestyle="--", alpha=0.7)

    for i in range(len(workloads)):
        tot = cold[i] + conf[i] + cap[i]
        if tot > 0:
            ax.annotate(f"Total: {tot}",
                        xy=(i, tot), xytext=(0, 5), textcoords="offset points",
                        ha="center", va="bottom", fontweight="bold")

    plt.tight_layout()
    out_path = os.path.join(out_dir, "miss_classification_breakdown.png")
    plt.savefig(out_path)
    plt.close()
    print(f"[Plot] Saved: {out_path}")


def plot_comprehensive_dashboard(data, out_dir: str):
    """6. Comprehensive 2x2 multi-panel figure for final paper/report."""
    workloads = [d["workload"] for d in data]
    hit_ratios = [d["hit_ratio"] * 100 for d in data]
    miss_ratios = [d["miss_ratio"] * 100 for d in data]
    amat_hw = [d["amat_hardware"] for d in data]
    hits = [d["hits"] for d in data]
    misses = [d["misses"] for d in data]

    fig, axs = plt.subplots(2, 2, figsize=(14, 10), dpi=300)

    # Subplot 1: Hit Ratio
    bars1 = axs[0, 0].bar(workloads, hit_ratios, color=["#1565c0", "#2e7d32", "#e65100", "#c62828"], edgecolor="black")
    axs[0, 0].set_title("(a) Cache Hit Ratio (%)", fontweight="bold")
    axs[0, 0].set_ylabel("Hit Ratio (%)")
    axs[0, 0].set_ylim(0, 120)
    for b in bars1:
        axs[0, 0].annotate(f"{b.get_height():.1f}%", xy=(b.get_x() + b.get_width() / 2, b.get_height()),
                           xytext=(0, 4), textcoords="offset points", ha="center", va="bottom", fontweight="bold")

    # Subplot 2: Miss Ratio
    bars2 = axs[0, 1].bar(workloads, miss_ratios, color=["#455a64", "#00897b", "#f57c00", "#b71c1c"], edgecolor="black")
    axs[0, 1].set_title("(b) Cache Miss Ratio (%)", fontweight="bold")
    axs[0, 1].set_ylabel("Miss Ratio (%)")
    axs[0, 1].set_ylim(0, 120)
    for b in bars2:
        axs[0, 1].annotate(f"{b.get_height():.1f}%", xy=(b.get_x() + b.get_width() / 2, b.get_height()),
                           xytext=(0, 4), textcoords="offset points", ha="center", va="bottom", fontweight="bold")

    # Subplot 3: AMAT Hardware
    bars3 = axs[1, 0].bar(workloads, amat_hw, color="#512da8", edgecolor="black")
    axs[1, 0].set_title("(c) Hardware AMAT (Cycles)", fontweight="bold")
    axs[1, 0].set_ylabel("Cycles")
    axs[1, 0].set_ylim(0, 16)
    for b in bars3:
        axs[1, 0].annotate(f"{b.get_height():.2f} cyc", xy=(b.get_x() + b.get_width() / 2, b.get_height()),
                           xytext=(0, 4), textcoords="offset points", ha="center", va="bottom", fontweight="bold")

    # Subplot 4: Hits vs Misses
    axs[1, 1].bar(workloads, hits, label="Hits", color="#388e3c", edgecolor="black")
    axs[1, 1].bar(workloads, misses, bottom=hits, label="Misses", color="#d32f2f", edgecolor="black")
    axs[1, 1].set_title("(d) Hits vs Misses (Total = 128)", fontweight="bold")
    axs[1, 1].set_ylabel("Access Count")
    axs[1, 1].set_ylim(0, 150)
    axs[1, 1].legend()

    for ax in axs.flat:
        ax.grid(axis="y", linestyle="--", alpha=0.6)
        ax.tick_params(axis="x", rotation=15)

    plt.suptitle("Direct-Mapped Cache Controller: Comprehensive Architectural Performance Suite",
                 fontsize=16, fontweight="bold", y=0.98)
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    out_path = os.path.join(out_dir, "comprehensive_dashboard.png")
    plt.savefig(out_path)
    plt.close()
    print(f"[Plot] Saved: {out_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Performance Plotter for Direct-Mapped Cache Controller")
    parser.add_argument("--json_file", type=str, default="analysis/amat_summary.json", help="Path to AMAT summary JSON")
    parser.add_argument("--out_dir", type=str, default="analysis/plots", help="Output directory for plots")
    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    set_plot_style()
    data = load_data(args.json_file)

    plot_hit_ratio(data, args.out_dir)
    plot_miss_ratio(data, args.out_dir)
    plot_amat_comparison(data, args.out_dir)
    plot_hits_vs_misses(data, args.out_dir)
    plot_miss_breakdown(data, args.out_dir)
    plot_comprehensive_dashboard(data, args.out_dir)
