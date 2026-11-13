#!/usr/bin/env bash
# gups: source from the Demeter fork (workload/gups at DEMETER_REF) into
# src/, then build it there.
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/gups/workload.sh"

fetch_demeter_workload gups "$GUPS_HOME/src"
command -v cargo > /dev/null || { echo "gups needs Rust: curl https://sh.rustup.rs -sSf | sh" >&2; exit 1; }
(cd "$GUPS_HOME/src" && cargo build --release)
ls -la "$GUPS_HOME/src/target/release/gups"
