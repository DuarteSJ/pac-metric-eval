# shellcheck shell=bash disable=SC2034  # sourced; variables are used by the sourcer
# Workload set for PACT Fig. 2 on traquina (sourced by collect.sh, setup.sh).
#
# PACT's 96 workloads: SPEC CPU 2017 (43, licensed), GAPBS (30), PARSEC (13),
# GPT-2 (4), YCSB A-F (6). Their commands were never published (only names, in
# pact-modeling/skx/dat), so this is our own set, same suites minus SPEC:
#   gapbs     6 GAPBS kernels x GAPBS_GRAPHS (default kron road: 12), GAP
#             benchmark arguments (benchmark/bench.mk) with fewer trials.
#             gapbs-all: all 5 GAP graphs (30, as PACT)
#   demeter   the Demeter artifact's workloads, incl. SPEC 603.bwaves_s
#   parsec    PARSEC 3.0, native inputs, binaries run directly
#   ycsb      YCSB A-F on Redis
#   gpt2      GPT-2 unconditional generation, 4 sizes (gpt2.py)
#   all       gapbs + demeter + parsec + ycsb + gpt2 (42; 29% graph, PACT 31%)
#
# workload_cmd NAME sets:
#   CMD      argv of the measured command
#   PRELOAD  file or directory to load into the page cache on the tier's node
#            first, or empty
#   ATTACH   empty: perf stat runs CMD. Otherwise a server workload:
#            "${ATTACH}_start NODE" starts the server bound to CPUS and NODE
#            and sets SERVER_PID; perf stat -p SERVER_PID counts while CMD
#            (the client) runs; then "${ATTACH}_stop" ends the server.

HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
GAPBS_DIR="${GAPBS_DIR:-$HERE/gapbs}"
GRAPH_DIR="${GRAPH_DIR:-$GAPBS_DIR/benchmark/graphs}"
DEMETER_BIN="${DEMETER_BIN:-$HOME/demeter-criticality/bin}"
PARSEC_DIR="${PARSEC_DIR:-$HERE/parsec-3.0}"
PARSEC_RUN="${PARSEC_RUN:-$HERE/parsec-run}"
REDIS_DIR="${REDIS_DIR:-$HERE/redis}"
YCSB_DIR="${YCSB_DIR:-$HERE/ycsb-0.17.0}"
GPT2_VENV="${GPT2_VENV:-$HERE/venv-gpt2}"
CPUS="${CPUS:-0-7}"
THREADS="${THREADS:-8}"
# YCSB client: other socket-0 cores and DRAM, outside the measured process.
CLIENT_CPUS="${CLIENT_CPUS:-8-23}"
CLIENT_NODE="${CLIENT_NODE:-0}"

GAPBS_KERNELS="bc bfs cc pr sssp tc"
GAPBS_GRAPHS="${GAPBS_GRAPHS:-kron road}"
GAPBS_ALL_GRAPHS="kron urand twitter road web"
DEMETER_WORKLOADS="graph500 xsbench btree gups liblinear bwaves silo"
PARSEC_WORKLOADS="blackscholes bodytrack canneal dedup facesim ferret fluidanimate freqmine raytrace streamcluster swaptions vips x264"
YCSB_WORKLOADS="ycsb-a ycsb-b ycsb-c ycsb-d ycsb-e ycsb-f"
GPT2_WORKLOADS="gpt2-124M gpt2-355M gpt2-774M gpt2-1558M"

# Trial counts: GAP's own (bench.mk) are 16-64 per run, too long for 3 tiers;
# these keep every run to minutes. The metrics are whole-run sums, so the trial
# count only scales them.
GAPBS_TRIALS_bfs=8 GAPBS_TRIALS_sssp=8 GAPBS_TRIALS_pr=2 GAPBS_TRIALS_cc=4
GAPBS_TRIALS_bc=2 GAPBS_TRIALS_tc=1

# YCSB on Redis: YCSB's default ~1 KB records, ~10 GB of data.
YCSB_RECORDS="${YCSB_RECORDS:-10000000}"
YCSB_OPS="${YCSB_OPS:-20000000}"
YCSB_CLIENT_THREADS="${YCSB_CLIENT_THREADS:-16}"
REDIS_PORT="${REDIS_PORT:-6399}"
YCSB_LOG="${YCSB_LOG:-/dev/null}"

# GPT-2: HuggingFace model names by parameter count.
declare -A GPT2_MODEL=([124M]=gpt2 [355M]=gpt2-medium [774M]=gpt2-large [1558M]=gpt2-xl)

# shellcheck disable=SC2086  # the lists are word-split on purpose
workload_group() {
	local k g
	case "$1" in
	gapbs) for k in $GAPBS_KERNELS; do for g in $GAPBS_GRAPHS; do echo "$k-$g"; done; done ;;
	gapbs-all) for k in $GAPBS_KERNELS; do for g in $GAPBS_ALL_GRAPHS; do echo "$k-$g"; done; done ;;
	demeter) printf '%s\n' $DEMETER_WORKLOADS ;;
	parsec) printf '%s\n' $PARSEC_WORKLOADS ;;
	ycsb) printf '%s\n' $YCSB_WORKLOADS ;;
	gpt2) printf '%s\n' $GPT2_WORKLOADS ;;
	all) for g in gapbs demeter parsec ycsb gpt2; do workload_group "$g"; done ;;
	*) echo "unknown group $1 (gapbs, gapbs-all, demeter, parsec, ycsb, gpt2, all)" >&2; return 1 ;;
	esac
}

# ycsb_client load|run LETTER: sets CMD to the YCSB client on CLIENT_CPUS.
ycsb_client() {
	CMD=(numactl --physcpubind="$CLIENT_CPUS" --membind="$CLIENT_NODE"
		"$YCSB_DIR/bin/ycsb.sh" "$1" redis -s -P "$YCSB_DIR/workloads/workload$2"
		-p redis.host=127.0.0.1 -p redis.port="$REDIS_PORT"
		-p recordcount="$YCSB_RECORDS" -p operationcount="$YCSB_OPS"
		-threads "$YCSB_CLIENT_THREADS")
}

# ycsb_start NODE: Redis bound to the measured cores and the tier's node, then
# load the records. Not measured: perf attaches for the run phase only.
ycsb_start() {
	local node=$1 i run_cmd=("${CMD[@]}")
	numactl --physcpubind="$CPUS" --membind="$node" "$REDIS_DIR/src/redis-server" \
		--port "$REDIS_PORT" --save '' --appendonly no > "$YCSB_LOG" 2>&1 &
	SERVER_PID=$!
	for i in $(seq 50); do
		"$REDIS_DIR/src/redis-cli" -p "$REDIS_PORT" ping > /dev/null 2>&1 && break
		sleep 0.2
	done
	ycsb_client load "$YCSB_LETTER"
	"${CMD[@]}" >> "$YCSB_LOG" 2>&1
	CMD=("${run_cmd[@]}")
}

ycsb_stop() {
	"$REDIS_DIR/src/redis-cli" -p "$REDIS_PORT" shutdown nosave > /dev/null 2>&1 ||
		kill "$SERVER_PID" 2> /dev/null || true
	wait "$SERVER_PID" 2> /dev/null || true
}

workload_cmd() {
	local name=$1 kernel graph trials
	PRELOAD="" ATTACH=""
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
	# PARSEC: the package's native run (parsec/native.runconf: run_exec, and
	# run_args with ${NTHREADS}) in the run directory setup.sh prepared. Not
	# through parsecmgmt, which would unpack the inputs inside the measured run.
	blackscholes | bodytrack | canneal | dedup | facesim | ferret | fluidanimate | freqmine | \
		raytrace | streamcluster | swaptions | vips | x264)
		local rd="$PARSEC_RUN/$name" run_exec="" run_args="" args
		local NTHREADS=$THREADS # read by the runconf
		# shellcheck disable=SC1091
		[[ -f $rd/native.runconf ]] && source "$rd/native.runconf"
		read -ra args <<< "$run_args"
		PRELOAD="$rd"
		CMD=(env -C "$rd" "$(cat "$rd/inst" 2> /dev/null || echo "$rd/NOT-SET-UP")/$run_exec" "${args[@]}")
		;;
	ycsb-[a-f])
		YCSB_LETTER=${name#ycsb-}
		ATTACH=ycsb
		ycsb_client run "$YCSB_LETTER"
		;;
	gpt2-*)
		local model=${GPT2_MODEL[${name#gpt2-}]:-}
		[[ -n $model ]] || { echo "unknown GPT-2 size $name" >&2; return 1; }
		CMD=(env HF_HUB_OFFLINE=1 "$GPT2_VENV/bin/python" "$HERE/gpt2.py" --model "$model"
			--threads "$THREADS" --samples 4 --tokens 256)
		;;
	*) echo "unknown workload $name" >&2; return 1 ;;
	esac
}
