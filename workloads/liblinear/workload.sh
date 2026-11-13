# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# liblinear (interface: workloads/README.md). Source: the Demeter fork's
# workload/liblinear, arguments as Demeter's bench.

LIBLINEAR_HOME="$WORKLOADS_DIR/liblinear"

list_liblinear() { echo liblinear; }

cmd_liblinear() {
	PRELOAD="$LIBLINEAR_HOME/src/kdda"
	CMD=("$LIBLINEAR_HOME/src/train" -m "$THREADS" -s 2 "$PRELOAD" /dev/null)
}
