#!/usr/bin/env bash
# PARSEC 3.0: download into src/, build each package (config "gcc": its
# default parallel model, pthreads or OpenMP for freqmine), and prepare
# run/<package>/ with the native input unpacked once, the run config and the
# install dir. A package that fails to build is skipped (see build-<pkg>.log).
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/parsec/workload.sh"

if [[ ! -d $PARSEC_SRC ]]; then
	tgz="$PARSEC_HOME/parsec-3.0.tar.gz"
	[[ -f $tgz ]] || wget -O "$tgz" https://parsec.cs.princeton.edu/download/3.0/parsec-3.0.tar.gz
	tar -xzf "$tgz" -C "$PARSEC_HOME"
	mv "$PARSEC_HOME/parsec-3.0" "$PARSEC_SRC"
fi

for p in $PARSEC_WORKLOADS; do
	log="$PARSEC_HOME/build-$p.log"
	# shellcheck disable=SC1091
	if (cd "$PARSEC_SRC" && source env.sh && parsecmgmt -a build -p "$p" -c gcc) > "$log" 2>&1; then
		echo "built $p"
	else
		echo "FAILED $p (see $log)"
		continue
	fi
	pkg=$(echo "$PARSEC_SRC"/pkgs/*/"$p")
	rd="$PARSEC_RUN/$p"
	mkdir -p "$rd"
	[[ -f $pkg/inputs/input_native.tar ]] && tar -xf "$pkg/inputs/input_native.tar" -C "$rd"
	cp "$pkg/parsec/native.runconf" "$rd/"
	echo "$pkg"/inst/*.gcc > "$rd/inst"
done
