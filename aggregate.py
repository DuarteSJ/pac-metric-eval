#!/usr/bin/env python3
"""Aggregate collect.sh raw perf files into PACT's Fig. 2 CSV.

  python3 aggregate.py results/<tag>     # -> results/<tag>/models.csv

Columns follow pact-modeling/skx/dat/r-l3_stall_skx.csv (tier i = 1, 2, 3),
so fig2.py and PACT's corr.plot read both:
  l3_stall_i              CYCLE_ACTIVITY.STALLS_L3_MISS
  demand_l2_mlp_i         OFFCORE_REQUESTS_OUTSTANDING.DEMAND_DATA_RD / .CYCLES_WITH_DEMAND_DATA_RD
  l3_miss_i               MEM_LOAD_RETIRED.L3_MISS
  offcore_load_latency_i  OFFCORE_REQUESTS_OUTSTANDING.DEMAND_DATA_RD / OFFCORE_REQUESTS.DEMAND_DATA_RD (cycles)
  (l3_miss/mlp)_i, (lat*l3_miss/mlp)_i
plus, for other MLP estimates on the same runs:
  l3m_mlp_i               OFFCORE_REQUESTS_OUTSTANDING.L3_MISS_DEMAND_DATA_RD / .CYCLES_WITH_L3_MISS_DEMAND_DATA_RD
  window_mlp_i            OFFCORE_REQUESTS_OUTSTANDING.L3_MISS_DEMAND_DATA_RD / cycles
  cycles_i, instructions_i, min_running_pct_i (lowest perf running share: < 100 = multiplexed)
A workload is written only if every tier has a raw file.
"""
import csv
import math
import sys
from pathlib import Path

E = {
    "stall": "cycle_activity.stalls_l3_miss",
    "miss": "mem_load_retired.l3_miss",
    "oro": "offcore_requests_outstanding.demand_data_rd",
    "oro_cyc": "offcore_requests_outstanding.cycles_with_demand_data_rd",
    "req": "offcore_requests.demand_data_rd",
    "l3m": "offcore_requests_outstanding.l3_miss_demand_data_rd",
    "l3m_cyc": "offcore_requests_outstanding.cycles_with_l3_miss_demand_data_rd",
    "cycles": "cycles",
    "instructions": "instructions",
}


def read_perf(path):
    """perf stat -x, (no -I): value,unit,event,run_time,pct,... -> {event: (value, pct)}."""
    out = {}
    with open(path) as f:
        for rec in csv.reader(f):
            if len(rec) < 5 or rec[0].startswith("#"):
                continue
            try:
                value = float(rec[0])
            except ValueError:  # <not counted> / <not supported>
                continue
            # Some perf versions append ":u" etc. to the event name.
            out[rec[2].split(":")[0]] = (value, float(rec[4] or 100))
    return out


def div(a, b):
    return a / b if b else math.nan


def tier_metrics(c):
    v = {k: c.get(name, (math.nan, 0))[0] for k, name in E.items()}
    mlp = div(v["oro"], v["oro_cyc"])
    lat = div(v["oro"], v["req"])
    pac = div(v["miss"], mlp)
    return {
        "l3_stall": v["stall"],
        "demand_l2_mlp": mlp,
        "l3_miss": v["miss"],
        "offcore_load_latency": lat,
        "(l3_miss/mlp)": pac,
        "(lat*l3_miss/mlp)": lat * pac,
        "l3m_mlp": div(v["l3m"], v["l3m_cyc"]),
        "window_mlp": div(v["l3m"], v["cycles"]),
        "cycles": v["cycles"],
        "instructions": v["instructions"],
        "min_running_pct": min((p for _, p in c.values()), default=math.nan),
    }


def main():
    run = Path(sys.argv[1])
    raws = sorted((run / "raw").glob("*_[0-9].csv"))
    by_name = {}
    for p in raws:
        name, idx = p.stem.rsplit("_", 1)
        by_name.setdefault(name, {})[int(idx)] = tier_metrics(read_perf(p))
    tiers = sorted({i for d in by_name.values() for i in d})
    keys = list(tier_metrics({}).keys())
    # PACT's column order: each metric for every tier, then the next metric.
    header = ["", "workload"] + [f"{k}_{i}" for k in keys for i in tiers]
    rows, partial = [], []
    for name in sorted(by_name):
        d = by_name[name]
        if set(d) != set(tiers):
            partial.append(name)
            continue
        rows.append([len(rows), name] + [d[i][k] for k in keys for i in tiers])
    with open(run / "models.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"wrote {run / 'models.csv'}: {len(rows)} workloads x {len(tiers)} tiers")
    if partial:
        print(f"skipped (missing tiers): {' '.join(partial)}")
    muxed = [r[1] for r in rows if min(r[2 + keys.index("min_running_pct") * len(tiers) + j]
                                       for j in range(len(tiers))) < 99.0]
    if muxed:
        print(f"multiplexed (counts scaled by perf): {' '.join(muxed)}")


if __name__ == "__main__":
    main()
