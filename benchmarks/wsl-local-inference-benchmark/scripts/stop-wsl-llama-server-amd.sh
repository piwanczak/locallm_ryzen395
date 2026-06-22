#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bench_root="$(cd "$script_dir/.." && pwd)"
log_dir="${LOG_DIR:-$bench_root/logs}"
pid_file="${PID_FILE:-$log_dir/llama-server-amd.pid}"

if [[ ! -f "$pid_file" ]]; then
  echo "No pid file found: $pid_file"
  exit 0
fi

pid="$(cat "$pid_file" 2>/dev/null || true)"
rm -f "$pid_file"

if [[ -z "$pid" ]]; then
  echo "Pid file was empty."
  exit 0
fi

if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  for _ in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "Stopped llama-server: pid=$pid"
      exit 0
    fi
    sleep 1
  done
  kill -9 "$pid" 2>/dev/null || true
  echo "Force-stopped llama-server: pid=$pid"
else
  echo "llama-server was not running: pid=$pid"
fi
