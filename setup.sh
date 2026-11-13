#!/usr/bin/env bash
# Build GAPBS and generate the paper's bc-kron graph (Kronecker, scale 27,
# degree 16: 134.2M vertices, 2.11B edges, ~18 GB .sg file).
#
#   ./setup.sh                 # SCALE=27 (paper)
#   SCALE=25 ./setup.sh        # ~4.5 GB graph for a quick dry run
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAPBS_DIR="${GAPBS_DIR:-$HERE/gapbs}"
SCALE="${SCALE:-27}"
DEGREE="${DEGREE:-16}"
GRAPH="${GRAPH:-$GAPBS_DIR/graphs/kron${SCALE}.sg}"

if [[ ! -d $GAPBS_DIR ]]; then
	git clone https://github.com/sbeamer/gapbs.git "$GAPBS_DIR"
fi
make -C "$GAPBS_DIR" -j"$(nproc)" bc converter

if [[ -f $GRAPH ]]; then
	echo "graph exists: $GRAPH"
	exit 0
fi
mkdir -p "$(dirname "$GRAPH")"
# Generation peaks well above the final graph size; interleave over the DRAM
# nodes (not CXL) so it is not bound by one node.
echo "generating $GRAPH (g$SCALE k$DEGREE), this takes a while ..."
numactl --interleave=0,1 "$GAPBS_DIR/converter" -g"$SCALE" -k"$DEGREE" -b "$GRAPH"
ls -lh "$GRAPH"
