# spec

[SPEC CPU 2017](https://www.spec.org/cpu2017/) v1.0.2, the 43 rate and speed
benchmarks; PACT used all 43. **Licensed: nothing from SPEC is in git.** The
install is on traquina's NAS (`SPEC_DIR`, default
`/mnt/nas/inesc/ist196723/benchmarks/cpu2017`) and is shared, so it is only
read: everything `setup.sh` writes goes under this folder.

| | |
|---|---|
| workloads | 23 rate (`5xx.*_r`) + 20 speed (`6xx.*_s`) |
| inputs | reference (`refrate`, `refspeed`); one copy |
| threads | rate: 1; speed: OpenMP where the benchmark has it (`OMP_NUM_THREADS`) |
| binaries | the install's, label `mytest` (SPEC's `Example-gcc-linux-x86.cfg` default; also the label in PACT's own script) |
| setup | `./setup.sh`: `runcpu --action setup --nobuild --output_root out/` with a local copy of the config, then `run/<benchmark>` -> its run dir, with `pact-run.sh` (the reference command lines from `specinvoke -n`) |

Not built in the install (no `mytest` binary), skipped by `setup.sh`:
`510.parest_r 521.wrf_r 526.blender_r 527.cam4_r 621.wrf_s 627.cam4_s
628.pop2_s` (the Fortran/C++ ones that often fail with recent compilers;
traquina also has no `gfortran`). So 36 of 43 for now.

Unverified until run on traquina: that `runcpu --nobuild` accepts the
existing binaries with the local config copy, and the `specinvoke -n` output
format.

`out/`, `run/` and `pact-fig2.cfg` are not in git.
