# Ornith 1.0 9B Q4_K_M Local Benchmark

Created: 2026-06-27 07:55 Europe/Warsaw

## Summary

Pulled and benchmarked `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` through Windows Ollama.

Result: not recommended for the current Ollama direct-edit harness. It passed `1/7` real-usage tasks and failed Kebab visually because the reasoning trace was exposed as normal output.

## Source Check

Current model sources checked:

- Base model: `deepreinforce-ai/Ornith-1.0-9B`
- GGUF model: `deepreinforce-ai/Ornith-1.0-9B-GGUF`

The Hugging Face API reported:

| Repo | Created | Last modified | Notes |
| --- | --- | --- | --- |
| `deepreinforce-ai/Ornith-1.0-9B` | `2026-06-21T04:27:07Z` | `2026-06-25T14:08:32Z` | MIT, `text-generation`, tags include `qwen3_5` and `eval-results`. |
| `deepreinforce-ai/Ornith-1.0-9B-GGUF` | `2026-06-25T04:56:13Z` | `2026-06-25T14:12:12Z` | GGUF repo containing `ornith-1.0-9b-Q4_K_M.gguf`, `Q5_K_M`, `Q6_K`, `Q8_0`, and bf16 GGUF. |

The model card says Ornith-1.0-9B is the lightweight member of the Ornith family for efficient single-GPU deployment, and it is a reasoning model whose replies open with `<think>...</think>` unless the serving stack separates reasoning content.

Sources:

- https://huggingface.co/deepreinforce-ai/Ornith-1.0-9B
- https://huggingface.co/deepreinforce-ai/Ornith-1.0-9B-GGUF

## Pull

Drive-space gate:

| Check | Value |
| --- | ---: |
| `C:` free before pull | `122.82 GB` |
| Pulled blob size | `5.6 GB` |
| `C:` free after pull | `117.13 GB` |

Command:

```powershell
ollama pull hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M
```

Pull completed successfully.

## Real-Usage Benchmark

Command shape:

```powershell
.\benchmarks\real-usage-agent-benchmark\scripts\run-ollama-direct-matrix.ps1 `
  -Models hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M `
  -Tasks backend-api,multi-file-cart,schema-validation,cli-report,frontend-filter,failing-command-recovery,sandbox-canary `
  -BaseUrl http://127.0.0.1:11434/v1 `
  -EndpointName windows-ornith-9b-q4km `
  -MaxAttempts 1 `
  -MaxTokens 4096 `
  -ContextLength 16384 `
  -TaskTimeoutMs 300000
```

Result:

| Task | Pass |
| --- | --- |
| `backend-api` | no |
| `multi-file-cart` | no |
| `schema-validation` | no |
| `cli-report` | yes |
| `frontend-filter` | no |
| `failing-command-recovery` | no |
| `sandbox-canary` | no |

Rollup:

| Metric | Value |
| --- | ---: |
| Passes | `1/7` |
| Avg TTFT | `39116.6 ms` |
| Avg output TPS | `42.93` |
| Avg wall output TPS | `17.18` |
| Avg output tokens | `1922.9` |

## Kebab Benchmark

The standard `8192` token Kebab attempt failed with `fetch failed`. A direct short Ollama generate smoke succeeded immediately afterward, so the promoted Kebab run used a smaller output cap:

```powershell
node .\benchmarks\kebab-benchmark\scripts\run-kebab-benchmark.mjs `
  --run-id 20260627-ornith-9b-q4km-kebab-2048 `
  --providers ollama-windows `
  --models hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M `
  --max-tokens 2048 `
  --timeout-seconds 900 `
  --temperature 0.2 `
  --top-p 0.9 `
  --keep-alive 10m
```

Result:

| Metric | Value |
| --- | ---: |
| Status | completed |
| Runtime | `108.9 s` |
| Automatic code-feature score | `6/8` |
| Manual visual score | `0/5` |

Manual visual note: screenshot rendered the model's `<think>` planning text rather than a canvas kebab scene. The automatic feature score is misleading for this reasoning-model output path.

## Interpretation

The local benchmark result is much weaker than the model card's agentic-coding claims in this specific setup. The main reason appears to be serving/protocol mismatch, not just base model capability: the card recommends runtimes with a reasoning parser and tool-call parser. The current Ollama direct harness receives raw reasoning text and does not expose parsed tool calls.

For a fairer follow-up, test Ornith through a vLLM or SGLang OpenAI-compatible server with the recommended `qwen3` reasoning parser and `qwen3_xml` / `qwen3_coder` tool parser, then rerun the same real-usage and Kebab prompts.

## Artifacts

| Artifact | Path |
| --- | --- |
| Real-usage matrix | `benchmarks/real-usage-agent-benchmark/results/20260627-072603-ollama-windows-ornith-9b-q4km-direct-matrix/ollama-direct-api-matrix-summary.json` |
| Real-usage rollup | `benchmarks/real-usage-agent-benchmark/reports/2026-06-27-ornith-9b-q4km-real-usage-rollup.md` |
| Kebab report | `benchmarks/kebab-benchmark/reports/2026-06-27-ornith-9b-q4km-kebab.md` |
| Kebab screenshot | `benchmarks/kebab-benchmark/results/20260627-ornith-9b-q4km-kebab-2048/runs/ollama-windows__hf.co_deepreinforce-ai_Ornith-1.0-9B-GGUF_Q4_K_M/screenshot.png` |
| Kebab failed standard attempt | `benchmarks/kebab-benchmark/results/20260627-ornith-9b-q4km-kebab/summary.json` |
