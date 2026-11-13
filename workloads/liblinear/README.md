# liblinear

[LIBLINEAR](https://www.csie.ntu.edu.tw/~cjlin/liblinear/) training (L2-regularized L2-loss SVM, primal) on the kdda dataset. Not in PACT's set: one of the Demeter artifact's workloads,
kept as an extra data point.

| | |
|---|---|
| workload | `liblinear`: solver 2, kdda (8.4M instances, 20M features) |
| threads | `-m $THREADS` |
| source | the Demeter fork, `workload/liblinear` at `DEMETER_REF` (`common.sh`) |
| setup | `./setup.sh`: fetch into `src/` and build (`src/train`) |

`src/` is not in git.
