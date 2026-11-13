#!/usr/bin/env bash
# graph500: source from the Demeter fork (workload/graph500 at DEMETER_REF) into
# src/, then build it there.
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/graph500/workload.sh"

fetch_demeter_workload graph500 "$GRAPH500_HOME/src"
make -C "$GRAPH500_HOME/src" omp-csr/omp-csr
ls -la "$GRAPH500_HOME/src/omp-csr/omp-csr"
