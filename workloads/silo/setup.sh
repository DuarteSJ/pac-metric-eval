#!/usr/bin/env bash
# silo: source from the Demeter fork (workload/silo at DEMETER_REF) into
# src/, then build it there.
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/silo/workload.sh"

fetch_demeter_workload silo "$SILO_HOME/src"
make -C "$SILO_HOME/src" dbtest
ls -la "$SILO_HOME/src/out-perf.masstree/benchmarks/dbtest"
