# Kimi and DeepSeek Fit Benchmark First Pass

Date: 2026-06-24

## Summary

This first pass adds current DeepSeek and Kimi candidates to the local
inference benchmark evidence.

The practical result is mixed:

- DeepSeek R1 8B fits and runs on Windows Ollama, WSL Ollama, and LM Studio.
  It is healthy as an endpoint, but it is a poor fit for the current direct-edit
  real-usage harness at the default 4096-token cap because it spends nearly the
  whole budget in reasoning and exposes no actionable final content.
- DeepSeek R1 32B fits and runs on Windows and WSL Ollama, but short smokes are
  already several minutes. Treat it as overnight or small-probe material before
  attempting full real-usage matrices.
- Kimi K2 Thinking is the newest Kimi family checked, but its available GGUF
  sizes do not fit this PC. The smallest K2 Thinking GGUF variants are hundreds
  of GB.
- Kimi-Dev-72B `UD-IQ2_XXS` is the first fit-aware Kimi candidate. It loads on
  Windows and WSL Ollama, but trivial smokes are already too slow for daytime
  real-usage lanes and did not reach final content. LM Studio can target the
  exact GGUF file, but the download rate made that path overnight-only in this
  pass.

This does not replace the current promoted Qwen/Gemma guidance. It adds
negative and fit-boundary evidence for Kimi/DeepSeek.

## Source Decisions

Current Kimi source pages checked:

- [moonshotai/Kimi-K2-Thinking](https://huggingface.co/moonshotai/Kimi-K2-Thinking)
- [unsloth/Kimi-K2-Thinking-GGUF](https://huggingface.co/unsloth/Kimi-K2-Thinking-GGUF)
- [moonshotai/Kimi-Dev-72B](https://huggingface.co/moonshotai/Kimi-Dev-72B)
- [unsloth/Kimi-Dev-72B-GGUF](https://huggingface.co/unsloth/Kimi-Dev-72B-GGUF)

Kimi K2 Thinking is a 1T-parameter MoE with 32B activated parameters and a 256K
context window, but the smallest GGUF variants listed for K2 Thinking are about
247 GB to 285 GB. That is beyond the practical local target for this PC.

Kimi-Dev-72B is the practical Kimi candidate because the GGUF card lists 73B
parameters with lower quantizations that fit local storage and memory:

| Candidate | Listed Size | Decision |
| --- | ---: | --- |
| Kimi K2 Thinking 1-bit GGUF | 247 GB or larger | Non-fit |
| Kimi-Dev-72B `UD-IQ1_S` | 23 GB | Fits, lower quality |
| Kimi-Dev-72B `UD-IQ2_XXS` | 25.7 GB | First runnable Kimi choice |
| Kimi-Dev-72B 4-bit variants | 39.7 GB or larger | Might fit memory, likely too slow for daytime runs |

Current DeepSeek source pages checked earlier in this pass:

- [DeepSeek R1 Ollama library](https://ollama.com/library/deepseek-r1)
- [deepseek-ai/DeepSeek-R1-0528-Qwen3-8B](https://huggingface.co/deepseek-ai/DeepSeek-R1-0528-Qwen3-8B)
- [lmstudio-community/DeepSeek-R1-0528-Qwen3-8B-GGUF](https://huggingface.co/lmstudio-community/DeepSeek-R1-0528-Qwen3-8B-GGUF)
- [deepseek-ai/DeepSeek-V3.2](https://huggingface.co/deepseek-ai/DeepSeek-V3.2)
- [unsloth/DeepSeek-V3.2-GGUF](https://huggingface.co/unsloth/DeepSeek-V3.2-GGUF)

Full DeepSeek V3.2 is not a practical local fit here, so this pass uses the
fit-aware R1 distilled/quantized lanes.

## Installed Models

Windows Ollama now has:

| Model | Size |
| --- | ---: |
| `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | 25 GB |
| `deepseek-r1:32b` | 19 GB |
| `deepseek-r1:8b` | 5.2 GB |
| `qwen3-coder:30b` | 18 GB |
| `gemma3:12b` | 8.1 GB |
| `gemma3n:e4b` | 7.5 GB |

WSL Ollama now has:

| Model | Size |
| --- | ---: |
| `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | 25 GB |
| `deepseek-r1:32b` | 19 GB |
| `deepseek-r1:8b` | 5.2 GB |
| `qwen3-coder:30b` | 18 GB |
| `gemma3:12b` | 8.1 GB |
| `gemma3n:e4b` | 7.5 GB |

LM Studio now has:

| Model | Size |
| --- | ---: |
| `deepseek-r1-0528-qwen3-8b` Q4_K_M GGUF | 5.03 GB |

## DeepSeek R1 8B Ollama Direct Evidence

Rollup:

- Markdown:
  `benchmarks/real-usage-agent-benchmark/reports/2026-06-24-kimi-deepseek-ollama-direct-rollup.md`
- JSON:
  `benchmarks/real-usage-agent-benchmark/reports/2026-06-24-kimi-deepseek-ollama-direct-rollup.json`

Windows Ollama matrix:

- Summary:
  `benchmarks/real-usage-agent-benchmark/results/20260624-190108-ollama-windows-deepseek-r1-8b-direct-matrix/ollama-direct-api-matrix-summary.json`
- Tasks: `backend-api`, `schema-validation`, `frontend-filter`
- Attempts: 2 per task
- Result: 0/3 passed
- Average observed generation speed while producing reasoning-only output:
  22.92 tokens/s
- Failure class: no actionable content reached before the 4096-token cap

WSL Ollama reduced lane:

- Summary:
  `benchmarks/real-usage-agent-benchmark/results/20260624-192348-ollama-wsl-deepseek-r1-8b-direct-matrix/ollama-direct-api-matrix-summary.json`
- Task: `backend-api`
- Attempts: 1
- Result: 0/1 passed
- Observed generation speed while producing reasoning-only output:
  16.49 tokens/s
- Failure class: no actionable content reached before the 4096-token cap

Interpretation: the 8B Ollama endpoint is not broken. It streams tokens and is
measurable. The problem is harness fit: the real-usage direct-edit workflow
receives no final answer to apply.

## DeepSeek R1 8B LM Studio Evidence

Single-task LM Studio direct run:

- Summary:
  `benchmarks/real-usage-agent-benchmark/results/20260624-211431-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json`
- Model: `deepseek-r1-0528-qwen3-8b`
- Task: `backend-api`
- Result: 0/1 passed
- Load: succeeded in about 10.9 seconds
- Restore: succeeded; `lms ps --json` returned `[]` afterward
- Prompt tokens: 1374
- Completion tokens: 4096
- Reasoning tokens: 4094
- Wall time: about 145.2 seconds
- Reasoning-only speed: about 28.21 tokens/s

Interpretation: LM Studio is faster than the Ollama 8B lanes in this
reasoning-only failure mode, and it exposes the important accounting: almost
all generated tokens were reasoning tokens.

## DeepSeek R1 32B Ollama Smoke Evidence

Downloaded to both Windows and WSL Ollama:

- `deepseek-r1:32b`

Windows smoke:

- Prompt: final-answer-only `OK`
- Max tokens: 1024
- Result: final content returned
- Command wall time: about 288 seconds
- Usage: 12 prompt tokens, 178 completion tokens, 190 total tokens

WSL smoke:

- Prompt: final-answer-only `OK`
- Max tokens: 1024
- Result: final content returned
- Command wall time: about 257 seconds
- Usage: 12 prompt tokens, 261 completion tokens, 273 total tokens

Interpretation: 32B fits both environments and can produce final content, but
it is too slow for a standard daytime direct-edit matrix. The next useful 32B
step is a constrained throughput probe or an overnight single-task lane.

## Kimi-Dev 72B Windows Ollama Smoke Evidence

Downloaded to Windows Ollama:

- `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS`

Smoke:

- Endpoint: Windows Ollama
- Prompt: final-answer-only `OK`
- Max tokens: 256
- Result: load and inference completed
- Command wall time: about 339 seconds
- Usage: 17 prompt tokens, 256 completion tokens, 273 total tokens
- Finish reason: `length`
- Final requested answer was not reached

Interpretation: Kimi-Dev-72B `UD-IQ2_XXS` fits and loads on Windows Ollama, but
it is not practical for standard real-usage direct matrices on this hardware.

## Kimi-Dev 72B WSL Ollama Smoke Evidence

Downloaded to WSL Ollama:

- `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS`

Smoke:

- Endpoint: WSL Ollama on `127.0.0.1:11435`
- Prompt: final-answer-only `OK`
- Max tokens: 64
- Result: load and inference completed
- Command wall time: about 116.7 seconds
- Usage: 13 prompt tokens, 64 completion tokens, 77 total tokens
- Finish reason: `length`
- Final requested answer was not reached

Interpretation: WSL Ollama has the same practical boundary as Windows Ollama:
the model fits and runs, but it is too slow and too reasoning-heavy for the
standard daytime direct-edit benchmark.

## Kimi-Dev 72B LM Studio Install Attempt

LM Studio was checked for the same Kimi quant.

The selector form did not work:

```powershell
lms get "https://huggingface.co/unsloth/Kimi-Dev-72B-GGUF@UD-IQ2_XXS" --gguf -y
```

LM Studio selected a different `Q3_K_S` candidate and reported that it could
not find variant `UD-IQ2_XXS`.

The exact-file form did resolve the intended model:

```powershell
lms get "https://huggingface.co/unsloth/Kimi-Dev-72B-GGUF/resolve/main/Kimi-Dev-72B-UD-IQ2_XXS.gguf" --gguf -y
```

It identified `Kimi Dev 72B UD IQ2_XXS [GGUF]` at 25.70 GB, but the download
timed out after about 1551.6 seconds with only about 305 MB transferred and an
estimated remaining time above eight hours. `lms ls` afterward did not list a
Kimi model as installed.

Interpretation: LM Studio Kimi is technically targetable, but not practical for
this interactive benchmark pass. Treat it as an overnight download plus smoke
test if strict runtime symmetry is required later.

## Minor Notes Created

- `notes/2026-06-24_18-45-14_kimi-deepseek-benchmark-planning.md`
- `notes/2026-06-24_19-31-00_deepseek-r1-8b-ollama-first-pass.md`
- `notes/2026-06-24_21-20-00_deepseek-32b-and-lmstudio-8b-pass.md`
- `notes/2026-06-24_21-55-00_kimi-dev-72b-windows-ollama-smoke.md`
- `notes/2026-06-24_22-21-31_kimi-dev-72b-wsl-and-lmstudio-follow-up.md`

## Current Recommendation

Do not promote Kimi or DeepSeek over the existing Qwen/Gemma local-inference
guidance based on this pass.

Use this decision table for next steps:

| Candidate | Status | Next Practical Step |
| --- | --- | --- |
| DeepSeek R1 8B, Ollama | Runs, no actionable output in direct harness at 4096 tokens | Keep as negative harness-fit evidence |
| DeepSeek R1 8B, LM Studio | Runs faster, exposes reasoning-token accounting | Use only if a non-reasoning harness/profile is added |
| DeepSeek R1 32B, Ollama | Fits and smokes on Windows/WSL, very slow | Overnight single-task or small throughput probe |
| Kimi K2 Thinking | Latest Kimi family, non-fit at GGUF sizes | Do not run locally on this PC |
| Kimi-Dev-72B `UD-IQ2_XXS` | Fits and smokes on Windows and WSL Ollama, very slow; LM Studio exact download timed out far short of completion | Overnight-only LM Studio symmetry or full task lane if needed |

## Open Follow-Ups

- Try an overnight `backend-api` lane for DeepSeek R1 32B or Kimi-Dev-72B with
  larger token/time budgets.
- Resume the exact LM Studio Kimi-Dev-72B `UD-IQ2_XXS` download only if strict
  runtime symmetry is worth the overnight transfer and extra disk use.
- Investigate whether the harness should preserve and inspect reasoning output
  for reasoning models, while still requiring final actionable content for a
  pass.
- Update the WSL/local-inference dashboard after deciding whether these
  candidates should be added to the promoted model guidance or only to the
  known-limits section.
