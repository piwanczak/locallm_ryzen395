# Phase 13 Docker Controlled Agent Report

Date: 2026-06-21

## Scope

This phase adds and validates a Docker-native benchmark runner for the already-proven controlled edit-agent workflow. It is intentionally separate from Pi:

- Pi remains the article-aligned third-party agent candidate, but currently fails to execute local llama.cpp tool-call-shaped output.
- The Docker controlled runner proves that the local coding benchmark itself can run from inside a container and produce real pass/fail evidence.

## Added Artifacts

| Artifact | Purpose |
| --- | --- |
| `benchmarks/docker-controlled-agent-runner/Dockerfile` | Small Node 24 image that runs `run-controlled-edit-agent.mjs` |
| `benchmarks/docker-controlled-agent-runner/README.md` | Runner usage and boundary notes |
| `scripts/run-docker-controlled-q4-workflow.ps1` | Starts WSL ROCm Q4, builds/runs the Docker controlled runner, captures outputs, stops WSL server |

## Validation Artifact

| Artifact | Result |
| --- | --- |
| `results/20260621-235639-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json` | Completed with `passed=true` |

## Results

| Check | Result |
| --- | --- |
| Docker image build | PASS; `local/controlled-edit-agent:node24` |
| WSL llama.cpp start | PASS; Qwen3 Coder Q4, `CTX_SIZE=8192`, `PARALLEL=1` |
| `js-window` inside Docker | PASS; first content `1107.9 ms`; wall `5730 ms`; verifier exited `0` |
| Protected `browser-style` inside Docker | PASS; first content `1900.9 ms`; wall `3274.3 ms`; verifier exited `0` |
| WSL llama.cpp stop | PASS |

The verifier command inside the container was Linux-native:

- `/usr/local/bin/node tools/test.mjs`

That matters because it proves the pass did not depend on Windows Node or host-local shell assumptions.

## Memory Evidence

The server log again showed full ROCm offload for Qwen3 Coder Q4:

- ROCm model buffer: about `17596 MiB`
- ROCm KV buffer at 8k and one slot: about `768 MiB`
- Visible ROCm pool: about `67226 MiB`

## Decision

The Docker-based benchmark runner requirement is now proven for the controlled local workflow. The recommended practical paths are:

1. Host/WSL controlled workflow: `scripts/run-recommended-q4-workflow.ps1`
2. Docker-controlled workflow: `scripts/run-docker-controlled-q4-workflow.ps1 -Build`

Pi remains a separate candidate, not the default, until tool-call execution works against a local endpoint.
