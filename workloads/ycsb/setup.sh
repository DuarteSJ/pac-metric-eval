#!/usr/bin/env bash
# YCSB on Redis: Redis (stable, built from source) into redis/, the YCSB 0.17.0
# Redis binding into ycsb/. The YCSB client needs Java
# (sudo apt install default-jre-headless).
set -euo pipefail
WORKLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$WORKLOADS_DIR/common.sh"
source "$WORKLOADS_DIR/ycsb/workload.sh"

command -v java > /dev/null || { echo "YCSB needs Java: sudo apt install default-jre-headless" >&2; exit 1; }

if [[ ! -x $REDIS_SRC/src/redis-server ]]; then
	mkdir -p "$REDIS_SRC"
	wget -qO- https://download.redis.io/redis-stable.tar.gz | tar -xz -C "$REDIS_SRC" --strip-components=1
	make -C "$REDIS_SRC" -j"$(nproc)"
fi
if [[ ! -d $YCSB_SRC ]]; then
	mkdir -p "$YCSB_SRC"
	wget -qO- https://github.com/brianfrankcooper/YCSB/releases/download/0.17.0/ycsb-redis-binding-0.17.0.tar.gz |
		tar -xz -C "$YCSB_SRC" --strip-components=1
fi
"$REDIS_SRC/src/redis-server" --version
ls "$YCSB_SRC/bin" "$YCSB_SRC/workloads"
