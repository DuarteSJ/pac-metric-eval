# shellcheck shell=bash disable=SC2034  # sets CMD/PRELOAD/ATTACH for the sourcer
# YCSB A-F on Redis (interface: workloads/README.md). A server workload:
# collect.sh calls ycsb_start NODE, counts the server (perf stat -p) while the
# client (CMD) runs, then calls ycsb_stop.

YCSB_HOME="$WORKLOADS_DIR/ycsb"
REDIS_SRC="$YCSB_HOME/redis"
YCSB_SRC="$YCSB_HOME/ycsb"
# YCSB's default ~1 KB records: ~10 GB of data.
YCSB_RECORDS="${YCSB_RECORDS:-10000000}"
YCSB_OPS="${YCSB_OPS:-20000000}"
YCSB_CLIENT_THREADS="${YCSB_CLIENT_THREADS:-16}"
REDIS_PORT="${REDIS_PORT:-6399}"
# The client runs outside the measured process: other socket-0 cores, DRAM.
CLIENT_CPUS="${CLIENT_CPUS:-8-23}"
CLIENT_NODE="${CLIENT_NODE:-0}"
YCSB_LOG="${YCSB_LOG:-/dev/null}"

list_ycsb() {
	local l
	for l in a b c d e f; do echo "ycsb-$l"; done
}

# ycsb_client load|run LETTER: sets CMD to the YCSB client.
ycsb_client() {
	CMD=(numactl --physcpubind="$CLIENT_CPUS" --membind="$CLIENT_NODE"
		"$YCSB_SRC/bin/ycsb.sh" "$1" redis -s -P "$YCSB_SRC/workloads/workload$2"
		-p redis.host=127.0.0.1 -p redis.port="$REDIS_PORT"
		-p recordcount="$YCSB_RECORDS" -p operationcount="$YCSB_OPS"
		-threads "$YCSB_CLIENT_THREADS")
}

cmd_ycsb() {
	YCSB_LETTER=${1#ycsb-}
	ATTACH=ycsb
	ycsb_client run "$YCSB_LETTER"
}

# ycsb_start NODE: Redis on the measured cores and the tier's node, then load
# the records. Not measured: perf attaches for the run phase only.
ycsb_start() {
	local node=$1 run_cmd=("${CMD[@]}")
	numactl --physcpubind="$CPUS" --membind="$node" "$REDIS_SRC/src/redis-server" \
		--port "$REDIS_PORT" --save '' --appendonly no > "$YCSB_LOG" 2>&1 &
	SERVER_PID=$!
	for _ in $(seq 50); do
		"$REDIS_SRC/src/redis-cli" -p "$REDIS_PORT" ping > /dev/null 2>&1 && break
		sleep 0.2
	done
	ycsb_client load "$YCSB_LETTER"
	"${CMD[@]}" >> "$YCSB_LOG" 2>&1
	CMD=("${run_cmd[@]}")
}

ycsb_stop() {
	"$REDIS_SRC/src/redis-cli" -p "$REDIS_PORT" shutdown nosave > /dev/null 2>&1 ||
		kill "$SERVER_PID" 2> /dev/null || true
	wait "$SERVER_PID" 2> /dev/null || true
}
