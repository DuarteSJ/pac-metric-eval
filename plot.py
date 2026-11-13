#!/usr/bin/env python3
"""Plot PACT Fig. 3 (per-tier MLP for bc-kron) from a run.sh directory.

  python3 plot.py runs/numa-YYYYmmdd-HHMMSS [--zoom 80 95] [--bin 1.0]

(a) whole run, counters binned to --bin seconds; (b) zoom at the raw
perf interval. Left axis: L2MLP (red), TOR-MLP (blue). Right axis:
Bandwidth x Latency / 64B (gray). Writes fig3.pdf/.png, metrics.csv and
summary.txt into the run directory.

Metrics are ratios of summed counters, so binning never averages ratios:
  L2MLP    = oro_data_rd / oro_cyc_data_rd                   (workload cores)
  TOR-MLP  = tor_occ / tor_cyc                               (CPU socket CHAs)
  latency  = tor_occ / tor_ins CHA cycles, / CHA clock -> ns (CPU socket CHAs)
  BW       = bw_rd * rd_bytes [+ bw_wr * wr_bytes] / dt      (slow tier)
  approx   = BW * latency / 64B
  inflight = tor_occ / per-CHA clock: mean outstanding slow-tier demand reads
             across the socket (metrics.csv only)
"""
import argparse
import csv
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

CPU_EVENTS = ("oro_data_rd", "oro_cyc_data_rd", "tor_occ", "tor_cyc", "tor_ins", "cha_clk")
MEM_EVENTS = ("bw_rd", "bw_wr")


def read_meta(run):
    meta = {}
    for line in (run / "meta.txt").read_text().splitlines():
        if not line.strip():
            break
        k, _, v = line.partition(" ")
        meta[k] = v.strip()
    return meta


def read_perf(path):
    """perf stat -I -x, --per-socket -> {time: {(socket, event): count}}."""
    rows = defaultdict(dict)
    with open(path) as f:
        for rec in csv.reader(f):
            if not rec or rec[0].startswith("#"):
                continue
            sock = next((i for i, x in enumerate(rec) if re.fullmatch(r"S\d+", x)), None)
            if sock is None or len(rec) < sock + 5:
                continue
            t, value, event = float(rec[0]), rec[sock + 2], rec[sock + 4]
            try:
                rows[t][(int(rec[sock][1:]), event)] = float(value)
            except ValueError:  # <not counted> / <not supported>
                continue
    return dict(sorted(rows.items()))


def samples(rows, cpu_sock, mem_sock):
    """One record per interval: end time, length and the counters we use."""
    out, prev = [], 0.0
    for t, vals in rows.items():
        s = {"t": t, "dt": t - prev}
        s.update({e: vals.get((cpu_sock, e), math.nan) for e in CPU_EVENTS})
        s.update({e: vals.get((mem_sock, e), math.nan) for e in MEM_EVENTS})
        out.append(s)
        prev = t
    return out


def binned(recs, width):
    """Sum counters into fixed-width time bins (t = bin end)."""
    bins = {}
    for r in recs:
        k = math.ceil(r["t"] / width - 1e-9)
        b = bins.setdefault(k, {"t": k * width, "dt": 0.0, **{e: 0.0 for e in CPU_EVENTS + MEM_EVENTS}})
        for e in ("dt",) + CPU_EVENTS + MEM_EVENTS:
            b[e] += r[e]
    return [bins[k] for k in sorted(bins)]


def div(a, b):
    return a / b if b and not math.isnan(a) and not math.isnan(b) else math.nan


def metrics(r, meta, writes):
    nr_cha = int(meta["nr_cha"])
    f_cha = div(r["cha_clk"], nr_cha * r["dt"])          # Hz, per CHA
    lat_s = div(div(r["tor_occ"], r["tor_ins"]), f_cha)  # s
    nbytes = r["bw_rd"] * int(meta["rd_bytes"])
    if writes:
        nbytes += r["bw_wr"] * int(meta["wr_bytes"])
    bw = div(nbytes, r["dt"])                             # B/s
    return {
        "t": r["t"],
        "l2mlp": div(r["oro_data_rd"], r["oro_cyc_data_rd"]),
        "tor_mlp": div(r["tor_occ"], r["tor_cyc"]),
        "lat_ns": lat_s * 1e9,
        "bw_gbs": bw / 1e9,
        "approx_mlp": bw * lat_s / 64.0,
        "inflight": div(r["tor_occ"], div(r["cha_clk"], nr_cha)),
        "tor_busy": div(r["tor_cyc"], r["cha_clk"]),
    }


def pearson(xs, ys):
    pts = [(x, y) for x, y in zip(xs, ys) if not (math.isnan(x) or math.isnan(y))]
    if len(pts) < 3:
        return math.nan
    n = len(pts)
    mx = sum(p[0] for p in pts) / n
    my = sum(p[1] for p in pts) / n
    sxy = sum((x - mx) * (y - my) for x, y in pts)
    sxx = sum((x - mx) ** 2 for x, _ in pts)
    syy = sum((y - my) ** 2 for _, y in pts)
    return sxy / math.sqrt(sxx * syy) if sxx and syy else math.nan


def mean(xs):
    xs = [x for x in xs if not math.isnan(x)]
    return sum(xs) / len(xs) if xs else math.nan


def read_time(run):
    """bc's graph-load time (s): before it, traffic is the .sg file read from
    page cache, not slow-tier accesses by the kernel."""
    log = run / "bc.log"
    if log.exists():
        for line in log.read_text().splitlines():
            if line.startswith("Read Time:"):
                return float(line.split()[-1])
    return 0.0


def percentile(xs, q):
    xs = sorted(x for x in xs if not math.isnan(x))
    return xs[min(len(xs) - 1, int(q * len(xs)))] if xs else 0.0


def panel(ax, ms, title, xlim, ylim_l, ylim_r):
    t = [m["t"] for m in ms]
    # Paper style: light-gray approximation on its own right-hand scale, behind
    # translucent L2MLP / TOR-MLP (overlap reads as purple).
    rx = ax.twinx()
    rx.plot(t, [m["approx_mlp"] for m in ms], color="0.78", lw=1.0, label="BW x Latency")
    rx.set_ylim(0, ylim_r)
    rx.set_ylabel("Approximated MLP", color="0.6")
    rx.tick_params(axis="y", colors="0.6")
    ax.set_zorder(rx.get_zorder() + 1)
    ax.patch.set_visible(False)
    ax.plot(t, [m["l2mlp"] for m in ms], color="#ff3b3b", alpha=0.8, lw=1.0, label="L2MLP")
    ax.plot(t, [m["tor_mlp"] for m in ms], color="#4b4bff", alpha=0.6, lw=1.0, label="TOR-MLP")
    ax.set_xlim(*xlim)
    ax.set_ylim(0, ylim_l)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("MLP")
    ax.set_title(title)
    return rx


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("run", type=Path)
    ap.add_argument("--zoom", type=float, nargs=2, metavar=("START", "END"),
                    help="panel (b) window in s (default: paper's 80-95, else middle 15 s)")
    ap.add_argument("--bin", type=float, default=1.0, help="bin width in s for the steady-state stats")
    ap.add_argument("--abin", type=float, default=0.0,
                    help="panel (a) bin width in s (default 0: raw intervals, as in the paper)")
    ap.add_argument("--xlim", type=float, nargs=2, metavar=("START", "END"),
                    help="panel (a) window in s (default: paper's 50-150, else graph load to end)")
    ap.add_argument("--reads-only", action="store_true",
                    help="BW from slow-tier reads only (default: reads + writes)")
    ap.add_argument("--ylim", type=float, nargs=2, metavar=("MLP", "APPROX"),
                    help="left/right y-axis tops (paper: 10 40; default: fit the "
                         "99th percentile, at least the paper's)")
    args = ap.parse_args()

    meta = read_meta(args.run)
    cpu_sock = int(meta["cpu_socket"])
    mem_sock = int(meta["bw_socket"])
    writes = not args.reads_only

    recs = samples(read_perf(args.run / "perf.csv"), cpu_sock, mem_sock)
    if not recs:
        sys.exit(f"no samples in {args.run / 'perf.csv'}")
    raw = [metrics(r, meta, writes) for r in recs]
    coarse = [metrics(r, meta, writes) for r in binned(recs, args.bin)]
    shown_a = raw if args.abin <= 0 else [metrics(r, meta, writes) for r in binned(recs, args.abin)]

    with open(args.run / "metrics.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(raw[0]))
        w.writeheader()
        w.writerows(raw)

    end = recs[-1]["t"]
    if args.zoom:
        z0, z1 = args.zoom
    elif end >= 95:
        z0, z1 = 80.0, 95.0
    else:
        z0, z1 = max(0.0, end / 2 - 7.5), min(end, end / 2 + 7.5)
    zoom = [m for m in raw if z0 <= m["t"] <= z1]
    t_read = read_time(args.run)
    if args.xlim:
        x0, x1 = args.xlim
    elif end >= 150 and t_read < 50:
        x0, x1 = 50.0, 150.0  # paper's window
    else:
        x0, x1 = math.floor(t_read), end
    shown_a = [m for m in shown_a if x0 <= m["t"] <= x1]

    col = lambda ms, k: [m[k] for m in ms]
    total = recs[0].copy()
    for r in recs[1:]:
        for e in ("dt",) + CPU_EVENTS + MEM_EVENTS:
            total[e] += r[e]
    tot = metrics(total, meta, writes)
    # Steady state: after the graph load, in --bin bins.
    steady = [m for m in coarse if m["t"] - args.bin >= t_read]
    ratio = [m["l2mlp"] / m["tor_mlp"] for m in steady
             if not math.isnan(m["l2mlp"]) and not math.isnan(m["tor_mlp"]) and m["tor_mlp"]]
    rq = [percentile(ratio, q) for q in (0.25, 0.5, 0.75)]
    threads = meta.get("threads", "?")
    summary = "\n".join([
        f"run            {args.run}",
        f"slow tier      {meta['tier']} (node {meta['memnode']})",
        f"duration       {end:.1f} s, {len(recs)} intervals of {meta['interval_ms']} ms",
        f"L2MLP          {tot['l2mlp']:.2f} (whole run)",
        f"TOR-MLP        {tot['tor_mlp']:.2f}",
        f"BWxLat/64B     {tot['approx_mlp']:.2f}  (BW {'rd+wr' if writes else 'rd'})",
        f"slow-tier lat  {tot['lat_ns']:.0f} ns (TOR occ/inserts, demand reads)",
        f"in-flight      {tot['inflight']:.2f} demand reads, socket-wide (TOR occ / CHA clock)",
        f"slow-tier BW   {tot['bw_gbs']:.2f} GB/s",
        # Sanity: T2 counts CHA cycles, so it must be <= cha_clk; TOR-MLP >= 1.
        f"TOR busy frac  {div(total['tor_cyc'], total['cha_clk']):.3f} (T2 / CHA clock, must be in [0,1])",
        f"pearson(TOR-MLP, L2MLP)      raw {pearson(col(raw, 'tor_mlp'), col(raw, 'l2mlp')):.3f}"
        f"  {args.bin:g}s-bins {pearson(col(coarse, 'tor_mlp'), col(coarse, 'l2mlp')):.3f}",
        f"pearson(BWxLat, TOR-MLP)     raw {pearson(col(raw, 'approx_mlp'), col(raw, 'tor_mlp')):.3f}"
        f"  {args.bin:g}s-bins {pearson(col(coarse, 'approx_mlp'), col(coarse, 'tor_mlp')):.3f}",
        f"steady (t > read {t_read:.1f}s, {args.bin:g}s bins, {threads} threads, {meta['nr_cha']} CHAs):",
        f"  pearson(TOR-MLP, L2MLP)    {pearson(col(steady, 'tor_mlp'), col(steady, 'l2mlp')):.3f}",
        f"  pearson(BWxLat, TOR-MLP)   {pearson(col(steady, 'approx_mlp'), col(steady, 'tor_mlp')):.3f}",
        f"  L2MLP / TOR-MLP            median {rq[1]:.2f}  IQR {rq[0]:.2f}-{rq[2]:.2f}",
        f"  means                      L2MLP {mean(col(steady, 'l2mlp')):.2f}  TOR-MLP "
        f"{mean(col(steady, 'tor_mlp')):.2f}  BWxLat {mean(col(steady, 'approx_mlp')):.2f}",
        f"zoom {z0:g}-{z1:g}s     TOR-MLP mean {mean(col(zoom, 'tor_mlp')):.2f}, "
        f"L2MLP mean {mean(col(zoom, 'l2mlp')):.2f}",
    ])
    print(summary)
    (args.run / "summary.txt").write_text(summary + "\n")

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    finite = lambda xs: [x for x in xs if not math.isnan(x)] or [0]
    # Paper scales (10 / 40), widened to a round number if the data's 99th
    # percentile exceeds them; single-interval transition spikes are clipped.
    if args.ylim:
        ylim_l, ylim_r = args.ylim
    else:
        peak_l = percentile(finite(col(shown_a, "l2mlp") + col(shown_a, "tor_mlp") +
                                   col(zoom, "l2mlp") + col(zoom, "tor_mlp")), 0.99)
        peak_r = percentile(finite(col(shown_a, "approx_mlp") + col(zoom, "approx_mlp")), 0.99)
        ylim_l = max(10, 2 * math.ceil(peak_l * 1.1 / 2))
        ylim_r = max(40, 10 * math.ceil(peak_r * 1.1 / 10))

    fig, (a, b) = plt.subplots(1, 2, figsize=(10, 3.2), constrained_layout=True)
    panel(a, shown_a, f"[a] Temporal MLP (bc-kron, {meta['tier'].upper()}, {threads}T)",
          (x0, x1), ylim_l, ylim_r)
    rb = panel(b, zoom, "[b] MLP Stability", (z0, z1), ylim_l, ylim_r)
    handles = b.get_legend_handles_labels()[0] + rb.get_legend_handles_labels()[0]
    b.legend(handles, [h.get_label() for h in handles], loc="upper right", frameon=False, fontsize=8)
    for ext in ("pdf", "png"):
        fig.savefig(args.run / f"fig3.{ext}", dpi=200)
    print(f"wrote {args.run / 'fig3.pdf'}")


if __name__ == "__main__":
    main()
