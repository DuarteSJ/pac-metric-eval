# pac-metric-eval

Evaluating per-access criticality (PAC) metrics on traquina (Emerald Rapids +
CXL), to choose the one to implement in the thesis's Demeter fork
([DuarteSJ/demeter-criticality](https://github.com/DuarteSJ/demeter-criticality),
branch `pac-metric`).

PACT (ASPLOS '26) estimates a page's criticality from the stall cycles the
slow tier causes, `S = k * N_slow / MLP`, with the MLP from CHA/TOR uncore
counters. Inside a VM those counters are not available, so Demeter needs
another MLP (or stall) estimate. This repo reproduces PACT's evidence for the
model on this hardware and tests the candidate metrics against it, on bare
metal.

| folder | what | question |
|---|---|---|
| [`fig2/`](fig2/) | PACT Fig. 2: per workload and tier, LLC-stalls vs LLC-misses / MLP | does `k * misses / MLP` predict stalls, with one k per tier, for each candidate MLP? |
| [`fig3/`](fig3/) | PACT Fig. 3: MLP over time for bc-kron (TOR-MLP, L2MLP, BW x latency) | do the MLP estimates track each other within 20 ms windows? |
| [`workloads/`](workloads/) | the workloads, one folder per suite (shared by both) | |

## Setup (traquina)

```sh
sudo apt install vmtouch default-jre-headless   # once (Java: YCSB client)
./setup.sh all              # every workload folder, or some: ./setup.sh gapbs spec
```

Then see each figure's README: `fig2/collect.sh` runs the workloads on every
tier, `fig3/run.sh` profiles bc-kron.

## Layout

```
setup.sh          set up workload folders (runs workloads/<name>/setup.sh)
workloads.sh      loads every workloads/<name>/workload.sh
workloads/        README.md, common.sh, one folder per suite
fig2/             collect.sh, aggregate.py, fig2.py, pact-modeling/ (PACT's code + data)
fig3/             run.sh, plot.py
```

History: `fig2/` and `fig3/` were the separate repos `pact-fig2` and
`pact-fig3`, merged here with their history.
