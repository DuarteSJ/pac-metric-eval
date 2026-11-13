# graph500

[Graph500](https://graph500.org/) BFS, OpenMP CSR implementation (`omp-csr`). Not in PACT's set: one of the Demeter artifact's workloads,
kept as an extra data point.

| | |
|---|---|
| workload | `graph500`: scale 24 (16M vertices), edge factor 24, 10 BFS roots |
| threads | `OMP_NUM_THREADS` |
| source | the Demeter fork, `workload/graph500` at `DEMETER_REF` (`common.sh`) |
| setup | `./setup.sh`: fetch into `src/` and build (`src/omp-csr/omp-csr`) |

`src/` is not in git.
