# parsec

[PARSEC 3.0](https://parsec.cs.princeton.edu/): 13 multithreaded benchmarks,
the same names as PACT's 13.

| | |
|---|---|
| workloads | `blackscholes bodytrack canneal dedup facesim ferret fluidanimate freqmine raytrace streamcluster swaptions vips x264` |
| inputs | `native` |
| threads | `THREADS` (each runconf's `${NTHREADS}`; freqmine via `OMP_NUM_THREADS`) |
| setup | `./setup.sh`: download (~3 GB) + build into `src/`, one run dir per package in `run/` |
| run | the binary directly, in `run/<pkg>/` with its args from `parsec/native.runconf`; not `parsecmgmt`, which would unpack the inputs inside the measured run |

Unverified: PARSEC 3.0 is old code and some packages may not build with a
recent gcc; failures are logged in `build-<pkg>.log` and skipped.

`src/`, `run/`, the tarball and the build logs are not in git.
