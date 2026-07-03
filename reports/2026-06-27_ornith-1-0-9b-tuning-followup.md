# Ornith 1.0 9B Local Tuning Follow-Up

Date: 2026-06-27

## Outcome

Best practical local setup found for `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M`:

- Real-usage direct edits: Ollama native `/api/chat`, `think=false`, 16k context, 8192 output ceiling, `temperature=0.2`, 3 attempts, tightened verifier-repair prompt.
- Kebab benchmark: Ollama `/api/generate`, 16k context, 8192 output ceiling, `temperature=0.2`, `top_p=0.9`, explicit final-answer and viewport framing guidance, plus `<think>` stripping before HTML extraction.

This fixes the avoidable runner/config failures. It does not make Ornith-1.0-9B Q4_K_M broadly reliable for the full real-usage coding suite. The best real-usage result was 2/7. The best Kebab result was 8/8 automatic code features with manual visual score 3/5.

## Why The Early Runs Were Bad

1. Ornith is a reasoning model. The Hugging Face model card says responses normally start with `<think>...</think>` unless the server separates reasoning content. Ollama's OpenAI-compatible endpoint exposed reasoning in ways the original benchmark parser did not handle, causing apparent empty outputs and no useful edits.
2. Native Ollama `/api/chat` with `think=false` suppresses reasoning cleanly for JSON-edit tasks. This removed parse failures and made failures real verifier failures instead.
3. Ollama `/api/generate` ignored `think=false` for Kebab, but the benchmark can now strip leading `<think>` text before extracting HTML. With a larger output ceiling and framing prompt, the HTML completed and rendered.
4. A Windows long-path issue in the direct-matrix wrapper caused a false runner failure while writing logs. The wrapper now writes logs with `\\?\` long-path-safe file calls.
5. The remaining real-usage failures are model/task failures: wrong discount/tax math, missed validation exceptions, wrong CLI output behavior, and cart discount logic. These are not parse, timeout, canary, allowlist, or silly config failures in the tuned Q4 run.

## Changes Made

- `benchmarks/real-usage-agent-benchmark/scripts/real-usage-suite.mjs`
  - Added `<think>` stripping before JSON parsing.
  - Added native Ollama `/api/chat` transport with `--transport ollama-chat` and `--think`.
  - Captures separated reasoning fields from OpenAI-compatible streaming.
  - Strengthened the generic repair prompt so verifier actual/expected output is used on later attempts.
- `benchmarks/real-usage-agent-benchmark/scripts/run-ollama-direct-matrix.ps1`
  - Added transport, temperature, think, and prompt-extra parameters.
  - Added `top_p` and `top_k` parameters for native Ollama sampling experiments.
  - Hardened log writing for Windows long paths.
- `benchmarks/kebab-benchmark/scripts/run-kebab-benchmark.mjs`
  - Added context length, think, Ollama API selection, and prompt-extra controls.
  - Added `<think>` stripping before HTML extraction.
  - Added native `/api/chat` option for comparison.

## Real-Usage Evidence

| Setup | Model | Passes | Avg TPS | Avg wall TPS | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| Original Ollama `/v1` | Q4_K_M | 1/7 | 42.93 | 17.18 | High apparent TPS but reasoning/content handling caused empty or wasted outputs. |
| Native `/api/chat`, 2 attempts | Q4_K_M | 1/7 | 17.74 | 15.85 | Clean JSON path, but only `sandbox-canary` passed. |
| Tuned native `/api/chat`, 3 attempts | Q4_K_M | 2/7 | 19.21 | 16.57 | Best real-usage setup. `frontend-filter` and `failing-command-recovery` passed. |
| Tuned native `/api/chat`, 3 attempts | Q5_K_M | 1/7 | 16.67 | 15.32 | Higher quant was slower and did not improve reliability. |
| Model-card sampling native `/api/chat`, 3 attempts | Q4_K_M | 1/7 | 19.42 | 16.48 | `temperature=0.6`, `top_p=0.95`, `top_k=20`; clean protocol, worse pass rate. |

Rollup: [2026-06-27-ornith-tuning-real-usage-rollup.md](../benchmarks/real-usage-agent-benchmark/reports/2026-06-27-ornith-tuning-real-usage-rollup.md)

Best Q4 matrix summary:
`benchmarks/real-usage-agent-benchmark/results/20260627-092710-ollama-ornith-tuned-r3-direct-matrix/ollama-direct-api-matrix-summary.json`

Q5 matrix summary:
`benchmarks/real-usage-agent-benchmark/results/20260627-095010-ollama-ornith-q5-tuned-r3-direct-matrix/ollama-direct-api-matrix-summary.json`

Model-card sampling matrix summary:
`benchmarks/real-usage-agent-benchmark/results/20260627-101831-ollama-ornith-q4-card-sampling-r3-direct-matrix/ollama-direct-api-matrix-summary.json`

## Kebab Evidence

Best run:

- Run id: `20260627-ornith-9b-q4km-kebab-generate-framed-8192`
- Endpoint: Ollama `/api/generate`
- Context: 16384
- Output ceiling: 8192
- Sampling: `temperature=0.2`, `top_p=0.9`
- Result: 8/8 automatic code features, 245.0s, 4698 eval tokens, 19.22 tok/s
- Manual visual score: 3/5

Report: [2026-06-27-ornith-9b-q4km-kebab-tuned.md](../benchmarks/kebab-benchmark/reports/2026-06-27-ornith-9b-q4km-kebab-tuned.md)

Earlier Kebab failure modes:

- `/api/chat`, 4096 tokens: no `<think>`, but truncated into a blank render.
- `/api/chat`, 8192 tokens: transport failed with `fetch failed`.
- `/api/generate`, 4096 tokens: rendered, but raw output leaked `<think>` and HTML was incomplete.

## Runner Findings

- OpenCode through Ollama `/v1` is not recommended for this model in the current setup. A backend-api pilot ran for 313s, produced 4096 output tokens, made 0 tool calls, and failed verification.
- Pi Docker was not runnable because Docker Desktop's Linux engine was not available.
- Q5_K_M did not help. It passed fewer real-usage tasks than Q4_K_M and ran slower.
- `think=true` on native `/api/chat` was not practical for backend-api: two attempts took about 285s and still failed basic semantics.
- Model-card sampling (`temperature=0.6`, `top_p=0.95`, `top_k=20`) did not help in this direct-edit harness. It completed cleanly and parsed from final content, but fell to 1/7.

## Recommendation

For this host and benchmark harness, keep Ornith-1.0-9B Q4_K_M as a visual/demo or simple-edit candidate, not as the promoted local coding-agent model. The tuned runner is now clean enough that failures are meaningful, but the model still misses too many small coding tasks.

If continuing Ornith work, the next fair experiment should be a runtime aligned with the model card: vLLM or SGLang with the Qwen3 reasoning parser and tool-call parser, or a recent llama.cpp server with a long context. The model-card sampling values alone (`temperature=0.6`, `top_p=0.95`, `top_k=20`) were tested through native Ollama and did not improve the direct-edit benchmark, so the remaining untested difference is serving/runtime behavior, not just sampler settings.

Sources:

- https://huggingface.co/deepreinforce-ai/Ornith-1.0-9B
- https://huggingface.co/deepreinforce-ai/Ornith-1.0-9B-GGUF
