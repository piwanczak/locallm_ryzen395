#!/usr/bin/env bash
set -euo pipefail

if [[ "${CONFIRM_WSL_LLAMA_DOWNLOAD:-0}" != "1" ]]; then
  echo "Refusing to download llama.cpp runtime without CONFIRM_WSL_LLAMA_DOWNLOAD=1" >&2
  exit 2
fi

benchmark_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_root="$benchmark_root/runtimes/amd-llamacpp-rocm"
zip_path="$runtime_root/llama-b8407-ubuntu-24.04-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64.zip"
url="${LLAMA_AMD_ZIP_URL:-https://repo.radeon.com/rocm/llama.cpp/linux/rocm-rel-7.2.1/llama-b8407-ubuntu-24.04-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64.zip}"

mkdir -p "$runtime_root"

if [[ ! -f "$zip_path" ]]; then
  wget -O "$zip_path" "$url"
fi

rm -rf "$runtime_root/extracted"
mkdir -p "$runtime_root/extracted"
unzip -q "$zip_path" -d "$runtime_root/extracted"

bin_dir="$(find "$runtime_root/extracted" -type f -name llama-server -printf '%h\n' | head -n 1)"
if [[ -z "${bin_dir:-}" ]]; then
  echo "Could not find llama-server under $runtime_root/extracted" >&2
  exit 3
fi

chmod +x "$bin_dir"/llama-server "$bin_dir"/llama-bench "$bin_dir"/llama-cli 2>/dev/null || true
ln -sfn "$bin_dir" "$runtime_root/current"

cat > "$runtime_root/manifest.txt" <<EOF
created=$(date --iso-8601=seconds 2>/dev/null || date)
url=$url
zip=$zip_path
bin_dir=$bin_dir
current=$runtime_root/current
EOF

echo "$runtime_root/current"
