# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# silo (interface: workloads/README.md). Source: the Demeter fork's
# workload/silo, arguments as Demeter's bench.

SILO_HOME="$WORKLOADS_DIR/silo"

list_silo() { echo silo; }

cmd_silo() {
	CMD=("$SILO_HOME/src/out-perf.masstree/benchmarks/dbtest" --verbose --slow-exit --parallel-loading \
		--bench=ycsb --num-threads="$THREADS" --scale-factor=55000 --ops-per-worker=10000000)
}
