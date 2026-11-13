# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# graph500 (interface: workloads/README.md). Source: the Demeter fork's
# workload/graph500, arguments as Demeter's bench.

GRAPH500_HOME="$WORKLOADS_DIR/graph500"

list_graph500() { echo graph500; }

cmd_graph500() {
	CMD=("$GRAPH500_HOME/src/omp-csr/omp-csr" -V -s 24 -e 24 -n 10)
}
