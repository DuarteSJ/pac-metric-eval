# xsbench

[XSBench](https://github.com/ANL-CESAR/XSBench): Monte Carlo neutron transport cross-section lookups. Not in PACT's set: one of the Demeter artifact's workloads,
kept as an extra data point.

| | |
|---|---|
| workload | `xsbench`: history-based, unionized grid, 25000 gridpoints, 10M particles |
| threads | `-t $THREADS` |
| source | the Demeter fork, `workload/xsbench` at `DEMETER_REF` (`common.sh`) |
| setup | `./setup.sh`: fetch into `src/` and build (`src/XSBench`) |

`src/` is not in git.
