# silo

[Silo](https://github.com/stephentu/silo) in-memory database, YCSB-style transactions. Not in PACT's set: one of the Demeter artifact's workloads,
kept as an extra data point.

| | |
|---|---|
| workload | `silo`: YCSB benchmark built into Silo, scale factor 55000, 10M ops per worker |
| threads | `--num-threads=$THREADS` |
| source | the Demeter fork, `workload/silo` at `DEMETER_REF` (`common.sh`) |
| setup | `./setup.sh`: fetch into `src/` and build (`src/out-perf.masstree/benchmarks/dbtest`) |

`src/` is not in git.
