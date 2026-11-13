# shellcheck shell=bash
# Loads every workloads/<name>/workload.sh (see workloads/README.md). Sourced
# by collect.sh and setup.sh.
#
#   workload_group NAME   the workloads of folder NAME, or of all folders
#                         for "all"
#   workload_cmd WORKLOAD sets CMD, PRELOAD and ATTACH for one workload

HERE="${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
WORKLOADS_DIR="$HERE/workloads"
# shellcheck source=workloads/common.sh
source "$WORKLOADS_DIR/common.sh"

SUITES=()
declare -A WORKLOAD_SUITE # workload name -> folder
for f in "$WORKLOADS_DIR"/*/workload.sh; do
	suite=$(basename "$(dirname "$f")")
	# shellcheck disable=SC1090
	source "$f"
	SUITES+=("$suite")
	while read -r w; do WORKLOAD_SUITE[$w]=$suite; done < <("list_$suite")
done
unset f suite w

workload_group() {
	local s
	if [[ $1 == all ]]; then
		for s in "${SUITES[@]}"; do "list_$s"; done
	elif [[ " ${SUITES[*]} " == *" $1 "* ]]; then
		"list_$1"
	else
		echo "unknown group $1 (all, ${SUITES[*]})" >&2
		return 1
	fi
}

workload_cmd() {
	local suite=${WORKLOAD_SUITE[$1]:-}
	[[ -n $suite ]] || { echo "unknown workload $1" >&2; return 1; }
	# shellcheck disable=SC2034  # set for the caller (collect.sh)
	PRELOAD="" ATTACH=""
	"cmd_$suite" "$1"
}
