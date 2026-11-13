# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# btree (interface: workloads/README.md). Source: the Demeter fork's
# workload/btree, arguments as Demeter's bench.

BTREE_HOME="$WORKLOADS_DIR/btree"

list_btree() { echo btree; }

cmd_btree() {
	CMD=("$BTREE_HOME/src/bench_btree_mt" -- -n 200000000 -l 2000000000)
}
