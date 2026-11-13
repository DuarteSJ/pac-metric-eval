# gapbs

[GAP Benchmark Suite](https://github.com/sbeamer/gapbs): 6 graph kernels on
the 5 GAP graphs. PACT used all 30 (`bc-kron` ... `tc-web`).

| | |
|---|---|
| workloads | `<kernel>-<graph>`: kernels `bc bfs cc pr sssp tc` x `GAPBS_GRAPHS` (default `kron road`: 12; all 5 graphs: 30) |
| arguments | as GAP's `benchmark/bench.mk` (sssp on `.wsg`, tc on `U.sg`, sssp delta 50000 on road, else 2), fewer trials (`GAPBS_TRIALS` in `workload.sh`) |
| threads | `THREADS` (OpenMP) |
| setup | `./setup.sh`: clone + build into `src/`, graphs into `graphs/` |
| disk | kron + road: ~60 GB; all 5 graphs: ~200 GB |

| graph | source | size |
|---|---|---|
| kron | generated, `-g27 -k16` (also fig3's graph) | 134M vertices, 2.1B edges |
| urand | generated, `-u27 -k16` | 134M vertices, 2.1B edges |
| road | USA road network (DIMACS), downloaded | 24M vertices, 58M edges |
| twitter | Twitter follower graph, downloaded | 62M vertices, 1.5B edges |
| web | sk-2005 web crawl (SuiteSparse), downloaded | 51M vertices, 1.9B edges |

`src/` and `graphs/` are not in git.
