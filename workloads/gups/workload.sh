# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# gups (interface: workloads/README.md). Source: the Demeter fork's
# workload/gups, arguments as Demeter's bench.

GUPS_HOME="$WORKLOADS_DIR/gups"

list_gups() { echo gups; }

cmd_gups() {
	CMD=("$GUPS_HOME/src/target/release/gups" --thread="$THREADS" --update=800000000 --len=15023996928 \
		--granularity=8 --report=1000 hotset --hot=1065353216 --weight=9 --reverse)
}
