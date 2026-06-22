# Phase 10 Pi Docker Command-Plan Dry-Run Report

Date: 2026-06-21

## Scope

This phase improved the Pi/container runner evidence before Docker was installed. It checks that the wrapper can generate Pi model configuration and the exact Docker Compose command plans for both the base and browser-capable services.

This is not a Docker benchmark. No containers were built, no containers were run, and Pi was not executed inside Docker.

Later update: Docker Desktop is now installed and WSL-enabled. Real container build/run evidence is recorded in `phase-11-docker-pi-validation.md`.

## Script Changes

| Script | Change |
| --- | --- |
| `benchmarks/pi-docker-agent-runner/scripts/run-pi-docker.ps1` | Added `-DryRun` and `-PlanOutput`; emits JSON command plan and generated model config path |
| `benchmarks/pi-docker-agent-runner/scripts/run-pi-docker.sh` | Added `--dry-run`; emits shell-readable command plan |

## Validation Artifacts

| Artifact | Result |
| --- | --- |
| `../results/20260621-230439-pi-docker-dry-run/pi-docker-plan.json` | GENERATED: base `pi` service command plan only |
| `../results/20260621-230439-pi-docker-dry-run/models.generated.json` | PARSED: generated Pi model config only |
| `../results/20260621-230439-pi-browser-dry-run/pi-browser-plan.json` | GENERATED: `pi-browser` service command plan only, with `--profile browser` |
| `../results/20260621-230439-pi-browser-dry-run/models.generated.json` | PARSED: generated browser-run model config only |

## Benchmark Status

| Check | Status |
| --- | --- |
| Docker CLI available | NO |
| Docker image built | NO |
| Docker container started | NO |
| Pi CLI executed inside Docker | NO |
| Coding task executed inside Docker | NO |
| Browser task executed inside Docker | NO |

## Base Plan

| Field | Value |
| --- | --- |
| Docker available | `false` |
| Service | `pi` |
| Model | `local/qwen3-coder-30b-q4` |
| Base URL | `http://host.docker.internal:8080/v1` |
| Workspace | `<repo-root>` |
| Run command | `docker compose --project-directory <runner> -f <compose> run --rm pi` |

## Browser Plan

| Field | Value |
| --- | --- |
| Docker available | `false` |
| Service | `pi-browser` |
| Browser profile | `--profile browser` |
| Model | `local/qwen3-coder-30b-q4` |
| Base URL | `http://host.docker.internal:8080/v1` |
| Run command | `docker compose --project-directory <runner> -f <compose> --profile browser run --rm pi-browser` |

## Decision

At the time of this phase, the Pi Docker runner was more strongly prepared than before: configuration generation and command construction worked for both base and browser services, but no Docker runtime was available.

The next approved step from this historical phase has now happened. The remaining Docker/Pi gap is tool-call execution against the local llama.cpp endpoint, not container runtime availability.
