#!/usr/bin/env bash
set -u

stamp="$(date +%Y%m%d-%H%M%S)"
out_dir="${1:-./wsl-preflight-$stamp}"
mkdir -p "$out_dir"

run_capture() {
  local name="$1"
  shift
  {
    echo "$ $*"
    "$@"
    echo "exit=$?"
  } > "$out_dir/$name.out" 2> "$out_dir/$name.err"
}

command_probe() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
  else
    echo "missing"
  fi
}

{
  echo "created=$(date --iso-8601=seconds 2>/dev/null || date)"
  echo "pwd=$(pwd)"
  echo "user=$(id -un 2>/dev/null || true)"
  echo "kernel=$(uname -a 2>/dev/null || true)"
  echo
  echo "[os-release]"
  if [ -f /etc/os-release ]; then
    cat /etc/os-release
  fi
  echo
  echo "[devices]"
  ls -l /dev/dxg /dev/dri /dev/kfd 2>/dev/null || true
  echo
  echo "[groups]"
  id 2>/dev/null || true
  echo
  echo "[tool-paths]"
  for tool in python3 node npm git gcc g++ cmake make ninja vulkaninfo rocminfo hipconfig rocm-smi clinfo llama-server llama-cli ollama; do
    printf "%s=%s\n" "$tool" "$(command_probe "$tool")"
  done
  echo
  echo "[env]"
  env | sort | grep -E '^(HIP|HSA|ROCM|VK|VULKAN|LD_LIBRARY_PATH|PATH)=' || true
} > "$out_dir/summary.txt" 2> "$out_dir/summary.err"

if command -v vulkaninfo >/dev/null 2>&1; then
  run_capture vulkaninfo-summary vulkaninfo --summary
fi

if command -v rocminfo >/dev/null 2>&1; then
  run_capture rocminfo rocminfo
fi

if command -v hipconfig >/dev/null 2>&1; then
  run_capture hipconfig hipconfig --full
fi

if command -v rocm-smi >/dev/null 2>&1; then
  run_capture rocm-smi rocm-smi
fi

echo "$out_dir"
