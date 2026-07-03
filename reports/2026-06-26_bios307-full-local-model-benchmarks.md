---
title: BIOS 307 full local model benchmark rerun
date: 2026-06-26
tags:
  - local-inference
  - benchmark
  - bios
  - ollama
  - lmstudio
  - kebab
---

# BIOS 307 full local model benchmark rerun

Finalized: 2026-06-27 00:09 Europe/Warsaw.

## Summary

After the BIOS update to `HN7306EA.307`, I reran the broad local model set
through the direct API real-usage benchmark and the Kebab visual benchmark.

Main result: no dashboard default should change from this evidence alone.
Windows Ollama Qwen3-Coder-Next remains the only family with broad verifier
passes, but neither quant passed the full 7-task direct matrix. The best
first-pass real-usage score was Qwen3-Coder-Next `UD-Q2_K_XL` on Windows
Ollama at `5/7`. Qwen3-Coder-Next `UD-Q4_K_M` improved on the previous weak
backend gate and passed `backend-api`, but finished only `4/7`.

Kebab did not produce a strong realistic result. The best visual was Windows
Ollama `qwen3-coder:30b`, with a recognizable skewer/flame scene but no
layered realistic doner stack.

## Evidence

- Step log:
  [notes/2026-06-26_23-59-00_bios307-full-benchmark-rerun.md](../public-results/results-summary.md)
- Real-usage rollup:
  [benchmarks/real-usage-agent-benchmark/reports/2026-06-26-bios307-full-direct-rollup.md](../benchmarks/real-usage-agent-benchmark/reports/2026-06-26-bios307-full-direct-rollup.md)
- Kebab rollup:
  [benchmarks/kebab-benchmark/reports/2026-06-26-bios307-kebab-full-run.md](../benchmarks/kebab-benchmark/reports/2026-06-26-bios307-kebab-full-run.md)
- Kebab contact sheet:
  [benchmarks/kebab-benchmark/results/20260626-2300-bios307-full/contact-sheet.png](../public-results/results-summary.md)
- Host preflight:
  [benchmarks/wsl-local-inference-benchmark/results/20260626-195200-preflight/host-preflight.json](../public-results/results-summary.md)

## Host State

| Item | Value |
| --- | --- |
| BIOS | `HN7306EA.307` |
| OS | Windows 11 Pro `10.0.26200` |
| RAM | `132,766,306,304` bytes physical |
| WSL distro | `Ubuntu-24.04`, WSL2 |
| WSL visible memory | `63,594,152 kB` |
| WSL swap | `16,777,216 kB` |
| WSL GPU device | `/dev/dxg` present |
| WSL Ollama `11435` | unreachable |
| Docker Desktop API | not running |

## Real-Usage Results

All direct matrix rows used the full 7-task manifest, `16k` context,
`MaxAttempts=1`, `MaxTokens=4096`, and a `300 s` task timeout.

| Provider | Model | Passes | Notes |
| --- | --- | ---: | --- |
| Windows Ollama | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | 5/7 | Best broad first-pass result; failed `backend-api` and `schema-validation`. |
| Windows Ollama | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | 4/7 | Passed `backend-api`, `multi-file-cart`, `cli-report`, and recovery; failed schema, frontend, and sandbox. |
| LM Studio | `google/gemma-4-12b` | 3/7 | Passed `multi-file-cart`, `cli-report`, and recovery with `reasoning_effort=none`; failed backend, schema, frontend, sandbox. |
| Windows Ollama | `deepseek-r1:32b` | 1/7 | Passed only sandbox; very slow first-content behavior. |
| Windows Ollama | `qwen3-coder:30b` | 1/7 | Passed only `multi-file-cart`. |
| LM Studio | `qwen/qwen3-coder-next` | 1/7 | Passed only sandbox; generated no fixture edits for most rows. |
| All other tested LM Studio/Ollama lanes | 0/7 | Either no useful edits, no metrics, or reasoning output hit the token cap. |

Interpretation:

- The BIOS update did not create a clean all-task winner.
- Qwen3-Coder-Next Q4 has a meaningful positive signal: the direct API
  `backend-api` row passed in one attempt where previous follow-up evidence
  was negative.
- Qwen3-Coder-Next Q2 remains the better broad first-pass direct API lane.
- LM Studio was generally worse for direct edit extraction in this harness:
  many rows produced content but no applyable edits, so they scored as
  `no-edit`.
- Reasoning models tended to spend output budget without creating usable final
  edits.

## Kebab Results

Kebab run: `benchmarks/kebab-benchmark/results/20260626-2300-bios307-full/`.

| Rank | Provider | Model | Time | Visual | Notes |
| ---: | --- | --- | ---: | ---: | --- |
| 1 | Windows Ollama | `qwen3-coder:30b` | 247s | 3/5 | Recognizable skewer/flame scene with controls, but simplified ring-like meat and no realistic layered doner stack. |
| 2 | LM Studio | `google/gemma-4-12b` | 188s | 2/5 | Abstract meat/flame composition, visually nonblank, but geometry is not a realistic vertical rotisserie. |
| 3 | LM Studio | `qwen/qwen3-coder-30b` | 92s | 2/5 | Small labeled scene with skewer/flame elements, but tiny and schematic. |
| 4 | LM Studio | `unsloth/qwen3-coder-30b-a3b-instruct` | 53s | 2/5 | Vertical rod and colored objects, but weak kebab/heater semantics. |
| 5 | LM Studio | `google/gemma-4-e4b` | 97s | 1/5 | Small flame and fragments; not a coherent kebab scene. |
| 6 | Windows Ollama | `gemma3:12b` | 171s | 1/5 | Vertical rod and base only; no convincing meat stack or heater. |

All other Kebab rows were failed, blank, text-only, or near-empty and score
`0/5`. WSL Ollama was provider-unreachable on `127.0.0.1:11435`.

## Decision

Do not update the promoted dashboard recommendation from this run. The broad
evidence still favors keeping the existing promoted local stack until a
higher-confidence runner/model lane passes both backend and multi-task gates.

Useful follow-up:

- Rerun only Qwen3-Coder-Next `UD-Q4_K_M` direct `backend-api` plus
  `schema-validation` with two attempts to see whether the backend pass is
  stable.
- Run OpenCode/Pi only for Qwen3-Coder-Next `UD_Q2_K_XL` and `UD_Q4_K_M` if
  the goal is agent-runner evidence rather than broad model screening.
- Keep WSL Ollama out of comparison tables until the `11435` endpoint is
  intentionally started and confirmed reachable.
