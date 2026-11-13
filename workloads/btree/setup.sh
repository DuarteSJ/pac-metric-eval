#!/usr/bin/env bash
# btree: source from the Demeter fork (workload/btree at DEMETER_REF) into
# src/, then build it there.
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/btree/workload.sh"

fetch_demeter_workload btree "$BTREE_HOME/src"
make -C "$BTREE_HOME/src"
ls -la "$BTREE_HOME/src/bench_btree_mt"
