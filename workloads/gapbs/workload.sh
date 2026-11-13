# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# GAPBS kernels on the GAP benchmark graphs (interface: workloads/README.md).

GAPBS_HOME="$WORKLOADS_DIR/gapbs"
GAPBS_SRC="$GAPBS_HOME/src"
GAPBS_GRAPHS_DIR="$GAPBS_HOME/graphs"

GAPBS_KERNELS="bc bfs cc pr sssp tc"
# Default kron + road (12 runs). All 5 GAP graphs (30 runs, PACT's set):
#   GAPBS_GRAPHS="kron urand twitter road web"
GAPBS_GRAPHS="${GAPBS_GRAPHS:-kron road}"

# Trials per run: GAP's own (benchmark/bench.mk) are 16-64, too long for 3
# tiers. The metrics are whole-run sums, so the count only scales them.
declare -A GAPBS_TRIALS=([bfs]=8 [sssp]=8 [pr]=2 [cc]=4 [bc]=2 [tc]=1)

list_gapbs() {
	local k g
	for k in $GAPBS_KERNELS; do
		for g in $GAPBS_GRAPHS; do echo "$k-$g"; done
	done
}

# Inputs and arguments as GAP's benchmark/bench.mk: sssp on the weighted graph
# (.wsg), tc on the undirected one (U.sg).
cmd_gapbs() {
	local kernel=${1%%-*} graph=${1#*-}
	local n=${GAPBS_TRIALS[$kernel]} g="$GAPBS_GRAPHS_DIR/$graph"
	case $kernel in
	bfs) PRELOAD="$g.sg"; CMD=("$GAPBS_SRC/bfs" -f "$PRELOAD" -n"$n") ;;
	pr) PRELOAD="$g.sg"; CMD=("$GAPBS_SRC/pr" -f "$PRELOAD" -i1000 -t1e-4 -n"$n") ;;
	cc) PRELOAD="$g.sg"; CMD=("$GAPBS_SRC/cc" -f "$PRELOAD" -n"$n") ;;
	bc) PRELOAD="$g.sg"; CMD=("$GAPBS_SRC/bc" -f "$PRELOAD" -i4 -n"$n") ;;
	sssp)
		local delta=2
		[[ $graph == road ]] && delta=50000
		PRELOAD="$g.wsg"; CMD=("$GAPBS_SRC/sssp" -f "$PRELOAD" -n"$n" -d"$delta")
		;;
	tc) PRELOAD="${g}U.sg"; CMD=("$GAPBS_SRC/tc" -f "$PRELOAD" -n"$n") ;;
	*) return 1 ;;
	esac
}
