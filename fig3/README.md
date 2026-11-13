# PACT Fig. 3 replication

Replicates Figure 3 ("Per-tier MLP") of *PACT: A Criticality-First Design for
Tiered Memory* (ASPLOS '26): bc-kron with its memory on the slow tier, and
three MLP estimates over time.

| series | definition | counters |
|---|---|---|
| L2MLP (red) | `Info_Memory_Latency_Load_L2_MLP`, workload cores | `OFFCORE_REQUESTS_OUTSTANDING.DATA_RD / .CYCLES_WITH_DATA_RD` |
| TOR-MLP (blue) | ΔT1/ΔT2 summed over the CPU socket's CHAs (Alg. 1) | T1 `UNC_CHA_TOR_OCCUPANCY.IA_MISS_DRD_<tier>`, T2 `UNC_CHA_COUNTER0_OCCUPANCY` thresh=1 |
| BW×Latency/64B (gray, right axis) | Little's law | slow-tier bytes/s × TOR latency (T1 / `TOR_INSERTS`) |

## Machine

traquina: 2× Xeon Gold 6530 (Emerald Rapids, 32 cores and 32 CHAs per
socket) and two CXL Type-3 expanders as CPU-less nodes 2 and 3 (64 GB each,
attached to socket 0). The paper emulated CXL with a throttled remote socket;
here the slow tier is real CXL.

bc runs on cores 0-7 (socket 0) with `--membind` to the slow tier:

| `TIER` | node | TOR umask | bandwidth |
|---|---|---|---|
| `cxl` (default) | 2 | `IA_MISS_DRD_CXL_ACC` 0x10c8178201 | `UNC_CXLCM_{RXC,TXC}_PACK_BUF_INSERTS.MEM_DATA` (64B / 16B each) |
| `numa` | 1 | `IA_MISS_DRD_REMOTE` 0xc8177e01 | socket-1 `UNC_M_CAS_COUNT.{RD,WR}` |

Encodings were checked on traquina with a 4 GB sweep on node 2:
- TOR inserts = 67M, i.e. 4 GB / 64 B.
- `_CXL_EXP_LOCAL` stays at 0.
- `cxl_pmu_mem*` device counters read ~0, so they aren't used.
- `0x1f thresh=1` doesn't multiplex. A second `0x36 thresh=1` would also
  need counter 0 and gets multiplexed.

perf only counts on the workload CPUs plus each socket's uncore reader CPU.
Counting core events on all 128 CPUs stretches 20 ms intervals to ~45 ms.

## Run

On traquina, in `~/fig3`:

```sh
./setup.sh                          # GAPBS + kron27.sg (paper graph, ~18 GB)
./run.sh                            # -> runs/cxl-<date>/
TIER=numa ./run.sh                  # remote-DDR slow tier, for comparison
python3 plot.py runs/cxl-<date>     # -> fig3.pdf/png, metrics.csv, summary.txt
```

Quick check on the existing scale-26 graph:

```sh
GRAPH=~/demeter-criticality/bin/kron26.sg BC_ARGS="-i1 -n1" TAG=smoke ./run.sh
```

Check `summary.txt`:
- `TOR busy frac` must be in [0,1], and TOR-MLP must be ≥ 1.
- `numastat.txt` should show bc's memory on the slow-tier node.

Fetch results locally:

```sh
rsync -a traquina:fig3/runs/ runs/
```

Knobs are listed in the `run.sh` header: `TIER`, `CPUS`, `THREADS`,
`INTERVAL_MS` (default 20 ms, PACT's window), `GRAPH`, `BC_ARGS`, `TIMEOUT`.
`plot.py` options:
- `--xlim S E` sets panel (a) (default 50-150 s, as in the paper, if the run
  is that long; otherwise from the end of the graph load to the end).
- `--zoom S E` sets panel (b) (default 80-95 s, as in the paper).
- `--abin` sets panel (a)'s bin width (default 0: raw intervals, as in the paper).
- `--bin` sets the bin width for the steady-state stats (default 1 s).
- `--ylim L R` sets the y-axis tops (`10 40` = paper).
- `--reads-only` drops writes from BW.

## Reading the result

TOR-MLP is the paper's Σ over CHAs (Alg. 1), i.e. the average queue depth of a
busy CHA. L2MLP is outstanding misses per busy core. The two only match when
the number of active cores is close to the number of CHAs. The paper's
Skylake ran 8 threads on 10 CHAs. traquina has 32 CHAs per socket, so:

| run | threads / CHAs | L2MLP | TOR-MLP | L2MLP ÷ TOR-MLP (median, IQR) | r(TOR, L2) |
|---|---|---|---|---|---|
| `cxl-20261029-121309` | 8 / 32 | 6.83 | 1.77 | 3.88 (3.57-4.07) | 0.865 |
| `cxl-32t-20261029-133439` | 32 / 32 | 7.10 | 5.89 | 1.22 (1.14-1.26) | 0.889 |
| `numa-8t-20261029-140041` | 8 / 32 | 6.85 | 1.73 | 3.98 (3.63-4.18) | 0.641 |
| `numa-32t-20261029-135913` | 32 / 32 | 6.36 | 4.14 | 1.48 (1.36-1.56) | 0.393 |

The thread/CHA effect is the same on both tiers. On NUMA (remote DDR, 197-220 ns,
19-55 GB/s), TOR-MLP stays flat during the slow L2MLP decays after each phase
change, which the gray memory-side BW x Latency does follow. That points to
non-demand (prefetch) traffic, which TOR's DRd filter excludes. Not yet verified.

Steady state only, i.e. after bc's graph load, in 1 s bins (`summary.txt`).
During the load, L2MLP is high from reading the `.sg` file out of page cache
in DRAM, while the CXL-filtered TOR-MLP correctly stays at 1.

`metrics.csv` also has `inflight`: TOR occupancy per CHA clock, i.e. mean
outstanding slow-tier demand reads across the socket. BW×Latency/64B tracks
it, plus the prefetch and write traffic the paper mentions.

Plot scale: y-axes fit the 99th percentile (never below the paper's 10 / 40),
so single-interval transition spikes are clipped. `--ylim 10 40` forces the
paper's scale.

perf interval: core events on 32 CPUs push 20 ms intervals to a ~52 ms median
(28 ms with 8 CPUs).
