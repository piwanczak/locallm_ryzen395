# Phase 11 Docker Pi Validation Report

Date: 2026-06-21

## Scope

Docker Desktop was installed and enabled for WSL after the earlier dry-run phase. This phase replaces the old Docker blocker with actual container evidence, while keeping the agentic Pi result separate from basic image/runtime validation.

Later related evidence: `phase-13-docker-controlled-agent.md` validates a separate Docker-native controlled edit-agent runner that does pass local coding tasks. `phase-15-pi-tool-call-compatibility.md` isolates the Pi failure to tool-call event compatibility. This phase remains specifically about Pi.

## Runtime State

| Check | Result |
| --- | --- |
| Windows Docker client/server | `29.5.3` |
| Docker Desktop | `4.78.0` |
| Windows context | `desktop-linux` |
| WSL Docker CLI | `/usr/bin/docker` in `Ubuntu-24.04` |
| WSL Docker Compose | `v5.1.4` |
| Base image | `local/pi-agent:base`, about `750MB` |
| Browser image | `local/pi-agent:browser`, about `3.36GB` |

## Script Fixes

| Area | Fix |
| --- | --- |
| Generated `models.json` | `run-pi-docker.ps1` now writes UTF-8 without BOM. Pi previously rejected Windows PowerShell's BOM-prefixed JSON. |
| Local OpenAI compatibility | Generated config now disables `supportsStore`, `supportsDeveloperRole`, `supportsReasoningEffort`, `supportsUsageInStreaming`, and `supportsStrictMode`, and uses `max_tokens`. |

## Validation Artifacts

| Artifact | Result |
| --- | --- |
| `../results/20260621-232549-pi-docker-base-validation/pi-docker-base-validation-summary.json` | Base image built; `docker compose run --rm pi --help` exited `0` |
| `../results/20260621-232722-pi-docker-model-config-validation/pi-docker-model-config-summary.json` | Pi parsed mounted `models.json` and listed `local-openai  local/qwen3-coder-30b-q4` |
| `../results/20260621-234235-pi-docker-browser-validation/pi-docker-browser-validation-summary.json` | Browser-capable image built; `docker compose --profile browser run --rm pi-browser --help` exited `0` |
| `../results/20260621-233951-pi-docker-q4-agent-edit-compat/pi-docker-q4-agent-edit-summary.json` | Pi reached WSL ROCm Q4 endpoint, but the edit task did not create the target file |

## Real Pi Edit Attempt

The edit attempt used:

- Container service: `pi`
- Endpoint from container: `http://host.docker.internal:8080/v1`
- WSL endpoint: ROCm llama.cpp on `127.0.0.1:8080`
- Model: `qwen/qwen3-coder-30b-q4`
- Pi model selector: `local-openai/qwen/qwen3-coder-30b-q4`
- Disposable workspace: `../results/20260621-233951-pi-docker-q4-agent-edit-compat/workspace`

The server accepted the request and generated a response. Pi exited `0`, but no `pi_docker_result.txt` was written. The model output contained text like a `write` tool call, and Pi printed it as assistant text instead of executing it.

This means the Docker network, model config, and local inference path work, but Pi plus this local llama.cpp endpoint is not a working editing agent. Phase 15 confirms the compatibility gap: Pi records the Qwen/llama.cpp function tags as assistant text, not as executable `toolCall` blocks.

## Decision

Promote the Pi Docker runner from "dry-run only" to "build-validated and endpoint-connected." Do not promote Pi as the default local coding-agent workflow yet. The working local coding workflow remains the controlled edit-agent runner against WSL ROCm llama.cpp.

## Next Work

1. Test Pi against an endpoint that returns structured executable tool calls, or add a local adapter/custom provider that converts Qwen-style function-tag text to Pi `toolCall` events.
2. Keep the browser image available for later once base Pi tool execution works.
3. Continue using disposable mounted workspaces for all Pi/Docker agent tests.
