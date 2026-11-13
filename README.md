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

## Layout

```
pact-fig2/
  setup.sh          set up workload folders (runs workloads/<name>/setup.sh)
  collect.sh        run workloads x tiers under perf stat -> results/<tag>/raw/
  aggregate.py      raw perf files -> results/<tag>/models.csv (PACT's columns)
  fig2.py           Figure 2 + per-tier k and Pearson r
  workloads.sh      loads every workloads/<name>/workload.sh
  workloads/        one folder per suite: README.md, setup.sh, workload.sh
  pact-modeling/    PACT's own Fig. 2 code and data (unmodified)
```

`fig2.py` on PACT's data gives the paper's numbers exactly (k = 238.0 /
441.6 / 771.1; r = 0.83-0.90 for misses, 0.97-0.98 for misses/MLP):

```sh
python3 fig2.py pact-modeling/skx/dat/r-l3_stall_skx.csv --tiers "DRAM (90ns),NUMA (140ns),CXL (190ns)"
```

## Workloads

See [`workloads/README.md`](workloads/README.md): 11 folders, 84 workloads
by default (252 runs over 3 tiers).

| folder | workloads | PACT's 96 |
|---|---|---|
| `gapbs` | 12 (6 kernels x kron, road); 30 with `GAPBS_GRAPHS` set to all 5 graphs | 30 |
| `spec` | 43 SPEC CPU 2017 (36 built in the install) | 43 |
| `parsec` | 13 | 13 |
| `ycsb` | 6, on Redis | 6 |
| `gpt2` | 4 | 4 |
| `graph500`, `xsbench`, `btree`, `gups`, `liblinear`, `silo` | 1 each (Demeter's workloads) | extra |

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
sudo apt install vmtouch default-jre-headless   # once (Java: YCSB client)
./setup.sh all                    # or some folders: ./setup.sh gapbs spec
DRY=1 ./collect.sh all            # check the commands
./collect.sh all                  # results/<date>/raw, then models.csv
python3 fig2.py results/<date>/models.csv
```

`collect.sh` takes folders or workload names (`./collect.sh gapbs 505.mcf_r`),
skips runs it already has (resume after an interruption), and records failed
runs as `*.failed`. `aggregate.py` writes only workloads with all three tiers
and reports runs whose counters perf multiplexed.

## Status

- Tested locally: `fig2.py` on PACT's data, `aggregate.py` + `fig2.py` on
  synthetic perf output, `DRY=1 collect.sh all` (252 runs), shellcheck.
- Not yet run on traquina. Unverified there: the `perf` event names on
  Emerald Rapids for this event set, and each folder's setup (see the
  "Unverified" notes in the folder READMEs). Traquina has no `gfortran`,
  `cargo` or `java`: needed for the 7 unbuilt SPEC benchmarks, `gups` and
  the YCSB client.
- First check on traquina: `./collect.sh bc-kron` (3 runs, minutes), then
  one workload per folder.
