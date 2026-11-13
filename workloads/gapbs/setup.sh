#!/usr/bin/env bash
# GAPBS: clone + build into src/, and the graphs of GAPBS_GRAPHS into graphs/
# with GAP's own recipes (src/benchmark/bench.mk). kron is generated (or linked
# from ~/pact-fig3 if there), road downloaded; the others (urand generated,
# twitter and web downloaded) only if listed. All 5: ~200 GB, hours.
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/gapbs/workload.sh"

[[ -d $GAPBS_SRC ]] || git clone https://github.com/sbeamer/gapbs.git "$GAPBS_SRC"
make -C "$GAPBS_SRC" -j"$(nproc)"

# bench.mk writes to src/benchmark/graphs; point that at graphs/.
mkdir -p "$GAPBS_GRAPHS_DIR"
if [[ ! -L $GAPBS_SRC/benchmark/graphs ]]; then
	rm -rf "$GAPBS_SRC/benchmark/graphs"
	ln -s "$GAPBS_GRAPHS_DIR" "$GAPBS_SRC/benchmark/graphs"
fi

# pact-fig3 generates the same kron graph (GAP's -g27 -k16).
fig3_kron="$HOME/pact-fig3/gapbs/graphs/kron27.sg"
if [[ $GAPBS_GRAPHS == *kron* && -f $fig3_kron && ! -e $GAPBS_GRAPHS_DIR/kron.sg ]]; then
	ln -s "$fig3_kron" "$GAPBS_GRAPHS_DIR/kron.sg"
fi

# Graphs already there are marked old (make -o): make would otherwise remake
# them as older than the freshly built converter (e.g. overwrite the linked
# kron). Generation peaks well above the graph size; keep it on DRAM.
targets=() olds=()
for g in $GAPBS_GRAPHS; do
	for t in "$g.sg" "$g.wsg" "${g}U.sg"; do
		if [[ -e $GAPBS_GRAPHS_DIR/$t ]]; then
			olds+=(-o "benchmark/graphs/$t")
		else
			targets+=("benchmark/graphs/$t")
		fi
	done
done
if [[ ${#targets[@]} -gt 0 ]]; then
	mkdir -p "$GAPBS_GRAPHS_DIR/raw"
	(cd "$GAPBS_SRC" && numactl --interleave=0,1 make -f benchmark/bench.mk "${olds[@]}" "${targets[@]}")
fi
ls -lh "$GAPBS_GRAPHS_DIR"
