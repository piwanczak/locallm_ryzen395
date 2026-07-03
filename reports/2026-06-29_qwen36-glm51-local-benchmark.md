---
title: Qwen3.6 35B A3B and GLM-5.1 local benchmark
date: 2026-06-29
tags:
  - local-inference
  - benchmark
  - qwen
  - glm
  - ollama
  - kebab
---

# Qwen3.6 35B A3B and GLM-5.1 local benchmark

Finalized: 2026-06-29 22:05 Europe/Warsaw.

## Summary

Qwen3.6 35B A3B was pulled and benchmarked locally through Windows Ollama as
`hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M`. GLM-5.1 was not pulled:
the smallest checked full-model GGUF route, Bartowski `IQ1_S`, is about
`147.30 GiB`, which is larger than the available `C:` free space before cache
overhead.

Qwen3.6 is runnable through Ollama's native chat API with `think=false`, but it
does not justify a promoted default change. It passed `4/7` one-attempt
real-usage tasks and failed the Kebab visual benchmark despite generating a
large canvas program.

## Evidence

- Plan:
  [notes/2026-06-29_21-40-28_qwen36-glm51-benchmark-plan.md](../public-results/results-summary.md)
- Preflight and GLM fit gate:
  [notes/2026-06-29_21-48-41_qwen36-glm51-preflight.md](../public-results/results-summary.md)
- Qwen3.6 pull and smoke:
  [notes/2026-06-29_22-00-00_qwen36-pull-and-smoke.md](../public-results/results-summary.md)
- Qwen3.6 real-usage direct matrix:
  [notes/2026-06-29_22-03-00_qwen36-real-usage-direct-matrix.md](../public-results/results-summary.md)
- Kebab and cleanup:
  [notes/2026-06-29_22-05-00_qwen36-kebab-and-cleanup.md](../public-results/results-summary.md)
- Real-usage rollup:
  [benchmarks/real-usage-agent-benchmark/reports/2026-06-29-qwen36-q4km-real-usage-rollup.md](../benchmarks/real-usage-agent-benchmark/reports/2026-06-29-qwen36-q4km-real-usage-rollup.md)
- Kebab report:
  [benchmarks/kebab-benchmark/reports/2026-06-29-qwen36-q4km-kebab.md](../benchmarks/kebab-benchmark/reports/2026-06-29-qwen36-q4km-kebab.md)

## Model And Fit

Qwen3.6 source routes checked:

- `https://huggingface.co/Qwen/Qwen3.6-35B-A3B`
- `https://huggingface.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF`
- `https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF`

Selected Qwen3.6 artifact:

| Item | Value |
| --- | --- |
| Ollama model | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` |
| Installed size | `22069580234` bytes |
| Family | `qwen35moe` |
| Parameter size | `34.7B` |
| Context length | `262144` |
| Capabilities | `completion`, `vision` |

GLM-5.1 source routes checked:

- `https://huggingface.co/zai-org/GLM-5.1`
- `https://huggingface.co/unsloth/GLM-5.1-GGUF`
- `https://huggingface.co/bartowski/zai-org_GLM-5.1-GGUF`

Checked GLM-5.1 GGUF size gates:

| Repo/quant | Shards | Total |
| --- | ---: | ---: |
| `bartowski/zai-org_GLM-5.1-GGUF` `IQ1_S` | 4 | `147.30 GiB` |
| `bartowski/zai-org_GLM-5.1-GGUF` `IQ1_M` | 5 | `163.93 GiB` |
| `bartowski/zai-org_GLM-5.1-GGUF` `IQ2_XXS` | 6 | `189.92 GiB` |
| `bartowski/zai-org_GLM-5.1-GGUF` `IQ2_XS` | 6 | `211.04 GiB` |
| `unsloth/GLM-5.1-GGUF` `MXFP4_MOE` | 11 | `419.94 GiB` |

Decision: GLM-5.1 full-model local testing is blocked on disk/runtime fit for
this pass. Do not treat a smaller `GLM-5.1-Air` or hosted endpoint as an exact
substitute without labeling it as a separate lane.

## Runtime Gate

The OpenAI-compatible streaming smoke reached the Qwen3.6 endpoint but returned
no visible content while consuming completion tokens. The Ollama-native chat
path with `think=false` produced parseable JSON edits and passed a
`frontend-filter` smoke.

Use this transport for future Ollama Qwen3.6 edit runs:

```powershell
-Transport ollama-chat -Think false
```

## Real-Usage Results

Full matrix settings:

- Runner: `ollama-direct-api:windows-qwen36-q4km`
- Context length: `16384`
- Max attempts: `1`
- Max tokens: `4096`
- Task timeout: `300000 ms`
- Transport: `ollama-chat`
- Think: `false`

Qwen3.6 passed `4/7`.

| Task | Result | Failure class | Notes |
| --- | --- | --- | --- |
| `backend-api` | fail | verifier | Tax/discount semantics wrong. |
| `multi-file-cart` | pass | pass | Clean verifier pass. |
| `schema-validation` | fail | verifier | Missed a required invalid-config exception. |
| `cli-report` | pass | pass | Clean verifier pass. |
| `frontend-filter` | fail | verifier | Did not fully match owner/status case-insensitively. |
| `failing-command-recovery` | pass | pass | Clean verifier pass. |
| `sandbox-canary` | pass | pass | Clean verifier pass and canary unchanged. |

Aggregate:

| Metric | Value |
| --- | ---: |
| Passes | `4/7` |
| Timeouts | `0` |
| Allowlist violations | `0` |
| Avg output TPS | `40.60` |
| Avg wall output TPS | `35.49` |
| Avg output tokens | `590.3` |

## Kebab Result

Kebab settings:

- Provider: `ollama-windows`
- Model: `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M`
- Context length: `16384`
- Max tokens: `8192`
- Think: `false`

Result:

| Metric | Value |
| --- | ---: |
| Runtime | `146.0 s` |
| Automatic code-feature score | `8/8` |
| Manual visual score | `0/5` |

The screenshot rendered as a nearly uniform dark canvas. Static inspection of
the generated HTML points to a JavaScript error in texture setup, so the
automatic code-feature score is misleading here.

## Decision

Do not update the promoted dashboard/default recommendation from this run.

Reasons:

- Qwen3.6 is operationally runnable but only reached `4/7` on the direct
  real-usage matrix.
- Kebab was a visual failure.
- GLM-5.1 exact full-model local benchmarking is blocked by fit, not completed.
- No new runner, memory, or endpoint recommendation was proven.

Useful follow-up:

- If Qwen3.6 remains interesting, run a two-attempt repair pass only on
  `backend-api`, `schema-validation`, and `frontend-filter`.
- Revisit GLM-5.1 only after adding enough model-cache disk space for at least
  the `147.30 GiB` `IQ1_S` route plus overhead, or after identifying a runtime
  route that does not require full local GGUF storage.

## Cleanup Audit

- `ollama stop hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` was run.
- `ollama ps` was empty after a short wait.
- Docker Desktop API was not running.
- WSL exact-name checks found no `llama-server` or `llama-bench`.
- User `.wslconfig` was absent.
- `C:` free space after run was about `94.70 GiB`.
