#!/usr/bin/env bash
# Build the Fig. 2 workloads on traquina.
#
#   ./setup.sh gapbs     GAPBS kernels + the 5 GAP graphs (kron, urand
#                        generated; twitter, road, web downloaded), in the
#                        .sg / .wsg / U.sg forms the runs need. ~200 GB of disk,
#                        hours (downloads + conversion).
#   ./setup.sh parsec    PARSEC 3.0 with native inputs (opt-in; old code, some
#                        packages may not build with a modern gcc).
#
# The demeter group needs nothing here: it uses the binaries the Demeter fork
# builds in ~/demeter-criticality/bin (DEMETER_BIN).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=workloads.sh
source "$HERE/workloads.sh"

setup_gapbs() {
	[[ -d $GAPBS_DIR ]] || git clone https://github.com/sbeamer/gapbs.git "$GAPBS_DIR"
	make -C "$GAPBS_DIR" -j"$(nproc)"
	# GAP's own graph recipes (benchmark/bench.mk). Generation and conversion
	# peak well above the graph size; keep them on the DRAM nodes.
	cd "$GAPBS_DIR"
	numactl --interleave=0,1 make -f benchmark/bench.mk bench-graphs
	ls -lh "$GRAPH_DIR"
}

setup_parsec() {
	local tgz="$HERE/parsec-3.0.tar.gz"
	if [[ ! -d $PARSEC_DIR ]]; then
		[[ -f $tgz ]] || wget -O "$tgz" https://parsec.cs.princeton.edu/download/3.0/parsec-3.0.tar.gz
		tar -xzf "$tgz" -C "$(dirname "$PARSEC_DIR")"
	fi
	# Config "gcc": each package's default parallel model (pthreads; OpenMP for
	# freqmine). parsecmgmt needs its env script; build each package separately so one
	# failure does not stop the rest.
	# shellcheck disable=SC1091
	(cd "$PARSEC_DIR" && source env.sh &&
		for p in $PARSEC_WORKLOADS; do
			parsecmgmt -a build -p "$p" -c gcc > "$HERE/parsec-build-$p.log" 2>&1 &&
				echo "built $p" || echo "FAILED $p (see parsec-build-$p.log)"
		done)
}

case "${1:-}" in
gapbs) setup_gapbs ;;
parsec) setup_parsec ;;
*) echo "usage: $0 gapbs|parsec" >&2; exit 1 ;;
esac
