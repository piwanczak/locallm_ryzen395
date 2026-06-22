# Phase 07 Rankings And Failure Modes

Date: 2026-06-21

## Ranked Current Profiles

| Rank | Profile | Decision | Evidence |
| ---: | --- | --- | --- |
| 1 | Controlled edit-agent + WSL ROCm llama.cpp + Qwen3 Coder 30B Q4 | Quality-default local coding workflow | Passed `js-window`; passed protected `browser-style`; browser verification passed |
| 2 | Docker-controlled edit-agent + WSL ROCm llama.cpp + Qwen3 Coder 30B Q4 | Containerized benchmark workflow | Docker image builds; `js-window` and protected `browser-style` pass inside Linux container |
| 3 | Controlled edit-agent + WSL ROCm llama.cpp + Qwen3 Coder 30B Q2 | Throughput fallback | Faster single-request decode estimate; passed `js-window`; passed protected `browser-style`; browser verification passed |
| 4 | WSL ROCm llama.cpp OpenAI-compatible server | Runtime baseline | Q2 single-request decode estimate `70.20 tok/s`; Q4 single-request decode estimate around `56-60 tok/s`; HIP smoke passed |
| 5 | OpenCode + WSL ROCm llama.cpp + Qwen3 Coder 30B | Realism benchmark only | One 8k run fixed `js-window`, but process did not terminate cleanly; later hardened run showed context overflow/tool-loop issues |
| 6 | Pi Docker runner | Build-validated, adapter-needed candidate | Base/browser images build and Pi reaches local model endpoint, but session logs show tool-call-shaped output is stored as assistant text instead of executable Pi tool calls |
| 7 | WSL Vulkan llama.cpp | Rejected for now | WSL Vulkan currently exposes only Mesa `llvmpipe` CPU |

## Key Metrics

| Metric | Value |
| --- | ---: |
| WSL memory configured | about `65 GB` |
| WSL memory visible in Linux | about `60 GiB` RAM plus `16 GiB` swap |
| Proven lower WSL cap for current Q4 host workflow | `32GB` |
| HIP reported pool | `70491842560` bytes |
| Qwen3 Coder Q2 GGUF size | about `11.26 GB` |
| Qwen3 Coder Q4 GGUF size | about `17.35 GB` |
| WSL ROCm single decode estimate | `70.20 tok/s` |
| WSL ROCm 4-way aggregate decode estimate | `84.65 tok/s` |
| WSL ROCm Q4 single decode estimate | `56-58 tok/s` |
| WSL ROCm Q4 4-way aggregate decode estimate | `96.27 tok/s` |
| Docker-controlled Q4 `js-window` first content | `1107.9 ms` |
| Docker-controlled Q4 `browser-style` first content | `1900.9 ms` |
| Qwen3 Coder Q4 projected device memory at 4-way/4k | `18281 MiB` |
| Qwen3 Coder Q4 ROCm model buffer | `17596.43 MiB` |
| Qwen3 Coder Q4 ROCm KV buffer at 4-way/4k | `384.00 MiB` |
| Controlled `js-window` wall time | `5825 ms` |
| Controlled protected `browser-style` wall time | `3730.1 ms` |

## Failure Modes

| Area | Failure Mode | Impact | Mitigation |
| --- | --- | --- | --- |
| WSL memory | `32GB` is proven only for the current short-context host/WSL Q4 workflow | Long-context, Docker-heavy, Pi/browser, and multi-agent comparisons are not covered by the 32GB pass | Use `32GB` for current host workflow, `48GB` for headroom, and rerun cap-specific tests for larger workloads |
| WSL Vulkan | Only CPU `llvmpipe` visible | Vulkan path is not a useful WSL GPU baseline | Keep ROCm/HIP as WSL default; revisit only when AMD Vulkan ICD appears |
| OpenCode 4k | Context overflow | No useful agent edit | Do not use 4k for OpenCode with this model/profile |
| OpenCode 8k | Correct edit possible but process may loop or fail to terminate | Not reliable as default workflow | Keep hardened timeout/capture runner; use controlled runner for practical local edits |
| Frontend DOM task | Model inverted `element.hidden` semantics | Unprotected browser-style runs failed | Protect known-good invariants and require verifier/browser checks |
| JSON edit format | Model can produce malformed full-file JSON or non-exact replacements | Harness may fail to apply edits | Prefer allowlisted exact replacements and retry with captured raw outputs |
| Docker/Pi | Pi receives tool-call-shaped text from local llama.cpp but does not execute it | Container and endpoint wiring work, but Pi is not a working local editing agent | Use an endpoint that emits structured executable tool calls, or add a Pi custom provider/adapter that converts Qwen/llama.cpp function-tag text into Pi `toolCall` events |
| Gemma E4B Q4 | Current AMD llama.cpp build reports unknown architecture `gemma4` | Cannot benchmark this local Gemma artifact on the WSL ROCm runtime yet | Try a newer llama.cpp/LM Studio backend that supports Gemma 4 |
| Small coder models | Qwen2.5-Coder 1.5B Q4/Q8 are fast but produce broken edits | Too unreliable as coding-agent defaults | Keep only as latency controls |

## Recommendation

Use WSL2 Ubuntu 24.04 plus AMD ROCm/ROCDXG llama.cpp as the runtime, and use `scripts/run-controlled-edit-agent.mjs` as the practical local coding workflow. Use `scripts/run-docker-controlled-q4-workflow.ps1 -Build` when the benchmark runner itself should run in Docker. Keep `CTX_SIZE=8192`, `PARALLEL=1`, and explicit verifier-backed tasks for now. Use Qwen3 Coder 30B Q4 as the quality default and Qwen3 Coder 30B Q2 as the faster fallback.

The current host/WSL Q4 workflow passed at a measured `32GB` WSL cap, so `65GB` is not required for that workflow. Use `48GB` if Docker Desktop, Pi/browser containers, larger contexts, or parallel agent experiments need additional headroom.

Do not spend time chasing WSL Vulkan until a GPU ICD is visible. For Pi Docker, do not rerun the same edit benchmark until there is a structured tool-call endpoint or adapter; container runtime availability is no longer the blocker.
