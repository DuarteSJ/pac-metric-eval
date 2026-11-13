# btree

B-tree index: build, then random lookups (multithreaded). Not in PACT's set: one of the Demeter artifact's workloads,
kept as an extra data point.

| | |
|---|---|
| workload | `btree`: 2e8 elements, 2e9 lookups |
| threads | `OMP_NUM_THREADS` |
| source | the Demeter fork, `workload/btree` at `DEMETER_REF` (`common.sh`) |
| setup | `./setup.sh`: fetch into `src/` and build (`src/bench_btree_mt`) |

`src/` is not in git.
