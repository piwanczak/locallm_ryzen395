#!/usr/bin/env bash
set -euo pipefail

runner_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
workspace="${WORKSPACE:-$(pwd)}"
base_url="${OPENAI_API_BASE:-http://host.docker.internal:1234/v1}"
model="${LOCAL_MODEL:-local/qwen3-coder-30b}"
service="pi"
build=0
dry_run=0

while (($#)); do
  case "$1" in
    --workspace)
      workspace="$2"
      shift 2
      ;;
    --base-url)
      base_url="$2"
      shift 2
      ;;
    --model)
      model="$2"
      shift 2
      ;;
    --browser)
      service="pi-browser"
      shift
      ;;
    --build)
      build=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

workspace="$(cd -- "$workspace" && pwd)"
runtime_dir="$runner_root/.runtime"
mkdir -p "$runtime_dir"
models_path="$runtime_dir/models.generated.json"

cat > "$models_path" <<JSON
{
  "providers": {
    "local-openai": {
      "baseUrl": "$base_url",
      "api": "openai-completions",
      "apiKey": "not-needed",
      "compat": {
        "supportsDeveloperRole": false,
        "supportsReasoningEffort": false,
        "supportsUsageInStreaming": false,
        "maxTokensField": "max_tokens"
      },
      "models": [
        {
          "id": "$model",
          "name": "Local $model",
          "input": ["text"],
          "contextWindow": 32768,
          "maxTokens": 4096,
          "cost": {
            "input": 0,
            "output": 0,
            "cacheRead": 0,
            "cacheWrite": 0
          }
        }
      ]
    }
  }
}
JSON

export PI_WORKSPACE="$workspace"
export PI_MODELS_JSON="$models_path"
export OPENAI_API_BASE="$base_url"
export OPENAI_API_KEY="${OPENAI_API_KEY:-not-needed}"

compose_args=(compose --project-directory "$runner_root" -f "$runner_root/docker-compose.yml")
if [[ "$service" == "pi-browser" ]]; then
  compose_args+=(--profile browser)
fi

if [[ "$dry_run" == "1" ]]; then
  docker_status="missing"
  docker_source=""
  if command -v docker >/dev/null 2>&1; then
    docker_status="found"
    docker_source="$(command -v docker)"
  fi
  printf 'dryRun=true\n'
  printf 'docker=%s\n' "$docker_status"
  printf 'dockerSource=%s\n' "$docker_source"
  printf 'runnerRoot=%s\n' "$runner_root"
  printf 'workspace=%s\n' "$workspace"
  printf 'modelsPath=%s\n' "$models_path"
  printf 'baseUrl=%s\n' "$base_url"
  printf 'model=%s\n' "$model"
  printf 'service=%s\n' "$service"
  printf 'build=%s\n' "$build"
  printf 'runCommand='
  printf '%q ' docker "${compose_args[@]}" run --rm "$service" "$@"
  printf '\n'
  exit 0
fi

if [[ "$build" == "1" ]]; then
  docker "${compose_args[@]}" build "$service"
fi

docker "${compose_args[@]}" run --rm "$service" "$@"
