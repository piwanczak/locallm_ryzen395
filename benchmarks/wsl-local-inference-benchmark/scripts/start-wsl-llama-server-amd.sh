#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bench_root="$(cd "$script_dir/.." && pwd)"
log_dir="${LOG_DIR:-$bench_root/logs}"
port="${PORT:-8080}"
wait_seconds="${START_WAIT_SECONDS:-420}"

mkdir -p "$log_dir"

pid_file="${PID_FILE:-$log_dir/llama-server-amd.pid}"
log_file="${LOG_FILE:-$log_dir/llama-server-amd.log}"
ready_file="${READY_FILE:-$log_dir/llama-server-amd.ready.json}"

if [[ -f "$pid_file" ]]; then
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    echo "llama-server already running: pid=$old_pid"
    echo "log=$log_file"
    exit 0
  fi
fi

rm -f "$ready_file"
nohup "$script_dir/run-wsl-llama-server-amd.sh" >"$log_file" 2>&1 &
pid="$!"
echo "$pid" >"$pid_file"

deadline=$((SECONDS + wait_seconds))
until curl -fsS "http://127.0.0.1:$port/v1/models" >"$ready_file" 2>/dev/null; do
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "llama-server exited before becoming ready: pid=$pid" >&2
    echo "log=$log_file" >&2
    tail -80 "$log_file" >&2 || true
    exit 1
  fi
  if (( SECONDS >= deadline )); then
    echo "Timed out waiting for llama-server readiness: pid=$pid port=$port" >&2
    echo "log=$log_file" >&2
    tail -80 "$log_file" >&2 || true
    exit 1
  fi
  sleep 2
done

echo "llama-server ready: pid=$pid port=$port"
echo "log=$log_file"
echo "models=$ready_file"
