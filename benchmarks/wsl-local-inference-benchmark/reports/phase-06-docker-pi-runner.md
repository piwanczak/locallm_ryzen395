# Phase 06 Docker Pi Runner Report

Date: 2026-06-21

## Scope

This phase originally validated the Docker/Pi runner scaffold without building containers. At the time, no container runtime was available on PATH, so runtime validation was intentionally blocked.

Later update: Docker Desktop was installed and WSL integration was enabled. See `phase-11-docker-pi-validation.md` for the real build/run validation that supersedes the blocker in this phase.

## Current Scaffold

| Artifact | Purpose | Status |
| --- | --- | --- |
| `benchmarks/pi-docker-agent-runner/Dockerfile.pi` | Minimal Pi image from Node 24 plus bash/git/ripgrep | Present |
| `benchmarks/pi-docker-agent-runner/Dockerfile.pi-browser` | Browser-capable Pi image with Playwright Chromium | Present |
| `benchmarks/pi-docker-agent-runner/docker-compose.yml` | Mounts workspace, model config, guardrails, and session volume | Present |
| `benchmarks/pi-docker-agent-runner/models.local.example.json` | Static local OpenAI-compatible provider example | Present and JSON-valid |
| `benchmarks/pi-docker-agent-runner/scripts/run-pi-docker.ps1` | Windows wrapper that generates `models.generated.json` and runs Compose | Present and parser-valid |
| `benchmarks/pi-docker-agent-runner/scripts/run-pi-docker.sh` | Linux/macOS wrapper shape for the same workflow | Present and bash syntax-valid |
| `benchmarks/pi-docker-agent-runner/agent/AGENTS.md` | Container-local guardrails | Present |

## Validation Result

| Check | Result |
| --- | --- |
| Docker CLI | BLOCKED: not found |
| Podman CLI | BLOCKED: not found |
| nerdctl CLI | BLOCKED: not found |
| PowerShell wrapper parser | PASS |
| Bash wrapper syntax | PASS |
| Static model JSON parse | PASS |
| Base Pi dry-run plan | GENERATED only; no container run |
| Browser Pi dry-run plan | GENERATED only; no container run |
| Compose build/run | BLOCKED by missing container runtime |
| Browser image validation | BLOCKED by missing container runtime |

## Endpoint Shape

The runner is aligned with the article and Pi docs pattern:

- Host inference endpoint: `http://host.docker.internal:1234/v1` for Windows-hosted LM Studio, or another OpenAI-compatible endpoint.
- WSL llama.cpp endpoint from Windows: `http://127.0.0.1:8080/v1` for calibration.
- Container to host endpoint: `http://host.docker.internal:<port>/v1` after verifying Docker's host gateway behavior.
- Pi provider API: `openai-completions` with local compatibility fields disabling developer role, reasoning effort, and streaming usage metadata.

Dry-run artifacts:

- `../results/20260621-230439-pi-docker-dry-run/pi-docker-plan.json`
- `../results/20260621-230439-pi-browser-dry-run/pi-browser-plan.json`

These artifacts are command plans, not benchmark outputs. They do not prove that Docker, Pi, or the browser image can run on this machine.

## Security Boundary

The container isolates the Pi process and its shell commands, but the mounted workspace remains writable. Use disposable benchmark fixtures first. Do not mount the whole home directory or host Pi auth directory.

## Historical Next Build Sequence

At the time of this phase, the next sequence was to install a runtime, build the container, verify Pi model config, and run a deterministic coding fixture. Docker was later installed and the base/browser images were built in `phase-11-docker-pi-validation.md`.

## Current Decision

Keep this phase as the historical scaffold gate. The later `phase-11` result promotes the runner to build-validated and endpoint-connected, but still not to a working Pi editing-agent path.
