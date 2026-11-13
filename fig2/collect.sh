#!/usr/bin/env bash
# Collect PACT Fig. 2 counters on traquina: every workload x every tier, one
# whole-run perf stat each, then aggregate into results/<tag>/models.csv.
#
#   ./collect.sh all                   # every workload folder (workloads/)
#   ./collect.sh gapbs spec            # some folders ...
#   ./collect.sh bc-kron 505.mcf_r     # ... or workload names
#   DRY=1 ./collect.sh all             # print the commands only
#
# Knobs (env):
#   TIERS    index:label:node, in PACT's order (1:dram:0 2:numa:1 3:cxl:2)
#   CPUS     workload cores, socket 0 (0-7); THREADS (8), as PACT
#   TIMEOUT  per run (60m); TAG results dir (date)
#   per-folder knobs (GAPBS_GRAPHS, YCSB_RECORDS, ...): workloads/*/workload.sh
# Existing raw files are skipped, so an interrupted collection resumes.
set -euo pipefail
export LC_ALL=C # perf prints decimal commas under e.g. pt_PT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../workloads.sh
source "$HERE/../workloads.sh"

TIERS="${TIERS:-1:dram:0 2:numa:1 3:cxl:2}"
TIMEOUT="${TIMEOUT:-60m}"
TAG="${TAG:-$(date +%Y%m%d)}"
OUT="$HERE/results/$TAG"
DRY="${DRY:-0}"

# PACT's four counters (pact-modeling/run-models.sh) plus OFFCORE_REQUESTS
# .DEMAND_DATA_RD, which gives the offcore_load_latency column the reference
# data has (= outstanding / requests, in cycles), and the L3-miss MLP pair and
# cycles, for testing other MLP estimates on the same runs. Each T1/T2 pair is a
# group so both are counted over the same time slices.
EVENTS=(
	-e cycle_activity.stalls_l3_miss
	-e mem_load_retired.l3_miss
	-e '{offcore_requests_outstanding.demand_data_rd,offcore_requests_outstanding.cycles_with_demand_data_rd,offcore_requests.demand_data_rd}'
	-e '{offcore_requests_outstanding.l3_miss_demand_data_rd,offcore_requests_outstanding.cycles_with_l3_miss_demand_data_rd}'
	-e cycles -e instructions
)

[[ $# -gt 0 ]] || { sed -n '2,13p' "$0"; exit 1; }
names=()
for a in "$@"; do
	if group=$(workload_group "$a" 2>/dev/null); then
		mapfile -t -O "${#names[@]}" names <<< "$group"
	else
		names+=("$a")
	fi
done

if [[ $DRY != 1 ]]; then
	command -v vmtouch > /dev/null || { echo "needs vmtouch (apt install vmtouch)" >&2; exit 1; }
	mkdir -p "$OUT/raw"
	{
		echo "date    $(date -Is)"
		echo "host    $(hostname) $(uname -r)"
		echo "cpu     $(lscpu | sed -n 's/^Model name: *//p')"
		echo "cpus    $CPUS  threads $THREADS"
		echo "tiers   $TIERS"
		echo "events  ${EVENTS[*]}"
		echo
		numactl -H
	} > "$OUT/meta.txt"
fi

run() {
	if [[ $DRY == 1 ]]; then echo "    $*"; else "$@"; fi
}

for name in "${names[@]}"; do
	workload_cmd "$name"
	for t in $TIERS; do
		IFS=: read -r idx label node <<< "$t"
		raw="$OUT/raw/${name}_$idx.csv"
		if [[ -s $raw ]]; then
			echo "skip $name/$label (have $raw)"
			continue
		fi
		echo "== $name / $label (node $node)"
		# Page cache of the input on the tier's node: evict, then load under
		# the same binding (as PACT's vmtouch preload).
		if [[ -n $PRELOAD ]]; then
			run vmtouch -q -e "$PRELOAD"
			run numactl --cpunodebind=0 --membind="$node" vmtouch -q -t -m 64G "$PRELOAD"
		fi
		# perf as root (paranoid 4); the workload as the invoking user.
		if [[ -z $ATTACH ]]; then
			perf_cmd=(sudo LC_ALL=C perf stat '-x,' -o "$raw.tmp" "${EVENTS[@]}" --
				sudo -u "$USER" env OMP_NUM_THREADS="$THREADS" OMP_PROC_BIND=true OMP_PLACES=cores
				timeout "$TIMEOUT" numactl --physcpubind="$CPUS" --membind="$node" "${CMD[@]}")
		else
			# Server workload: count only the server, bound to CPUS and the
			# tier, while the client (CMD, on CLIENT_CPUS) runs.
			perf_cmd=(sudo LC_ALL=C perf stat '-x,' -o "$raw.tmp" "${EVENTS[@]}" -p @SERVER_PID@ --
				sudo -u "$USER" timeout "$TIMEOUT" "${CMD[@]}")
		fi
		if [[ $DRY == 1 ]]; then
			[[ -n $ATTACH ]] && echo "    ${ATTACH}_start $node"
			echo "    ${perf_cmd[*]}"
			[[ -n $ATTACH ]] && echo "    ${ATTACH}_stop"
			continue
		fi
		rc=0
		if [[ -n $ATTACH ]]; then
			# shellcheck disable=SC2034  # read by the workload folder's _start
			YCSB_LOG="$OUT/raw/${name}_$idx.server.log"
			trap '"${ATTACH}_stop"' EXIT
			"${ATTACH}_start" "$node"
			perf_cmd=("${perf_cmd[@]/@SERVER_PID@/$SERVER_PID}")
		fi
		"${perf_cmd[@]}" > "$OUT/raw/${name}_$idx.log" 2>&1 || rc=$?
		if [[ -n $ATTACH ]]; then
			"${ATTACH}_stop"
			trap - EXIT
		fi
		if [[ $rc -eq 0 ]]; then
			mv "$raw.tmp" "$raw"
		else
			echo "   FAILED rc=$rc (see $OUT/raw/${name}_$idx.log)"
			mv "$raw.tmp" "$raw.failed" 2> /dev/null || true
		fi
	done
done

[[ $DRY == 1 ]] || python3 "$HERE/aggregate.py" "$OUT"
