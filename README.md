# PACT Fig. 2 on traquina

Reproduces Figure 2 ("PAC modeling") of *PACT: A Criticality-First Design for
Tiered Memory* (ASPLOS '26): per workload and memory tier, whole-run
LLC-stalls against LLC-misses and LLC-misses/MLP, and the per-tier fit
`LLC-stalls = k * LLC-misses / MLP`.

`pact-modeling/` is PACT's own code and data, unmodified (MoatLab/PACT
`modeling/` at `dd11678`, MIT, see `LICENSE`). It has the paper's measurements
(`skx/dat/r-l3_stall_skx.csv`: 96 workloads x 3 tiers, Skylake-X), but its
collection script defines only 2 workloads, so the commands behind the 96 are
unpublished. The scripts here run our own workload set on traquina instead.

| file | role |
|---|---|
| `workloads.sh` | the workload set and each command |
| `setup.sh` | build GAPBS + graphs, PARSEC, Redis + YCSB, the GPT-2 venv |
| `collect.sh` | run every workload on every tier under `perf stat` |
| `aggregate.py` | raw perf files -> `models.csv` (PACT's columns) |
| `fig2.py` | Figure 2 + per-tier k and Pearson r |
| `gpt2.py` | GPT-2 generation (gpt2 group) |

`fig2.py` on PACT's data gives the paper's numbers exactly (k = 238.0 /
441.6 / 771.1; r = 0.83-0.90 for misses, 0.97-0.98 for misses/MLP):

```sh
python3 fig2.py pact-modeling/skx/dat/r-l3_stall_skx.csv --tiers "DRAM (90ns),NUMA (140ns),CXL (190ns)"
```

## Workloads

| group | workloads | vs PACT's 96 |
|---|---|---|
| `gapbs` | bc, bfs, cc, pr, sssp, tc x kron, road (12) | 12 of their 30 GAPBS names; GAP benchmark inputs and arguments (`benchmark/bench.mk`), fewer trials. `gapbs-all`: all 5 graphs (30), `GAPBS_GRAPHS` picks others |
| `demeter` | graph500, xsbench, btree, gups, liblinear, bwaves (SPEC 603.bwaves_s), silo (YCSB) | 1 of their 43 SPEC (bwaves_s); the rest are extra |
| `parsec` | the same 13 PARSEC 3.0 names, native inputs | binaries run directly from a prepared run dir (not through `parsecmgmt`, which unpacks the inputs inside the run) |
| `ycsb` | YCSB A-F on Redis (10M records, 20M ops) | same 6 names; their key-value store is unpublished, Redis is a guess from their Redis results. perf counts only the server, during the run phase; the client runs on cores 8-23 |
| `gpt2` | GPT-2 124M / 355M / 774M / 1558M, unconditional sampling (`gpt2.py`) | same 4 names; theirs match OpenAI's TF1 `generate_unconditional_samples.py`, this is the same task on PyTorch + transformers |
| — | 42 other SPEC CPU 2017 | licensed |

`all` = `gapbs` + `demeter` + `parsec` + `ycsb` + `gpt2`: 42 workloads (126
runs), 29% graph workloads (PACT: 31%).

## Tiers (traquina)

| index | tier | node | PACT |
|---|---|---|---|
| 1 | local DRAM | 0 | DRAM, 90 ns |
| 2 | remote socket DRAM | 1 | NUMA, 140 ns |
| 3 | CXL Type-3 expander | 2 | remote socket with throttled uncore, 190 ns |

Workloads run on cores 0-7 (socket 0) with 8 threads, as PACT
(`OMP_NUM_THREADS=8`), memory bound with `numactl --membind`. Inputs are
loaded into the page cache on the tier's node first (`vmtouch`, as PACT).

## Counters

PACT's four, plus three for the latency column and for other MLP estimates
(T1/T2 pairs are perf groups, so both see the same time slices):

| column | events |
|---|---|
| `l3_stall` | `CYCLE_ACTIVITY.STALLS_L3_MISS` |
| `l3_miss` | `MEM_LOAD_RETIRED.L3_MISS` |
| `demand_l2_mlp` | `OFFCORE_REQUESTS_OUTSTANDING.DEMAND_DATA_RD / .CYCLES_WITH_DEMAND_DATA_RD` |
| `offcore_load_latency` | `OFFCORE_REQUESTS_OUTSTANDING.DEMAND_DATA_RD / OFFCORE_REQUESTS.DEMAND_DATA_RD` (cycles) |
| `l3m_mlp` | `OFFCORE_REQUESTS_OUTSTANDING.L3_MISS_DEMAND_DATA_RD / .CYCLES_WITH_L3_MISS_DEMAND_DATA_RD` |
| `window_mlp` | `OFFCORE_REQUESTS_OUTSTANDING.L3_MISS_DEMAND_DATA_RD / cycles` |

## Run (on traquina)

```sh
sudo apt install vmtouch default-jre-headless   # once
./setup.sh all                            # or gapbs / parsec / ycsb / gpt2
DRY=1 ./collect.sh all                    # check the commands
./collect.sh all                          # results/<date>/raw, then models.csv
python3 fig2.py results/<date>/models.csv
```

`collect.sh` takes groups or workload names (`./collect.sh bc-kron xsbench`),
skips runs it already has (resume after an interruption), and records failed
runs as `*.failed`. `aggregate.py` writes only workloads with all three tiers
and reports runs whose counters perf multiplexed.

## Status

- Tested locally: `fig2.py` on PACT's data, `aggregate.py` + `fig2.py` on
  synthetic perf output, `DRY=1 collect.sh all` (126 runs), shellcheck.
- Not yet run on traquina. Unverified there: the `perf` event names on
  Emerald Rapids for this event set; GAP's road download (an old university
  server); PARSEC builds on Ubuntu 26.04 and the run-dir layout
  (`native.runconf`, `inst/*.gcc`); the YCSB 0.17.0 Redis-binding tarball
  layout (`bin/ycsb.sh`); the GPT-2 venv.
- First check on traquina: `./collect.sh bc-kron` (3 runs, minutes), then
  one workload per group.
