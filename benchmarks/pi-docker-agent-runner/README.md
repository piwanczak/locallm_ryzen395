# Pi Docker Agent Runner

This directory is a guarded scaffold for running Pi inside Docker against a local OpenAI-compatible inference endpoint such as LM Studio, llama.cpp server, Ollama, vLLM, or a WSL-hosted runtime.

No image build or install is required to read these files. On this machine, the current preflight found WSL2 working with Ubuntu 24.04 and ROCm/ROCDXG, but no Docker/Podman/nerdctl CLI on PATH. Treat container runtime installation as the remaining explicit approval gate.

## Current Host Evidence

- Preflight artifact: `benchmarks/wsl-local-inference-benchmark/results/20260621-205116-preflight/host-preflight.json`
- WSL status: default version `2`
- WSL distro: `Ubuntu-24.04`, version `2`
- WSL memory: configured around `65 GB`, reported inside Linux as about `60 GiB` RAM plus `16 GiB` swap
- GPU reported by Windows: `AMD Radeon(TM) 8060S Graphics`, driver `32.0.31019.2002`
- WSL ROCm/HIP: working through ROCDXG; HIP smoke passed on `gfx1151`
- WSL Vulkan: installed but currently exposes only Mesa `llvmpipe` CPU
- Container runtime: Docker, Podman, and nerdctl were not found
- Host Node.js: available as `22.23.0`

## Runner Shape

- `Dockerfile.pi` builds a minimal Pi container from `node:24-bookworm-slim`.
- `Dockerfile.pi-browser` adds Playwright Chromium for frontend/browser verification tasks. It is deliberately separate because browser installation is large.
- `docker-compose.yml` mounts a selected workspace at `/workspace`, mounts generated Pi model config read-only, and keeps Pi sessions in a named Docker volume.
- `agent/AGENTS.md` gives Pi container-local guardrails.
- `scripts/run-pi-docker.ps1` and `scripts/run-pi-docker.sh` generate `models.json` for the selected local endpoint and run the selected Compose service.

## First Use After Docker Exists

Validate wrapper output before Docker exists:

```powershell
.\scripts\run-pi-docker.ps1 `
  -Workspace "C:\path\to\target-repo" `
  -BaseUrl "http://host.docker.internal:8080/v1" `
  -Model "local/qwen3-coder-30b-q4" `
  -DryRun `
  -PlanOutput "C:\path\to\pi-docker-plan.json"
```

This writes `.runtime/models.generated.json` and prints the Docker Compose command it would run.

From this directory, build and run the base container:

```powershell
.\scripts\run-pi-docker.ps1 `
  -Workspace "C:\path\to\target-repo" `
  -BaseUrl "http://host.docker.internal:1234/v1" `
  -Model "local/qwen3-coder-30b" `
  -Build
```

For browser-capable frontend tasks:

```powershell
.\scripts\run-pi-docker.ps1 `
  -Workspace "C:\path\to\target-repo" `
  -BaseUrl "http://host.docker.internal:1234/v1" `
  -Model "local/qwen3-coder-30b" `
  -Browser `
  -Build
```

Any extra arguments after the wrapper parameters are forwarded to `pi`.

If Windows execution policy blocks direct script invocation, run the wrapper through:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-pi-docker.ps1 -DryRun
```

## Provider Config

The wrapper writes `.runtime/models.generated.json` and mounts it as `/root/.pi/agent/models.json`.

Default provider:

- Provider id: `local-openai`
- API type: `openai-completions`
- API key: `not-needed`
- Compatibility: disables developer role, reasoning effort, and streaming usage fields by default because many local OpenAI-compatible servers reject one or more of those fields.

The static `models.local.example.json` is included for inspection or manual use.

## Security Boundary

This isolates the Pi process and its shell commands inside Docker, but any mounted workspace remains writable from inside the container. Use disposable benchmark fixtures first. Do not mount the whole home directory or host Pi auth directory unless that is an explicit decision.

## Dependency Gates

1. Install a container runtime only after approval. Docker Desktop is the simplest path on Windows; a WSL-native Docker Engine path can also be evaluated now that Ubuntu 24.04 exists.
2. Build the base Pi image.
3. Verify a local OpenAI-compatible endpoint with the existing calibration script before using Pi.
4. Use the browser image only after the base agent path can complete a small coding task.
