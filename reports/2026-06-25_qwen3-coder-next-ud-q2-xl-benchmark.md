# Qwen3-Coder-Next UD-Q2 XL Benchmark

Date: 2026-06-25

## Summary

Qwen3-Coder-Next was benchmarked through the local Ollama
OpenAI-compatible endpoint as
`hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL`. This is an exact
Qwen3-Coder-Next run, but it is a `26 GB` 2-bit XL GGUF quant rather than a
Q4/Q8 quality result.

Bottom line: it is usable for small coding tasks, but it is not a promotion
candidate from this evidence. The strongest result was the controlled edit-agent
lane at `2/2` first-attempt passes. The broader real-usage direct API lane
passed `5/7`, with meaningful failures in tax logic and schema validation.

## Result Matrix

| Benchmark lane | Result | Key reading | Durable report |
| --- | --- | --- | --- |
| Smoke calibration | pass | cold-load first content `66516.7 ms`, decode estimate `19.58 tok/s` | [Phase 26](../benchmarks/wsl-local-inference-benchmark/reports/phase-26-qwen3-coder-next-ollama-ud-q2-xl.md) |
| Controlled edit-agent | `2/2` pass | first-attempt fixes for `js-window` and `browser-style` | [Phase 26](../benchmarks/wsl-local-inference-benchmark/reports/phase-26-qwen3-coder-next-ollama-ud-q2-xl.md) |
| Real-usage direct API | `5/7` pass | no timeouts or canary breach, but two semantic verifier failures | [Real-usage rollup](../benchmarks/real-usage-agent-benchmark/reports/2026-06-25-qwen3-coder-next-ud-q2-xl-real-usage.md) |
| Kebab canvas prompt | completed, `8/8` code features | functional animated canvas, moderate visual realism | [Kebab report](../benchmarks/kebab-benchmark/reports/2026-06-25-qwen3-coder-next-ud-q2-xl-kebab.md) |

## Model And Endpoint

The model identity and quant choice were checked against the official Qwen model
card, Unsloth GGUF packaging, LM Studio listing, and Ollama listing:

- Qwen model card: https://huggingface.co/Qwen/Qwen3-Coder-Next
- Unsloth GGUF package: https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF
- LM Studio listing: https://lmstudio.ai/models/qwen/qwen3-coder-next
- Ollama listing: https://ollama.com/library/qwen3-coder-next

The model family is documented as an `80B` total MoE with about `3B` active
parameters and a `262144` token context window. This local pass used
`UD-Q2_K_XL` through Ollama because the Q4_K_M LM Studio artifact was not
locally available in time for the interactive run.

## Decision

Leave promoted local stack guidance unchanged. This run should be treated as a
first exact-model viability measurement, not a best-quality Qwen3-Coder-Next
evaluation.

The next high-value milestone is a Q4_K_M or better rerun of the real-usage and
controlled agent lanes, followed by Pi/OpenCode only if the stronger quant beats
this first pass cleanly.

## Cleanup Audit

- Ollama model was stopped after the run; `ollama ps` showed no loaded model.
- Docker had no running containers.
- WSL had no exact-name `llama-server` or `llama-bench` processes.
- No user `.wslconfig` was present.
