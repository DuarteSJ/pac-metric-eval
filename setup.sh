#!/usr/bin/env bash
# Set up workloads on traquina: runs workloads/<name>/setup.sh for each name
# given, or for every folder with "all". Each folder's README.md says what its
# setup downloads and builds.
#
#   ./setup.sh gapbs spec      # some folders
#   ./setup.sh all             # every folder; a failing one does not stop the rest
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=workloads.sh
source "$HERE/workloads.sh"

[[ $# -gt 0 ]] || { sed -n '2,7p' "$0" >&2; echo "folders: ${SUITES[*]}" >&2; exit 1; }
names=("$@")
[[ $1 == all ]] && names=("${SUITES[@]}")

failed=()
for s in "${names[@]}"; do
	[[ -x $WORKLOADS_DIR/$s/setup.sh ]] || { echo "no workloads/$s/setup.sh" >&2; failed+=("$s"); continue; }
	echo "=== $s"
	"$WORKLOADS_DIR/$s/setup.sh" || failed+=("$s")
done
if [[ ${#failed[@]} -gt 0 ]]; then
	echo "FAILED: ${failed[*]}" >&2
	exit 1
fi
