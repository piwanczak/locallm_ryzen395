# Phase 03 Recommendation Report

Date: 2026-06-21

## Recommended Default

| Layer | Recommendation |
| --- | --- |
| OS path | WSL2 Ubuntu 24.04 |
| Runtime | AMD validated ROCm llama.cpp binary via `scripts/start-wsl-llama-server-amd.sh` |
| Quality-default model | `Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf` |
| Throughput fallback | `Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf` |
| Server profile | `CTX_SIZE=8192`, `PARALLEL=1`, flash attention enabled |
| Agent workflow | `scripts/run-controlled-edit-agent.mjs` for small edit tasks and verifier-backed simple frontend tasks |
| One-command wrapper | `scripts/run-recommended-q4-workflow.ps1` |
| Containerized wrapper | `scripts/run-docker-controlled-q4-workflow.ps1 -Build` |
| Benchmark record | Keep raw JSON under `../results/`; summarize in Markdown reports and render HTML |

## Why

The WSL ROCm backend is fast enough for small local coding tasks and avoids the current WSL Vulkan CPU-only path. OpenCode is valuable as a realistic agent benchmark, but Qwen3 Coder 30B is not reliable enough with OpenCode tool loops under 8k context. The controlled edit-agent runner is narrower, safer, and currently demonstrably passes both `js-window` and a protected-invariant `browser-style` frontend task with browser verification.

Qwen3 Coder 30B Q4 is now the quality default because it passed both the code edit and protected frontend task, including browser verification, while still decoding around `56-60 tok/s` in single-request calibration and `91-96 tok/s` in 4-way 4k-context calibration. The one-command wrapper completed on `2026-06-21` with `js-window` and protected `browser-style` passing, single calibration at `60.28 tok/s`, and 4-way aggregate calibration at `91.97 tok/s`. Qwen3 Coder 30B Q2 remains a strong throughput fallback because it reached `70.20 tok/s` single-request, `84.65 tok/s` 4-way aggregate, and also passed the protected workflow.

The Docker-controlled wrapper also completed on `2026-06-21`: `js-window` passed inside Docker with first content `1107.9 ms`, and protected `browser-style` passed inside Docker with first content `1900.9 ms`. Use this when the benchmark itself should run in a Linux container while the model server remains WSL ROCm llama.cpp.

## Current Limits

- WSL memory defaults to about `60 GiB` with no `.wslconfig`, but the current host/WSL Qwen3 Coder Q4 workflow is proven at a `32GB` cap. Long-context comparisons to Windows 128 GB-class runs are still not valid from this short-context result.
- Docker/Pi runner validation is no longer blocked at the runtime layer: Docker Desktop and WSL integration work, Pi base and browser images build, and the Docker-controlled benchmark runner passes. Pi itself is not yet a working local editing agent because the Qwen/llama.cpp endpoint produced tool-call-shaped text that Pi did not execute.
- Unprotected frontend task `browser-style` failed because the model misunderstood `element.hidden` semantics even with an explicit hint.
- Browser verification has passed for the protected-invariant `browser-style` workflow, but broader browser-use automation is not yet covered.
- Gemma E4B Q4 is present locally but did not load in the current AMD llama.cpp build because the GGUF reports architecture `gemma4`.
- Qwen2.5-Coder 1.5B Q4/Q8 are fast but failed the controlled edit task, so they are not viable default coding agents.

## Next Work

1. Add an automated browser-verification adapter that can run outside the current in-app browser environment when Playwright or a browser binary is available.
2. Test Pi against an endpoint or adapter that returns executable OpenAI `tool_calls`; keep the current Docker images as the prepared container harness.
3. Consider a WSL memory sweep before attempting 16k and larger agent contexts.
4. Try Gemma E4B only after upgrading to a llama.cpp build that supports `gemma4`.
