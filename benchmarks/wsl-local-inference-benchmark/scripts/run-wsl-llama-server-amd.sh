#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bench_root="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$bench_root/../.." && pwd)"

runtime_dir="${LLAMA_RUNTIME_DIR:-$bench_root/runtimes/amd-llamacpp-rocm/current}"
model_path="${MODEL_PATH:-$repo_root/downloads/Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf}"
model_alias="${MODEL_ALIAS:-qwen/qwen3-coder-30b}"
host="${HOST:-0.0.0.0}"
port="${PORT:-8080}"
ctx_size="${CTX_SIZE:-4096}"
n_gpu_layers="${N_GPU_LAYERS:-99}"
parallel="${PARALLEL:-1}"
jinja="${LLAMA_JINJA:-}"
chat_template="${LLAMA_CHAT_TEMPLATE:-}"
chat_template_file="${LLAMA_CHAT_TEMPLATE_FILE:-}"
chat_template_kwargs="${LLAMA_CHAT_TEMPLATE_KWARGS:-}"

if [[ ! -x "$runtime_dir/llama-server" ]]; then
  echo "Missing executable: $runtime_dir/llama-server" >&2
  echo "Run setup-wsl-llamacpp-amd.sh first." >&2
  exit 1
fi

if [[ ! -f "$model_path" ]]; then
  echo "Missing model file: $model_path" >&2
  echo "Set MODEL_PATH to an existing GGUF." >&2
  exit 1
fi

export HSA_ENABLE_DXG_DETECTION="${HSA_ENABLE_DXG_DETECTION:-1}"
export LD_LIBRARY_PATH="$runtime_dir:${LD_LIBRARY_PATH:-}"

args=(
  --host "$host" \
  --port "$port" \
  --model "$model_path" \
  --alias "$model_alias" \
  -ngl "$n_gpu_layers" \
  -c "$ctx_size" \
  --parallel "$parallel" \
  -fa on
)

if [[ "$jinja" == "1" || "$jinja" == "true" || "$jinja" == "yes" ]]; then
  args+=(--jinja)
fi

if [[ -n "$chat_template" ]]; then
  args+=(--chat-template "$chat_template")
fi

if [[ -n "$chat_template_file" ]]; then
  args+=(--chat-template-file "$chat_template_file")
fi

if [[ -n "$chat_template_kwargs" ]]; then
  args+=(--chat-template-kwargs "$chat_template_kwargs")
fi

exec "$runtime_dir/llama-server" "${args[@]}"
