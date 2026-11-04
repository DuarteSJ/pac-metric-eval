# shellcheck shell=bash disable=SC2034  # sourced; variables are used by the sourcer
# Workload set for PACT Fig. 2 on traquina (sourced by collect.sh).
#
# PACT's 96 workloads: SPEC CPU 2017 (43, licensed), GAPBS (30), PARSEC (13),
# GPT-2 (4), YCSB A-F (6). Their commands were never published (only names, in
# pact-modeling/skx/dat), so this is our own set:
#   gapbs   the same 30 GAPBS runs (6 kernels x 5 GAP graphs), GAP benchmark
#           arguments (benchmark/bench.mk) with fewer trials
#   demeter the workloads the Demeter artifact ships, incl. SPEC 603.bwaves_s
#   parsec  PARSEC 3.0, native inputs (opt-in, needs setup.sh parsec)
#
# workload_cmd NAME sets CMD (argv) and PRELOAD (file to load into the page
# cache on the target node first, or empty).

GAPBS_DIR="${GAPBS_DIR:-$HOME/pact-fig2/gapbs}"
GRAPH_DIR="${GRAPH_DIR:-$GAPBS_DIR/benchmark/graphs}"
DEMETER_BIN="${DEMETER_BIN:-$HOME/demeter-criticality/bin}"
PARSEC_DIR="${PARSEC_DIR:-$HOME/pact-fig2/parsec-3.0}"
THREADS="${THREADS:-8}"

GAPBS_KERNELS="bc bfs cc pr sssp tc"
GAPBS_GRAPHS="kron urand twitter road web"
DEMETER_WORKLOADS="graph500 xsbench btree gups liblinear bwaves silo"
PARSEC_WORKLOADS="blackscholes bodytrack canneal dedup facesim ferret fluidanimate freqmine raytrace streamcluster swaptions vips x264"

# Trial counts: GAP's own (bench.mk) are 16-64 per run, too long for 3 tiers x
# 30 runs; these keep every run to minutes. The metrics are whole-run sums, so
# the trial count only scales them.
GAPBS_TRIALS_bfs=8 GAPBS_TRIALS_sssp=8 GAPBS_TRIALS_pr=2 GAPBS_TRIALS_cc=4
GAPBS_TRIALS_bc=2 GAPBS_TRIALS_tc=1

# shellcheck disable=SC2086  # the lists are word-split on purpose
workload_group() {
	case "$1" in
	gapbs) for k in $GAPBS_KERNELS; do for g in $GAPBS_GRAPHS; do echo "$k-$g"; done; done ;;
	demeter) printf '%s\n' $DEMETER_WORKLOADS ;;
	parsec) printf '%s\n' $PARSEC_WORKLOADS ;;
	all) workload_group gapbs; workload_group demeter ;;
	*) echo "unknown group $1 (gapbs, demeter, parsec, all)" >&2; return 1 ;;
	esac
}

workload_cmd() {
	local name=$1 kernel graph trials
	PRELOAD=""
	case "$name" in
	bc-* | bfs-* | cc-* | pr-* | sssp-* | tc-*)
		kernel=${name%%-*} graph=${name#*-}
		local n="GAPBS_TRIALS_$kernel"
		trials=${!n}
		# Inputs and arguments as GAP's benchmark/bench.mk: sssp on the
		# weighted graph, tc on the undirected one.
		case $kernel in
		bfs) PRELOAD="$GRAPH_DIR/$graph.sg"; CMD=("$GAPBS_DIR/bfs" -f "$PRELOAD" -n"$trials") ;;
		pr) PRELOAD="$GRAPH_DIR/$graph.sg"; CMD=("$GAPBS_DIR/pr" -f "$PRELOAD" -i1000 -t1e-4 -n"$trials") ;;
		cc) PRELOAD="$GRAPH_DIR/$graph.sg"; CMD=("$GAPBS_DIR/cc" -f "$PRELOAD" -n"$trials") ;;
		bc) PRELOAD="$GRAPH_DIR/$graph.sg"; CMD=("$GAPBS_DIR/bc" -f "$PRELOAD" -i4 -n"$trials") ;;
		sssp)
			PRELOAD="$GRAPH_DIR/$graph.wsg"
			local delta=2
			[[ $graph == road ]] && delta=50000
			CMD=("$GAPBS_DIR/sssp" -f "$PRELOAD" -n"$trials" -d"$delta")
			;;
		tc) PRELOAD="$GRAPH_DIR/${graph}U.sg"; CMD=("$GAPBS_DIR/tc" -f "$PRELOAD" -n"$trials") ;;
		esac
		;;
	# Demeter artifact workloads, arguments as its bench (and as tested in
	# pact-fig3's earlier runs on traquina).
	graph500) CMD=("$DEMETER_BIN/omp-csr" -V -s 24 -e 24 -n 10) ;;
	xsbench) CMD=("$DEMETER_BIN/XSBench" -m history -G unionized -t "$THREADS" -l 34 -g 25000 -p 10000000) ;;
	btree) CMD=("$DEMETER_BIN/bench_btree_mt" -- -n 200000000 -l 2000000000) ;;
	gups) CMD=("$DEMETER_BIN/gups" --thread="$THREADS" --update=800000000 --len=15023996928
		--granularity=8 --report=1000 hotset --hot=1065353216 --weight=9 --reverse) ;;
	liblinear) PRELOAD="$DEMETER_BIN/kdda"; CMD=("$DEMETER_BIN/train" -m "$THREADS" -s 2 "$PRELOAD" /dev/null) ;;
	bwaves) CMD=("$DEMETER_BIN/bind-stdin" "$DEMETER_BIN/bwaves_s.in" "$DEMETER_BIN/bwaves_s") ;;
	silo) CMD=("$DEMETER_BIN/dbtest" --verbose --slow-exit --parallel-loading --bench=ycsb
		--num-threads="$THREADS" --scale-factor=55000 --ops-per-worker=10000000) ;;
	# PARSEC through its own launcher (it runs the benchmark as a child, which
	# perf stat and numactl both follow).
	blackscholes | bodytrack | canneal | dedup | facesim | ferret | fluidanimate | freqmine | \
		raytrace | streamcluster | swaptions | vips | x264)
		CMD=("$PARSEC_DIR/bin/parsecmgmt" -a run -p "$name" -c gcc -i native -n "$THREADS")
		;;
	*) echo "unknown workload $name" >&2; return 1 ;;
	esac
}
