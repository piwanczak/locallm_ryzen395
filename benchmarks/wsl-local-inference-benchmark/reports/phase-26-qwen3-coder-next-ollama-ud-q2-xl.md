# Phase 26 - Qwen3-Coder-Next Ollama UD-Q2 XL

Date: 2026-06-25

## Scope

This phase benchmarks Qwen3-Coder-Next through the available local benchmark
lanes without changing benchmark definitions. The runnable endpoint was the
Windows Ollama OpenAI-compatible API:

- base URL: `http://127.0.0.1:11434/v1`
- model: `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL`
- local size: about `26 GB`
- benchmark context: `16384`

This is an exact Qwen3-Coder-Next model-family run, but it is not a Q4 or Q8
quality run. The LM Studio Q4_K_M artifact is about `48.5 GB`; a direct LM
Studio download was started, proved too slow for this interactive pass, and was
stopped before completion.

## Bottom Line

Qwen3-Coder-Next `UD-Q2_K_XL` is usable but not promotable from this run:

- real-usage direct API: `5/7` pass, no timeouts, no sandbox canary breach;
- controlled edit-agent: `2/2` pass on `js-window` and `browser-style`;
- Kebab canvas prompt: completed, automatic code feature score `8/8`, but manual
  visual realism is only moderate;
- throughput after load was around `18-19 tok/s` on these small tasks.

The failures are meaningful coding misses, not runner failures. Keep the
existing promoted local coding stack unchanged until a higher-quality quant and
full agent-lane runs beat it.

## Endpoint And Smoke

Evidence:

- Ollama pull log: `../../../logs/20260625-210239-qwen3-coder-next-ollama-pull`
- smoke calibration: `../results/20260625-211334-qwen3-coder-next-ollama-ud-q2-xl-smoke/openai-compatible-calibration.json`

The first smoke request succeeded. Because the model was cold-loaded, the first
content latency was `66516.7 ms`. The same request reported an aggregate decode
estimate of `19.58 tok/s`.

## Controlled Edit Agent

Evidence:

- run directory: `../results/20260625-212318-qwen3-coder-next-ollama-ud-q2-xl-controlled`

| Task | Attempts | Result | First content | Wall time | Output tokens | Modified file |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| `js-window` | 1 | pass | `2906.0 ms` | `8898.2 ms` | `114` | `src/windowCounter.mjs` |
| `browser-style` | 1 | pass | `4344.0 ms` | `9616.1 ms` | `100` | `app.js` |

Both tasks used JSON replacement edits, applied cleanly, and passed their local
verifiers. This is the strongest result in the run set: the model found the
small intended fixes on the first attempt.

## Real-Usage Direct API

Evidence:

- rollup report: `../../real-usage-agent-benchmark/reports/2026-06-25-qwen3-coder-next-ud-q2-xl-real-usage.md`
- matrix summary: `../../real-usage-agent-benchmark/results/20260625-211501-ollama-windows-qwen3-coder-next-ud-q2-xl-direct-matrix/ollama-direct-api-matrix-summary.json`

Aggregate:

- passes: `5/7`
- timeouts: `0`
- average TTFT: `4823.9 ms`
- average output throughput: `18.59 tok/s`
- average wall throughput: `16 tok/s`

Passed tasks: `multi-file-cart`, `cli-report`, `frontend-filter`,
`failing-command-recovery`, and `sandbox-canary`.

Failed tasks:

- `backend-api`: wrong tax calculation and missing `taxableCents`;
- `schema-validation`: invalid input did not raise the expected validation
  exception.

## Kebab Benchmark

Evidence:

- report: `../../kebab-benchmark/reports/2026-06-25-qwen3-coder-next-ud-q2-xl-kebab.md`
- screenshot: `../../kebab-benchmark/results/20260625-212346-qwen3-coder-next-ollama-ud-q2-xl-kebab/runs/ollama-windows__hf.co_unsloth_Qwen3-Coder-Next-GGUF_UD-Q2_K_XL/screenshot.png`

The run completed in `168.2 s` with automatic code feature score `8/8`.
Manual inspection found a functional animated canvas, but the visual result is
stylized and geometric rather than a realistic rotating doner skewer in front of
a gas heating element.

## Decision

Do not update the local-inference dashboard's promoted guidance from this pass.
The result is useful as a first exact-model data point and as a low-memory
viability check, but not as replacement evidence for Qwen3 Coder 30B Q4 or the
existing promoted stack.

Next useful steps:

- repeat real-usage and controlled tasks with Q4_K_M or better if the model is
  fully downloaded;
- run the Pi or OpenCode agent lanes only after the stronger quant is available;
- compare the same seven real-usage tasks against the current promoted local
  model under the same Ollama endpoint if an endpoint-level comparison is needed.
