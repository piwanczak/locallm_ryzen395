# Phase 12 Recommended Q4 Workflow Report

Date: 2026-06-21

## Scope

This phase validates the one-command default local workflow:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-recommended-q4-workflow.ps1
```

The wrapper starts WSL ROCm llama.cpp for Qwen3 Coder 30B Q4, runs single-request calibration, runs the controlled `js-window` and protected `browser-style` edit tasks, stops the server, then runs a separate 4-way throughput calibration.

## Top-Level Artifact

| Artifact | Result |
| --- | --- |
| `results/20260621-234449-recommended-q4-workflow/recommended-q4-workflow-summary.json` | Completed, `dryRun=false` |

Linked artifacts:

- Agent matrix: `results/20260621-234449-model-matrix/model-matrix-summary.json`
- Throughput matrix: `results/20260621-234713-model-matrix/model-matrix-summary.json`
- Single calibration: `results/20260621-234449-model-matrix/qwen3-coder-30b-q4-calibration-single.json`
- `js-window`: `results/20260621-234449-model-matrix/qwen3-coder-30b-q4-js-window/js-window-result.json`
- `browser-style`: `results/20260621-234449-model-matrix/qwen3-coder-30b-q4-browser-style/browser-style-result.json`
- 4-way calibration: `results/20260621-234713-model-matrix/qwen3-coder-30b-q4-calibration-4way.json`

## Results

| Check | Result |
| --- | --- |
| Single calibration | PASS; first content `370.8 ms`; decode estimate `60.28 tok/s` |
| `js-window` controlled edit | PASS; first content `1465.5 ms`; wall `5603.2 ms`; verifier exited `0` |
| Protected `browser-style` edit | PASS; first content `2438.5 ms`; wall `4171.9 ms`; verifier exited `0` |
| 4-way calibration | PASS; `4/4` successful; first content min `416.1 ms`; aggregate decode estimate `91.97 tok/s` |

## Memory Evidence

The latest Q4 agent server log again shows the model fully offloaded to the WSL ROCm-visible GPU pool:

- Model buffer on ROCm: about `17596 MiB`
- KV buffer at 8k context and one slot: about `768 MiB`
- Visible ROCm pool: about `67226 MiB`

This supports the current conclusion that the `65 GB` WSL memory setting is enough for this short-context Q4 workflow. It does not answer whether `65 GB` is necessary; that still requires the guarded memory-cap sweep.

## Decision

The one-command Q4 workflow is now proven for the current default non-container local setup. It is the recommended path for small coding challenges and simple verifier-backed frontend edits on this machine:

- WSL2 Ubuntu 24.04
- AMD ROCm/ROCDXG llama.cpp
- Qwen3 Coder 30B Q4
- `scripts/run-controlled-edit-agent.mjs`
- `scripts/run-recommended-q4-workflow.ps1` for repeatable benchmark capture

Docker/Pi remains separate: the container builds and reaches the model, but Pi did not execute the local model's tool-call-shaped output.
