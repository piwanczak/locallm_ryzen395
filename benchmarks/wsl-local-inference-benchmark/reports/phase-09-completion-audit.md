# Phase 09 Completion Audit

Date: 2026-06-21

## Purpose

This audit checks the active goal against current evidence. It identifies what is proven, what is intentionally not promoted, and what would require separate future work.

## Requirement Status

| Requirement | Status | Evidence |
| --- | --- | --- |
| Inspect Windows, WSL2, GPU, drivers, Docker, ROCm/HIP, Vulkan, RAM, storage | PROVEN for current run | `phase-00-preflight.md`, `phase-01-wsl-rocm-runtime.md`, preflight JSON, WSL preflight outputs |
| Prefer WSL2/Linux path where practical | PROVEN | Ubuntu 24.04 WSL2 installed and used for ROCm llama.cpp |
| Verify acceleration paths | PROVEN for ROCm/HIP, rejected for WSL Vulkan | HIP smoke passed; WSL Vulkan exposes only Mesa `llvmpipe` CPU |
| Use Vicki Boykis article and saved HTML reading list as inputs | PROVEN | `phase-05-research-candidates.md` |
| Extract candidate models/runtimes/agents/browser options | PROVEN | `phase-05-research-candidates.md`, `phase-08-multi-model-matrix.md` |
| Keep Markdown notes for minor steps | PROVEN | `notes/` entries through `2026-06-21_22-49-00_multi-model-matrix.md` |
| Produce Markdown and HTML per major phase | PROVEN through current phase | `reports/phase-00` through `phase-15` rendered as `.md` and `.html` |
| Create preflight notes and machine constraints | PROVEN | `phase-00-preflight.md`, `matrix.md`, `setup-runbook.md` |
| Create WSL2/Docker/GPU setup instructions | PROVEN | `setup-runbook.md`; `phase-11-docker-pi-validation.md`; `phase-13-docker-controlled-agent.md` |
| Create Docker-based benchmark runner | PROVEN | `benchmarks/docker-controlled-agent-runner` plus `scripts/run-docker-controlled-q4-workflow.ps1`; `js-window` and protected `browser-style` pass inside Docker |
| Create Pi/container-compatible runner variant | PROVEN as container runner; NOT PROMOTED as editing agent | `benchmarks/pi-docker-agent-runner` exists, builds, mounts model config, and reaches WSL llama.cpp; `phase-15-pi-tool-call-compatibility.md` explains why local tool execution needs an adapter or structured endpoint |
| Create scripts for startup, benchmark execution, logging, result capture | PROVEN | `start-wsl-llama-server-amd.sh`, `stop-wsl-llama-server-amd.sh`, `run-openai-compatible-calibration.mjs`, `run-controlled-edit-agent.mjs`, `run-wsl-model-matrix.ps1`, `run-docker-controlled-q4-workflow.ps1` |
| Capture raw benchmark outputs | PROVEN | `results/` contains calibration, agent, browser, and model-matrix JSON artifacts |
| Summarize rankings and failure modes | PROVEN | `phase-07-rankings-failure-modes.md`, `summary-rankings.json`, `model-matrix-comparison.json` |
| Recommend default model/runtime/agent workflow | PROVEN for non-container local workflow | `phase-03-recommendation.md`: WSL ROCm llama.cpp + Qwen3 Coder 30B Q4 + controlled edit-agent |
| Run repeatable benchmarks against comparable local models | PROVEN for available GGUFs | Qwen3 Coder Q4/Q2, Qwen2.5-Coder Q4/Q8, Gemma load failure captured |
| Cover small coding tasks | PROVEN | `js-window` controlled agent runs |
| Cover edit/patch tasks | PROVEN | controlled edit-agent allowlisted replacements |
| Cover simple frontend tasks | PROVEN | protected `browser-style` runs |
| Cover browser verification where feasible | PROVEN | Q2 and Q4 `browser-style` browser verification JSON and screenshots |
| Cover latency and throughput | PROVEN | single and 4-way calibration outputs |
| Cover GPU/VRAM/RAM use | PROVEN for current short-context workflow | WSL RAM and ROCm visible memory captured; Q4 server log captures projected device/model/KV memory; `32GB` cap sweep passed for current host/WSL Q4 workflow |
| Cover reliability and qualitative failure modes | PROVEN | OpenCode loop/context overflow, frontend hidden semantics, small-model syntax failures, Gemma architecture failure |
| Final working local coding-agent workflow | PROVEN for controlled local workflow | Qwen3 Coder Q4 controlled `js-window` and `browser-style` passed with browser verification |
| Final Docker-controlled agent workflow | PROVEN | `results/20260621-235639-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json` |
| Final Pi agent workflow | NOT PROMOTED | Container runtime works, but Pi did not execute local llama.cpp tool-call-shaped output; session logs show plain assistant text rather than Pi `toolCall` blocks |

## Current Recommended Workflow

| Layer | Current Default |
| --- | --- |
| OS | WSL2 Ubuntu 24.04 |
| Runtime | AMD ROCm/ROCDXG llama.cpp |
| Model | Qwen3 Coder 30B Q4_K_M |
| Fallback model | Qwen3 Coder 30B Q2_K |
| Agent | `scripts/run-controlled-edit-agent.mjs` |
| Containerized agent runner | `scripts/run-docker-controlled-q4-workflow.ps1 -Build` |
| Context | `8192` for controlled edit tasks |
| Browser check | In-app browser or equivalent Playwright/browser verifier against generated fixture |

## Remaining Work

| Gap | Why It Matters | Next Concrete Step |
| --- | --- | --- |
| Pi Docker tool execution not working | Pi is useful only after it can dispatch tools | Use a structured tool-call endpoint, or implement a Pi custom provider/adapter from Qwen/llama.cpp function tags to Pi `toolCall` events |
| Broader memory-cap coverage | `32GB` is proven only for the current host/WSL Q4 workflow | Rerun cap-specific tests before lowering the cap for Docker-heavy, Pi/browser, long-context, or multi-agent workloads |
| Gemma candidate blocked | Article-inspired candidate cannot be compared on current AMD llama.cpp build | Try a newer llama.cpp/LM Studio backend with `gemma4` support |
| Broader autonomous agent not proven | Controlled harness is intentionally narrower than a full agent | Revisit OpenCode/Pi after context/tool-loop behavior is bounded |

## Decision

The practical goal is complete for the proven WSL2 local coding-agent setup: the host/WSL Q4 workflow is working and documented, the Docker-controlled workflow is working and documented, browser/frontend verification is covered, and the `32GB` cap sweep proves `65GB` is not required for the current host/WSL short-context Q4 workflow. Pi is documented as build-validated and endpoint-connected, but not promoted because the current llama.cpp/Qwen endpoint returns function-tag text instead of executable Pi tool calls. Future Pi work should start with a structured tool-call endpoint or adapter, not with another identical edit rerun.
