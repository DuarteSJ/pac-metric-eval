# ycsb

[YCSB](https://github.com/brianfrankcooper/YCSB) core workloads A-F on
[Redis](https://redis.io/), the same 6 names as PACT's (`workloada` ...
`workloadf`). PACT does not say which store it ran YCSB on; Redis is a guess
from the paper's Redis results.

| | |
|---|---|
| workloads | `ycsb-a` ... `ycsb-f` (YCSB's `workloads/workload[a-f]`) |
| size | `YCSB_RECORDS` 10M records (~1 KB each, ~10 GB), `YCSB_OPS` 20M operations |
| measured | the Redis server only, during the run phase: `perf stat -p <redis pid>` while the client runs |
| placement | server on `CPUS` with memory on the tier; client (16 threads) on `CLIENT_CPUS` (8-23) with memory on DRAM |
| setup | `./setup.sh`: Redis stable into `redis/`, YCSB 0.17.0 Redis binding into `ycsb/`; needs Java |

Each run loads the records again (not measured), so every workload starts
from the same state.

Unverified: the YCSB 0.17.0 binding tarball layout (`bin/ycsb.sh`).

`redis/` and `ycsb/` are not in git.
