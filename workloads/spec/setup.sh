#!/usr/bin/env bash
# SPEC CPU 2017: one run directory per benchmark in run/, from the licensed
# install in SPEC_DIR (read-only for us: runcpu writes only under out/).
#
#   1. config: a copy of SPEC's Example-gcc-linux-x86.cfg, whose default label
#      "mytest" is the one the install's binaries were built with (and the
#      one PACT's own script runs). runcpu writes build hashes into its
#      config, so it must not be the shared one.
#   2. runcpu --action setup --nobuild --output_root out/: run directories
#      with the reference inputs, using the existing binaries.
#   3. run/<benchmark>: a link to that run directory, with pact-run.sh in it:
#      the reference command lines (specinvoke -n), run in that directory.
# Benchmarks without a "$SPEC_LABEL" binary are skipped (7 were never built in
# the install: see README.md).
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/spec/workload.sh"

OUT="$SPEC_HOME/out"
CFG="$SPEC_HOME/pact-fig2.cfg"
mkdir -p "$OUT" "$SPEC_RUN"
[[ -f $CFG ]] || cp "$SPEC_DIR/config/Example-gcc-linux-x86.cfg" "$CFG"

benches=()
for b in $(list_spec); do
	if ls "$SPEC_DIR/benchspec/CPU/$b/exe/"*"_base.$SPEC_LABEL-m64" > /dev/null 2>&1; then
		benches+=("$b")
	else
		echo "skip $b: no $SPEC_LABEL binary in $SPEC_DIR"
	fi
done

# shellcheck disable=SC1091
(cd "$SPEC_DIR" && source shrc &&
	runcpu --config="$CFG" --define label="$SPEC_LABEL" --action=setup --nobuild \
		--size=ref --tune=base --copies=1 --threads="$THREADS" --noreportable \
		--output_root="$OUT" "${benches[@]}")

for b in "${benches[@]}"; do
	# shellcheck disable=SC2012  # SPEC run dir names are plain
	src=$(ls -d "$OUT/benchspec/CPU/$b/run/run_base_ref"*"_$SPEC_LABEL-m64.0000" 2> /dev/null | head -1)
	if [[ -z $src ]]; then
		echo "FAILED $b: no run directory under $OUT"
		continue
	fi
	# run/<benchmark> -> the run directory; pact-run.sh inside it.
	ln -sfn "$src" "$SPEC_RUN/$b"
	{
		echo "#!/usr/bin/env bash"
		echo "# $b reference run (specinvoke -n), from its run directory"
		echo "set -e"
		echo "cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\""
		(cd "$SPEC_DIR" && source shrc > /dev/null && cd "$src" && specinvoke -n) | grep -v '^#'
	} > "$src/pact-run.sh"
	echo "set up $b"
done
