# Phase 08 Multi-Model Matrix Report

Date: 2026-06-21

## Scope

This phase reruns the WSL ROCm llama.cpp path against additional local GGUF models that were already present under LM Studio model storage. No new model downloads were performed.

Durable outputs are still written to the Windows workspace. WSL commands run from `/mnt/c/path/to/locallm_ryzen395`, so the results appear under this repository folder.

## Local Models Found

| Model | GGUF Size | Status |
| --- | ---: | --- |
| Qwen3 Coder 30B A3B Q4_K_M | `17.35 GB` | Benchmarked |
| Qwen3 Coder 30B A3B Q2_K | `10.49 GB` LM Studio copy; existing benchmark used workspace copy around `11.26 GB` | Benchmarked earlier |
| Gemma 4 E4B IT Q4_K_M | `4.97 GB` | Load failed in AMD llama.cpp build |
| Qwen2.5-Coder 1.5B Q8_0 | `1.53 GB` | Benchmarked |
| Qwen2.5-Coder 1.5B Q4_K_M | `0.92 GB` | Benchmarked |
| Qwen3 0.6B Q4_K_M | `0.37 GB` | Not benchmarked; too small to change the default decision |

## Runner

New repeatable wrapper:

- `scripts/run-wsl-model-matrix.ps1`

The wrapper starts one WSL llama.cpp server per model, runs OpenAI-compatible calibration, optionally runs one or more controlled edit-agent tasks, stops the server, and writes summaries under `../results/`.

One early wrapper run failed before benchmarking because a Bash `cd` command missed `&&`; that failed run is preserved at `../results/20260621-223616-model-matrix/model-matrix-summary.json` as harness-debug evidence.

## Results

| Model | Task | Runtime Result | Agent Result | Browser Result | Key Artifact |
| --- | --- | ---: | --- | --- | --- |
| Qwen3 Coder 30B Q4 | calibration | `57.56 tok/s`, first content `356.7 ms` | n/a | n/a | `../results/20260621-223758-model-matrix/qwen3-coder-30b-q4-calibration-single.json` |
| Qwen3 Coder 30B Q4 | 4-way calibration | `96.27 tok/s` aggregate, first content min `373.2 ms` | n/a | n/a | `../results/20260621-225403-model-matrix/qwen3-coder-30b-q4-calibration-4way.json` |
| Qwen3 Coder 30B Q4 | `js-window` | same server | PASS, first content `1555.9 ms`, wall `5791.2 ms` | n/a | `../results/20260621-223758-model-matrix/qwen3-coder-30b-q4-js-window/js-window-result.json` |
| Qwen3 Coder 30B Q4 | `browser-style` | `56.57 tok/s`, first content `687.6 ms` | PASS, first content `1909.8 ms`, wall `3555.6 ms` | PASS | `../results/20260621-224242-model-matrix/qwen3-coder-30b-q4-browser-style/browser-style-result.json` |
| Qwen3 Coder 30B Q2 | `js-window` | `70.20 tok/s`, first content `752.9 ms` | PASS, first content `1137.9 ms`, wall `5825 ms` | n/a | `../results/20260621-221417-controlled-js-window-lineendings/js-window-result.json` |
| Qwen3 Coder 30B Q2 | `browser-style` | same server | PASS, first content `2125.2 ms`, wall `3730.1 ms` | PASS | `../results/20260621-222232-controlled-browser-style-protected/browser-style-result.json` |
| Qwen2.5-Coder 1.5B Q4 | `js-window` | `116.07 tok/s`, first content `118.6 ms` | FAIL, syntax-invalid edit after two attempts | n/a | `../results/20260621-223702-model-matrix/qwen25-coder-15b-q4-js-window/js-window-result.json` |
| Qwen2.5-Coder 1.5B Q8 | `js-window` | `76.99 tok/s`, first content `213.5 ms` | FAIL, syntax-invalid edit after two attempts | n/a | `../results/20260621-224107-model-matrix/qwen25-coder-15b-q8-js-window/js-window-result.json` |
| Gemma 4 E4B IT Q4 | load | FAIL | n/a | n/a | `logs/20260621-223702-model-matrix/gemma-4-e4b-q4/llama-server.log` |

## GPU Memory Evidence

The Qwen3 Coder 30B Q4 4-way server log records the following runtime memory facts:

| Measure | Value |
| --- | ---: |
| Visible ROCm VRAM pool | `67226 MiB` |
| Projected device memory use | `18281 MiB` |
| ROCm model buffer | `17596.43 MiB` |
| ROCm KV buffer | `384.00 MiB` |
| Context | `4096` total, `1024` per slot |
| Slots | `4` |

Artifact: `logs/20260621-225403-model-matrix/qwen3-coder-30b-q4/llama-server.log`

Gemma failure reason:

```text
unknown model architecture: 'gemma4'
```

## Decision

Qwen3 Coder 30B Q4 is the quality default for the controlled local coding workflow. It fits inside the current WSL memory cap, passes both the code edit and protected frontend task, passed real browser verification, and now has a 4-way throughput measurement.

Qwen3 Coder 30B Q2 remains the faster fallback. It has better decode throughput and also passes the protected tasks, but Q4 is the more defensible default when quality is prioritized and outlet power is available.

Qwen2.5-Coder 1.5B is useful only as a latency control. Both Q4 and Q8 variants were fast but failed the basic `js-window` task by creating syntactically broken edits.

The current `65 GB` WSL cap is enough for the Q4 and Q2 30B-class short-context profiles. The evidence does not prove that `65 GB` is required. The next useful memory experiment is a cap sweep at `65 GB`, `48 GiB`, and `32 GiB`.
