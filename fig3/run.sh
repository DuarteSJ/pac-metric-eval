#!/usr/bin/env bash
# Profile bc-kron for PACT Fig. 3 on traquina (2x Xeon Gold 6530, Emerald
# Rapids, two CXL Type-3 expanders as CPU-less nodes 2 and 3): per-interval
# L2MLP, TOR-MLP and the Bandwidth x Latency / 64B approximation, with all
# workload memory on the slow tier.
#
#   ./run.sh                 # slow tier = CXL (node 2)
#   TIER=numa ./run.sh       # slow tier = remote-socket DDR (node 1)
#
# Knobs (env):
#   TIER        cxl | numa                                (cxl)
#   CPUS        workload cores, physical, socket 0        (0-7)
#   THREADS     OMP threads                               (8)
#   INTERVAL_MS perf sampling interval; PACT uses 20 ms   (20)
#   GRAPH       .sg graph   (../workloads/gapbs/graphs/kron.sg: GAP kron, -g27 -k16)
#   BC_ARGS     bc arguments                              (-i4 -n4)
#   TIMEOUT     workload timeout                          (30m)
#   TAG         run directory prefix                      ($TIER)
#
# Needs sudo for perf (system-wide uncore).
set -euo pipefail
# perf prints decimal commas under e.g. pt_PT, which breaks -x, output.
export LC_ALL=C

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAPBS_DIR="${GAPBS_DIR:-$HERE/../workloads/gapbs/src}"
GRAPH="${GRAPH:-$HERE/../workloads/gapbs/graphs/kron.sg}"
TIER="${TIER:-cxl}"
CPUS="${CPUS:-0-7}"
THREADS="${THREADS:-8}"
INTERVAL_MS="${INTERVAL_MS:-20}"
BC_ARGS="${BC_ARGS:--i4 -n4}"
TIMEOUT="${TIMEOUT:-30m}"
TAG="${TAG:-$TIER}"
OUT="${OUT:-$HERE/runs/$TAG-$(date +%Y%m%d-%H%M%S)}"
CPU_SOCKET=0

[[ -x $GAPBS_DIR/bc ]] || { echo "no $GAPBS_DIR/bc, run ../setup.sh gapbs" >&2; exit 1; }
[[ -f $GRAPH ]] || { echo "no graph $GRAPH, run ../setup.sh gapbs" >&2; exit 1; }

# --- slow tier ----------------------------------------------------------------
# TOR umask (incl. umask_ext) selects LLC-miss demand reads to that tier:
#   UNC_CHA_TOR_*.IA_MISS_DRD_CXL_ACC   0x10c8178201  (counts Type-3 memory here;
#                                                      _CXL_EXP_LOCAL stays 0)
#   UNC_CHA_TOR_*.IA_MISS_DRD_REMOTE    0xc8177e01
# Slow-tier bandwidth (all traffic incl. prefetch and writebacks):
#   cxl:  host CXL.mem link, UNC_CXLCM_RXC_PACK_BUF_INSERTS.MEM_DATA = one per
#         64B line read, UNC_CXLCM_TXC_PACK_BUF_INSERTS.MEM_DATA = one per 16B
#         slot written (checked against a 4 GB read/zero sweep). Counted on S0.
#   numa: socket-1 DRAM, UNC_M_CAS_COUNT.RD / .WR, 64B each.
case $TIER in
cxl)
	MEMNODE=2
	TOR_UMASK=0x10c8178201
	BW_SOCKET=0
	BW_RD="uncore_cxlcm/event=0x41,umask=0x10,name=bw_rd/"
	BW_WR="uncore_cxlcm/event=0x02,umask=0x10,name=bw_wr/"
	RD_BYTES=64 WR_BYTES=16
	;;
numa)
	MEMNODE=1
	TOR_UMASK=0xc8177e01
	BW_SOCKET=1
	BW_RD="uncore_imc/event=0x05,umask=0xcf,name=bw_rd/"
	BW_WR="uncore_imc/event=0x05,umask=0xf0,name=bw_wr/"
	RD_BYTES=64 WR_BYTES=64
	;;
*) echo "TIER must be cxl or numa" >&2; exit 1 ;;
esac

# --- events -------------------------------------------------------------------
# TOR-MLP, Table 1 / Alg. 1 of the paper, summed over the CPU socket's CHAs:
#   T1 = TOR_OCCUPANCY (0x36), pinned to counter 0 of each CHA
#   T2 = COUNTER0_OCCUPANCY (0x1f) thresh=1: cycles with T1 >= 1. A second 0x36
#        with thresh=1 would also need counter 0 and get multiplexed.
#   TOR_INSERTS (0x35) gives latency = T1 / inserts in CHA cycles.
# L2MLP, the paper's [7] (Info_Memory_Latency_Load_L2_MLP, SKX definition):
#   OFFCORE_REQUESTS_OUTSTANDING.DEMAND_DATA_RD / .CYCLES_WITH_DEMAND_DATA_RD
#   (umask 0x01, demand loads only).
# Also recorded: the EMR definition of the same-named Intel metric, DATA_RD /
#   CYCLES_WITH_DATA_RD (umask 0x08), which adds L2 prefetches.
# Each T1/T2 pair is a perf group, so both see the same time slices.
EVENTS=(
	"uncore_cha/event=0x36,umask=$TOR_UMASK,name=tor_occ/"
	"uncore_cha/event=0x1f,thresh=1,name=tor_cyc/"
	"uncore_cha/event=0x35,umask=$TOR_UMASK,name=tor_ins/"
	"uncore_cha/event=0x01,name=cha_clk/"
	"$BW_RD"
	"$BW_WR"
	"{cpu/event=0x20,umask=0x01,name=oro_demand_rd/,cpu/event=0x20,umask=0x01,cmask=1,name=oro_cyc_demand_rd/}"
	"{cpu/event=0x20,umask=0x08,name=oro_data_rd/,cpu/event=0x20,umask=0x08,cmask=1,name=oro_cyc_data_rd/}"
)
EV=$(IFS=,; echo "${EVENTS[*]}")

# Count on the workload CPUs plus each socket's uncore reader CPU (CHA cpumask)
# only: core events on all 128 CPUs make perf take ~45 ms per 20 ms interval.
expand() {
	local p parts
	IFS=, read -ra parts <<< "$1"
	for p in "${parts[@]}"; do
		if [[ $p == *-* ]]; then seq "${p%-*}" "${p#*-}"; else echo "$p"; fi
	done
}
PERF_CPUS=$({ expand "$CPUS"; expand "$(cat /sys/bus/event_source/devices/uncore_cha_0/cpumask)"; } | sort -nu | paste -sd,)

mkdir -p "$OUT"
{
	echo "date        $(date -Is)"
	echo "host        $(hostname) $(uname -r)"
	echo "cpu         $(lscpu | sed -n 's/^Model name: *//p')"
	echo "tier        $TIER"
	echo "memnode     $MEMNODE"
	echo "cpus        $CPUS"
	echo "perf_cpus   $PERF_CPUS"
	echo "cpu_socket  $CPU_SOCKET"
	echo "bw_socket   $BW_SOCKET"
	echo "rd_bytes    $RD_BYTES"
	echo "wr_bytes    $WR_BYTES"
	# uncore_cha_N are per-socket box indices, so this is CHAs per socket.
	echo "nr_cha      $(find /sys/bus/event_source/devices -maxdepth 1 -name 'uncore_cha_*' | wc -l)"
	echo "graph       $GRAPH"
	echo "bc_args     $BC_ARGS"
	echo "threads     $THREADS"
	echo "interval_ms $INTERVAL_MS"
	echo "thp         $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
	echo "events      $EV"
	echo
	numactl -H
} > "$OUT/meta.txt"

# Snapshot placement once the graph is loaded: everything should be on MEMNODE.
(
	sleep 30
	pid=$(pgrep -n -x bc || true)
	[[ -n $pid ]] && numastat -p "$pid" > "$OUT/numastat.txt" 2>&1
) &

echo "profiling bc-kron, slow tier $TIER (node $MEMNODE) -> $OUT"
# perf runs as root (uncore); the workload runs as the invoking user.
# perf -I timestamps start at workload exec.
# shellcheck disable=SC2086
sudo LC_ALL=C perf stat -C "$PERF_CPUS" --per-socket -I "$INTERVAL_MS" -x, -o "$OUT/perf.csv" -e "$EV" -- \
	sudo -u "$USER" env OMP_NUM_THREADS="$THREADS" OMP_PROC_BIND=true OMP_PLACES=cores \
	timeout "$TIMEOUT" numactl --physcpubind="$CPUS" --membind="$MEMNODE" \
	"$GAPBS_DIR/bc" -f "$GRAPH" $BC_ARGS 2>&1 | tee "$OUT/bc.log"

wait
echo "done: $OUT"
echo "plot: python3 $HERE/plot.py $OUT"
