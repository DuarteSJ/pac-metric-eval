# shellcheck shell=bash disable=SC2034  # sourced; variables are used by the sourcer
# Shared by every workloads/<name>/ folder (see workloads/README.md).

WORKLOADS_DIR="${WORKLOADS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Measured cores and threads (socket 0), as PACT (OMP_NUM_THREADS=8).
CPUS="${CPUS:-0-7}"
THREADS="${THREADS:-8}"

# The Demeter fork's workloads (graph500, xsbench, btree, gups, liblinear,
# silo) are built from its workload/ tree, pinned for reproducibility.
DEMETER_REPO="${DEMETER_REPO:-https://github.com/DuarteSJ/demeter-criticality.git}"
DEMETER_REF="${DEMETER_REF:-70fb90a4602377a13036755990453fcfdeb79590}"

# fetch_demeter_workload NAME DEST: copy workload/NAME of the Demeter fork at
# DEMETER_REF into DEST (a sparse, shallow fetch of just that directory).
fetch_demeter_workload() {
	local name=$1 dest=$2 tmp
	[[ -d $dest ]] && return 0
	tmp=$(mktemp -d)
	git -C "$tmp" init -q
	git -C "$tmp" remote add origin "$DEMETER_REPO"
	git -C "$tmp" sparse-checkout set "workload/$name"
	git -C "$tmp" fetch -q --depth 1 --filter=blob:none origin "$DEMETER_REF"
	git -C "$tmp" checkout -q FETCH_HEAD
	mv "$tmp/workload/$name" "$dest"
	rm -rf "$tmp"
	echo "fetched workload/$name at ${DEMETER_REF:0:7} -> $dest"
}
