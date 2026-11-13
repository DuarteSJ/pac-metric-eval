# fig3: PACT Fig. 3 replication

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

On traquina, from the repo root:

```sh
GAPBS_GRAPHS=kron ./setup.sh gapbs          # GAPBS + the paper's kron graph (~17 GB), shared with fig2
cd fig3
./run.sh                                    # -> runs/cxl-<date>/
TIER=numa ./run.sh                          # remote-DDR slow tier, for comparison
CPUS=0-31 THREADS=32 TAG=cxl-32t ./run.sh   # one thread per CHA
python3 plot.py runs/cxl-<date>             # -> fig3.pdf/png, metrics.csv, summary.txt
```

Check `summary.txt`:
- `TOR busy frac` must be in [0,1], and TOR-MLP must be ≥ 1.
- `numastat.txt` should show bc's memory on the slow-tier node.

Fetch results locally:

```sh
rsync -a traquina:pac-metric-eval/fig3/runs/ runs/
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
| `cxl-8t-demand-20261113-111438` | 8 / 32 | 5.04 | 1.77 | 2.84 (2.56-3.05) | 0.918 |
| `cxl-32t-demand-20261113-111144` | 32 / 32 | 5.23 | 5.89 | 0.89 (0.85-0.93) | 0.974 |
| `numa-8t-demand-20261113-112133` | 8 / 32 | 4.98 | 1.75 | 2.85 (2.54-3.09) | 0.882 |
| `numa-32t-demand-20261113-112011` | 32 / 32 | 4.58 | 4.20 | 1.10 (1.00-1.15) | 0.928 |

L2MLP here is the paper's [7], demand loads only. The same runs also record
the Emerald Rapids definition of that metric (`DATA_RD`, adding L2
prefetches; `l2mlp_all` in `metrics.csv`), which the first runs plotted: it
is ~35% higher (e.g. 7.05 vs 5.23 on CXL at 32 threads; ratios 1.22-3.91),
and on NUMA it tracked TOR-MLP poorly (r = 0.39 at 32 threads), because it
follows prefetch traffic that TOR's demand-read filter excludes.

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
