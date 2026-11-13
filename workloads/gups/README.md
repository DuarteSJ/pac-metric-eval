# gups

GUPS (giga-updates per second), random updates on a large array, with a hot set (Demeter's Rust version). Not in PACT's set: one of the Demeter artifact's workloads,
kept as an extra data point.

| | |
|---|---|
| workload | `gups`: 14 GB array, 800M updates; 1 GB hot set (top of the array) gets 9x the updates |
| threads | `--thread=$THREADS` |
| source | the Demeter fork, `workload/gups` at `DEMETER_REF` (`common.sh`) |
| setup | `./setup.sh`: fetch into `src/` and build (`src/target/release/gups`) |

`src/` is not in git.
