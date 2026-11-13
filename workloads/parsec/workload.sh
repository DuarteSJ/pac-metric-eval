# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# PARSEC 3.0, native inputs (interface: workloads/README.md).

PARSEC_HOME="$WORKLOADS_DIR/parsec"
PARSEC_SRC="$PARSEC_HOME/src"
PARSEC_RUN="$PARSEC_HOME/run"
PARSEC_WORKLOADS="blackscholes bodytrack canneal dedup facesim ferret fluidanimate freqmine raytrace streamcluster swaptions vips x264"

list_parsec() {
	local w
	for w in $PARSEC_WORKLOADS; do echo "$w"; done
}

# The package's native run (parsec/native.runconf: run_exec, and run_args with
# ${NTHREADS}), in the run directory setup.sh prepared. Not through
# parsecmgmt, which would unpack the inputs inside the measured run.
cmd_parsec() {
	local rd="$PARSEC_RUN/$1" run_exec="" run_args="" args
	# shellcheck disable=SC2034,SC2153  # NTHREADS is read by the runconf
	local NTHREADS=$THREADS
	# shellcheck disable=SC1091
	[[ -f $rd/native.runconf ]] && source "$rd/native.runconf"
	read -ra args <<< "$run_args"
	PRELOAD="$rd"
	CMD=(env -C "$rd" "$(cat "$rd/inst" 2> /dev/null || echo "$rd/NOT-SET-UP")/$run_exec" "${args[@]}")
}
