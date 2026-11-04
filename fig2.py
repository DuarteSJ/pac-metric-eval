#!/usr/bin/env python3
"""Plot PACT Fig. 2 (PAC modeling) from a per-workload, per-tier CSV.

  python3 fig2.py results/models.csv [-o fig2.png] [--tiers "DRAM,NUMA,CXL"]
  python3 fig2.py pact-modeling/skx/dat/r-l3_stall_skx.csv   # paper's data

Input columns (PACT's format, tier i = 1, 2, 3): workload, l3_stall_i,
l3_miss_i, (l3_miss/mlp)_i. Panels (a)-(c): LLC-stalls against LLC-misses
(gray) and LLC-misses/MLP (color), one point per workload. Panel (d): the
per-tier fit LLC-stalls = k * LLC-misses/MLP through the origin (least
squares, as PACT's gnuplot `fit f(x) = a*x`). Prints k and Pearson r of both
predictors per tier.
"""
import argparse
import csv
import math
from pathlib import Path

COLORS = ("#e8312f", "#4b4bff", "#22c022")  # paper: red, blue, green


def read(path):
    with open(path) as f:
        rows = list(csv.DictReader(f))
    tiers = sorted({int(k.rsplit("_", 1)[1]) for k in rows[0] if k.startswith("l3_stall_")})
    return rows, tiers


def col(rows, name):
    out = []
    for r in rows:
        try:
            out.append(float(r[name]))
        except (KeyError, ValueError):
            out.append(math.nan)
    return out


def pearson(xs, ys):
    p = [(x, y) for x, y in zip(xs, ys) if not (math.isnan(x) or math.isnan(y))]
    if len(p) < 3:
        return math.nan
    n = len(p)
    mx, my = sum(x for x, _ in p) / n, sum(y for _, y in p) / n
    sxy = sum((x - mx) * (y - my) for x, y in p)
    sxx = sum((x - mx) ** 2 for x, _ in p)
    syy = sum((y - my) ** 2 for _, y in p)
    return sxy / math.sqrt(sxx * syy) if sxx and syy else math.nan


def fit_origin(xs, ys):
    """Least-squares slope of y = k*x."""
    p = [(x, y) for x, y in zip(xs, ys) if not (math.isnan(x) or math.isnan(y))]
    sxx = sum(x * x for x, _ in p)
    return sum(x * y for x, y in p) / sxx if sxx else math.nan


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv", type=Path)
    ap.add_argument("-o", "--out", type=Path, help="figure path (default: next to the CSV, fig2.png + .pdf)")
    ap.add_argument("--tiers", default="DRAM,NUMA,CXL", help="tier labels, comma-separated, in column order")
    args = ap.parse_args()

    rows, tiers = read(args.csv)
    labels = args.tiers.split(",")
    fits = []
    lines = [f"{args.csv}: {len(rows)} workloads"]
    for i, t in enumerate(tiers):
        stall = col(rows, f"l3_stall_{t}")
        miss = col(rows, f"l3_miss_{t}")
        pac = col(rows, f"(l3_miss/mlp)_{t}")
        k = fit_origin(pac, stall)
        fits.append((t, k, stall, miss, pac))
        lines.append(f"  tier {t} ({labels[i]}): k = {k:.1f}   r(stall, miss) = {pearson(miss, stall):.3f}"
                     f"   r(stall, miss/mlp) = {pearson(pac, stall):.3f}")
    print("\n".join(lines))

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(1, len(tiers) + 1, figsize=(3.0 * (len(tiers) + 1), 2.8),
                             constrained_layout=True)
    for ax, (t, k, stall, miss, pac), label, color in zip(axes, fits, labels, COLORS):
        ax.scatter([x / 1e10 for x in miss], [y / 1e12 for y in stall], s=14, color="0.65",
                   label="LLC-miss")
        ax.scatter([x / 1e10 for x in pac], [y / 1e12 for y in stall], s=16, marker="^",
                   color=color, label="LLC-miss/MLP")
        ax.set_xlim(left=0)
        ax.set_ylim(bottom=0)
        ax.set_title(f"[{'abc'[t - 1]}] {label}")
        ax.legend(loc="lower right", frameon=False, fontsize=7)
    axes[0].set_ylabel("LLC-Stalls (x$10^{12}$)")
    fig.supxlabel("Metrics: LLC-miss (●) and PAC = LLC-miss/MLP (▲) (x$10^{10}$)", fontsize=9)

    ax = axes[-1]
    xmax = max(max((x for x in pac if not math.isnan(x)), default=0) for *_, pac in fits) / 1e10
    for (t, k, *_), label, color in zip(fits, labels, COLORS):
        ax.plot([0, xmax], [0, k * xmax * 1e10 / 1e12], color=color, lw=2, label=f"{label}: y={k:.1f}x")
    ax.set_xlim(0, xmax)
    ax.set_ylim(bottom=0)
    ax.set_title("[d] PAC Models")
    ax.set_xlabel("LLC-miss/MLP (x$10^{10}$)")
    ax.legend(loc="upper left", frameon=False, fontsize=7)

    out = args.out or args.csv.with_name("fig2.png")
    fig.savefig(out, dpi=200)
    fig.savefig(out.with_suffix(".pdf"))
    out.with_name("fig2-summary.txt").write_text("\n".join(lines) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
