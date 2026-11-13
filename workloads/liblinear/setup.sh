#!/usr/bin/env bash
# liblinear: source from the Demeter fork (workload/liblinear at DEMETER_REF) into
# src/, then build it there.
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/liblinear/workload.sh"

fetch_demeter_workload liblinear "$LIBLINEAR_HOME/src"
make -C "$LIBLINEAR_HOME/src"  # also downloads kdda (KDD Cup 2010, ~2.5 GB compressed)
ls -la "$LIBLINEAR_HOME/src/train"
