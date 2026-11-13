# Workloads

One folder per suite or project. Each has the same three files:

| file | role |
|---|---|
| `README.md` | what it is, where the code comes from, inputs, threads |
| `setup.sh` | fetch and build into the folder (run once on traquina) |
| `workload.sh` | the workload names and how each one runs (sourced by `../workloads.sh`) |

Code, binaries and inputs land inside the folder (`src/`, `graphs/`, `run/`,
...) and are **not in git**: the open-source code is downloaded by
`setup.sh`, and SPEC is licensed.

| folder | workloads | source | in PACT's 96 |
|---|---|---|---|
| [`gapbs/`](gapbs/) | 12 (`<kernel>-<graph>`; 30 with all 5 graphs) | github.com/sbeamer/gapbs | 30 |
| [`spec/`](spec/) | 43 SPEC CPU 2017 rate + speed (36 built) | traquina NAS install (licensed) | 43 |
| [`parsec/`](parsec/) | 13 | PARSEC 3.0 tarball | 13 |
| [`ycsb/`](ycsb/) | 6 (`ycsb-a` ... `ycsb-f`) on Redis | redis.io + YCSB 0.17.0 | 6 |
| [`gpt2/`](gpt2/) | 4 (`gpt2-124M` ... `gpt2-1558M`) | HuggingFace models | 4 |
| [`graph500/`](graph500/) | 1 | Demeter fork | extra |
| [`xsbench/`](xsbench/) | 1 | Demeter fork | extra |
| [`btree/`](btree/) | 1 | Demeter fork | extra |
| [`gups/`](gups/) | 1 | Demeter fork | extra |
| [`liblinear/`](liblinear/) | 1 | Demeter fork | extra |
| [`silo/`](silo/) | 1 | Demeter fork | extra |

With `GAPBS_GRAPHS="kron urand twitter road web"`, the first five folders
are PACT's exact composition (96 workloads); the Demeter ones add 6.

## `workload.sh` interface

For a folder `<name>/`, `workload.sh` defines:

- `list_<name>`: prints its workload names, one per line;
- `cmd_<name> WORKLOAD`: sets
  - `CMD`: the command to measure (an array);
  - `PRELOAD` (optional): a file or directory `collect.sh` loads into the
    page cache on the tier's node before the run;
  - `ATTACH` (optional, server workloads): `collect.sh` then calls
    `${ATTACH}_start NODE` (starts the server bound to `CPUS` and the tier's
    node, sets `SERVER_PID`), counts the server with `perf stat -p` while
    `CMD` (the client) runs, and calls `${ATTACH}_stop`. Only `ycsb/` uses it.

`common.sh` holds what the folders share: `CPUS`/`THREADS` and the Demeter
fork's repository and pinned commit. To add a workload, add a folder with
these three files; `workloads.sh` picks it up.
