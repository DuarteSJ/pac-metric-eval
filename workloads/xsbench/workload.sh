# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# xsbench (interface: workloads/README.md). Source: the Demeter fork's
# workload/xsbench, arguments as Demeter's bench.

XSBENCH_HOME="$WORKLOADS_DIR/xsbench"

list_xsbench() { echo xsbench; }

cmd_xsbench() {
	CMD=("$XSBENCH_HOME/src/XSBench" -m history -G unionized -t "$THREADS" -l 34 -g 25000 -p 10000000)
}
