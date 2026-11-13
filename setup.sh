#!/usr/bin/env bash
# Build the Fig. 2 workloads on traquina (paths: workloads.sh).
#
#   ./setup.sh gapbs     GAPBS kernels + the graphs of GAPBS_GRAPHS (default
#                        kron road; GAPBS_GRAPHS="kron urand twitter road web"
#                        for gapbs-all) in the .sg / .wsg / U.sg forms the runs
#                        need, with GAP's own recipes. kron is generated (or
#                        linked from ~/pact-fig3 if there), road downloaded.
#   ./setup.sh parsec    PARSEC 3.0, built per package, plus a run directory
#                        per package with its native input unpacked.
#   ./setup.sh ycsb      Redis (built from source) and the YCSB Redis client
#                        (needs Java: apt install default-jre-headless).
#   ./setup.sh gpt2      Python venv with PyTorch (CPU) + transformers and the
#                        4 GPT-2 models.
#   ./setup.sh all       all of the above.
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
	mkdir -p "$GRAPH_DIR"
	# pact-fig3 generated the same kron graph (GAP's -g27 -k16).
	local fig3_kron="$HOME/pact-fig3/gapbs/graphs/kron27.sg"
	if [[ $GAPBS_GRAPHS == *kron* && -f $fig3_kron && ! -e $GRAPH_DIR/kron.sg ]]; then
		ln -s "$fig3_kron" "$GRAPH_DIR/kron.sg"
	fi
	# GAP's recipes (benchmark/bench.mk), only for the graphs used. Generation
	# and conversion peak well above the graph size; keep them on DRAM.
	# Graphs already there are marked old (-o): make would otherwise remake
	# them as older than the freshly built converter, e.g. overwrite the
	# linked fig3 kron.
	local g t targets=() olds=()
	for g in $GAPBS_GRAPHS; do
		for t in "$g.sg" "$g.wsg" "${g}U.sg"; do
			if [[ -e $GRAPH_DIR/$t ]]; then
				olds+=(-o "benchmark/graphs/$t")
			else
				targets+=("benchmark/graphs/$t")
			fi
		done
	done
	if [[ ${#targets[@]} -gt 0 ]]; then
		(cd "$GAPBS_DIR" && mkdir -p benchmark/graphs/raw &&
			numactl --interleave=0,1 make -f benchmark/bench.mk "${olds[@]}" "${targets[@]}")
	fi
	ls -lh "$GRAPH_DIR"
}

setup_parsec() {
	local tgz="$HERE/parsec-3.0.tar.gz" p pkg inst rd
	if [[ ! -d $PARSEC_DIR ]]; then
		[[ -f $tgz ]] || wget -O "$tgz" https://parsec.cs.princeton.edu/download/3.0/parsec-3.0.tar.gz
		tar -xzf "$tgz" -C "$(dirname "$PARSEC_DIR")"
	fi
	# Config "gcc": each package's default parallel model (pthreads; OpenMP for
	# freqmine). Built one by one so one failure does not stop the rest.
	for p in $PARSEC_WORKLOADS; do
		# shellcheck disable=SC1091
		if (cd "$PARSEC_DIR" && source env.sh && parsecmgmt -a build -p "$p" -c gcc) \
			> "$HERE/parsec-build-$p.log" 2>&1; then
			echo "built $p"
		else
			echo "FAILED $p (see parsec-build-$p.log)"
			continue
		fi
		# Run directory: the native input unpacked once, the run config, and
		# the install dir, read by workload_cmd.
		pkg=$(echo "$PARSEC_DIR"/pkgs/*/"$p")
		inst=$(echo "$pkg"/inst/*.gcc)
		rd="$PARSEC_RUN/$p"
		mkdir -p "$rd"
		[[ -f $pkg/inputs/input_native.tar ]] && tar -xf "$pkg/inputs/input_native.tar" -C "$rd"
		cp "$pkg/parsec/native.runconf" "$rd/"
		echo "$inst" > "$rd/inst"
	done
}

setup_ycsb() {
	command -v java > /dev/null || { echo "YCSB needs Java: sudo apt install default-jre-headless" >&2; exit 1; }
	if [[ ! -x $REDIS_DIR/src/redis-server ]]; then
		mkdir -p "$REDIS_DIR"
		wget -qO- https://download.redis.io/redis-stable.tar.gz | tar -xz -C "$REDIS_DIR" --strip-components=1
		make -C "$REDIS_DIR" -j"$(nproc)"
	fi
	if [[ ! -d $YCSB_DIR ]]; then
		wget -qO- https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-redis-binding-0.17.0.tar.gz |
			tar -xz -C "$(dirname "$YCSB_DIR")"
		mv "$(dirname "$YCSB_DIR")/ycsb-redis-binding-0.17.0" "$YCSB_DIR"
	fi
	"$REDIS_DIR/src/redis-server" --version
	ls "$YCSB_DIR/bin" "$YCSB_DIR/workloads"
}

setup_gpt2() {
	[[ -d $GPT2_VENV ]] || python3 -m venv "$GPT2_VENV"
	"$GPT2_VENV/bin/pip" install -q torch --index-url https://download.pytorch.org/whl/cpu
	"$GPT2_VENV/bin/pip" install -q transformers
	# Download the 4 models into the HuggingFace cache (gpt2.py runs offline).
	"$GPT2_VENV/bin/python" -c "
from transformers import GPT2LMHeadModel
for m in ('gpt2', 'gpt2-medium', 'gpt2-large', 'gpt2-xl'):
    GPT2LMHeadModel.from_pretrained(m)
    print('cached', m)
"
}

case "${1:-}" in
gapbs) setup_gapbs ;;
parsec) setup_parsec ;;
ycsb) setup_ycsb ;;
gpt2) setup_gpt2 ;;
all) setup_gapbs; setup_parsec; setup_ycsb; setup_gpt2 ;;
*) sed -n '2,18p' "$0" >&2; exit 1 ;;
esac
