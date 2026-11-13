#!/usr/bin/env bash
# xsbench: source from the Demeter fork (workload/xsbench at DEMETER_REF) into
# src/, then build it there.
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/xsbench/workload.sh"

fetch_demeter_workload xsbench "$XSBENCH_HOME/src"
make -C "$XSBENCH_HOME/src"
ls -la "$XSBENCH_HOME/src/XSBench"
