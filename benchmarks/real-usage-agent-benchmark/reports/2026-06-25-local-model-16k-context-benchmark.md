# Local Model 16k Context Benchmark

Date: 2026-06-25

## Executive Summary

Best configuration in this pass:

| Rank | Configuration | Result |
| ---: | --- | --- |
| 1 | LM Studio `google/gemma-4-12b`, `32768` context, `reasoning_effort=none`, `parallel=1` | Best locally tested direct coding config in this run |
| 2 | LM Studio `google/gemma-4-12b`, `16384` context, `reasoning_effort=none`, `parallel=1` | Same clean behavior, slower first useful token in this run |
| 3 | WSL Ollama `qwen3-coder:30b`, requested `16384`, observed loaded context `262144` | Passed, but much slower first useful token |
| 4 | Windows Ollama `qwen3-coder:30b`, requested `16384` | Passed, but much slower first useful token |

The main result is not tokens/sec. The practical winner was the stack that made
the correct edit cleanly: LM Studio Gemma 4 12B. It passed the verifier at both
16k and 32k with a single replacement and no malformed edit JSON. The 32k run
was the best current row: `6.7 s` first useful token, `13.5 s` model wall time,
`13.7 s` wrapper task time, `19.97` output tok/s, and verifier pass.

Ollama Qwen passed on Windows and WSL, but both rows had very high first useful
token time because this run included cold load or large-context setup cost.
WSL Ollama also reported Qwen loaded at `262144` context after the run, so the
WSL result should be treated as `>=16k` large-context evidence rather than a
strict 16k-only row.

## Scope

This was a bounded direct API benchmark, not a full overnight agent leaderboard.

Primary verifier task:

- `frontend-filter`
- direct API JSON-edit harness
- one or two attempts depending on row
- requested context `16384`, with larger confirmation where useful

The task is small but useful because it catches a common local-coder failure:
changing only `row.textContent` and missing `row.dataset.owner` /
`row.dataset.status`.

## Endpoint Inventory

| Endpoint | Status |
| --- | --- |
| Windows Ollama | Reachable at `http://127.0.0.1:11434/v1`, Ollama `0.30.10` |
| WSL Ollama | Reachable at `http://127.0.0.1:11435/v1`, Ollama `0.30.10` |
| LM Studio | Reachable at `http://127.0.0.1:1234/v1`; no model loaded before/after wrapper rows |

Installed local model coverage included:

- Ollama: `qwen3-coder:30b`, `gemma3:12b`, `gemma3n:e4b`,
  `deepseek-r1:8b`, `deepseek-r1:32b`,
  `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS`.
- LM Studio: `qwen/qwen3-coder-30b`,
  `unsloth/qwen3-coder-30b-a3b-instruct`, `google/gemma-4-12b`,
  `google/gemma-4-e4b`, `qwen2.5-coder-1.5b-instruct@q4_k_m`,
  `qwen2.5-coder-1.5b-instruct@q8_0`,
  `deepseek-r1-0528-qwen3-8b`, `kimi-dev-72b`.

## Verified Task Results

| Endpoint | Model | Context | Attempts | Pass | First Useful Token | Task/Model Wall | Output TPS | Notes |
| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | --- |
| LM Studio | `google/gemma-4-12b` | `32768` | 1 | yes | `6.74 s` | `13.50 s` | `19.97` | Best row; clean edit, verifier pass |
| LM Studio | `google/gemma-4-12b` | `16384` | 1 | yes | `15.97 s` | `23.16 s` | `18.80` | Clean edit, verifier pass |
| WSL Ollama | `qwen3-coder:30b` | requested `16384`, observed `262144` | 1 | yes | `159.51 s` | `168.38 s` | `35.15` | Correct edit; large context loaded |
| Windows Ollama | `qwen3-coder:30b` | requested `16384` | 1 | yes | `211.86 s` | `224.07 s` | `36.78` | Correct edit; cold load cost dominated |
| LM Studio | `qwen/qwen3-coder-30b` | `16384` | 2 | no | `2.27-6.20 s` | `13.33-17.56 s` | `52.86-54.97` | Fast but malformed/incomplete edit JSON |
| LM Studio | `unsloth/qwen3-coder-30b-a3b-instruct` | `16384` | 2 | no | `1.83-4.03 s` | `11.68-13.61 s` | `62.66-63.68` | Faster smaller quant, same incomplete fix |
| Windows Ollama | `gemma3n:e4b` | requested `16384`, observed `32768` | 2 | no | `3.34 s` on attempt 2 | `6.89 s` on attempt 2 | `25.36` | Fast but failed verifier |
| WSL Ollama | `gemma3n:e4b` | requested `16384`, observed `32768` | 2 | no | `4.00 s` on attempt 2 | `8.04 s` on attempt 2 | `22.24` | Fast but failed verifier |
| LM Studio | `qwen2.5-coder-1.5b-instruct@q8_0` | `16384` | 2 | no | `0.55-0.65 s` | `2.99-4.04 s` | `84.09-96.75` | Extremely fast; still incomplete/wrong edit |
| LM Studio | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `16384` | 2 | no | `0.59-0.60 s` | `2.11-2.84 s` | `127.31-137.32` | Extremely fast; invalid JSON / wrong edit |
| LM Studio | `google/gemma-4-e4b` | `16384` | 2 | no | `2.06-2.83 s` with `reasoning_effort=none` | `55.74-56.93 s` | `37.86-38.15` | Non-JSON long output, no edit |
| LM Studio | `kimi-dev-72b` | `16384` | 2 | no | none | timed out twice at `300 s` | n/a | Tiny smoke was fast, task prompt was not |

Interpretation:

- Gemma 12B is the only LM Studio model that combined correctness and clean
  structured edit output.
- Qwen 30B is still the only Ollama model that passed the task, but the current
  direct API run had large first-token overhead.
- Smaller quant/smaller model lanes are good endpoint-speed checks, not good
  local coder defaults for this task.

## Heavy Model Smokes

Heavy and reasoning models were smoke-tested with `Return exactly OK.`,
`max_tokens=64` except LM Studio Kimi at `32`, requested `16384` context.

| Endpoint | Model | Smoke Result | First Byte | Visible Final Output | Notes |
| --- | --- | --- | ---: | --- | --- |
| Windows Ollama | `deepseek-r1:8b` | completed | `110.95 s` | no | Reasoning-only output, no visible `OK` |
| Windows Ollama | `deepseek-r1:32b` | timeout | n/a | no | Timed out at `180 s` |
| Windows Ollama | Kimi-Dev 72B `UD-IQ2_XXS` | timeout | n/a | no | Timed out at `180 s` |
| WSL Ollama | `deepseek-r1:8b` | completed | `20.68 s` | no | Reasoning-only output, no visible `OK` |
| WSL Ollama | `deepseek-r1:32b` | completed | `57.80 s` | no | Reasoning-only output, about `6.99` tok/s |
| WSL Ollama | Kimi-Dev 72B `UD-IQ2_XXS` | completed | `111.65 s` | yes, `OK` | Too slow for daytime coding, about `0.56` tok/s |
| LM Studio | `deepseek-r1-0528-qwen3-8b` | completed | `1.23 s` | no | Reasoning-only output; `62/64` completion tokens were reasoning |
| LM Studio | `kimi-dev-72b` | completed | `2.58 s` | yes, `OK` | Short prompt only; full task timed out |

The heavy model smoke result is useful mainly as fit evidence. It does not
promote any of these models for practical local coding on this machine.

## Context Findings

| Stack | Finding |
| --- | --- |
| LM Studio Gemma 12B | Passed at both `16384` and `32768`; 32k is the best current local direct-coding config from this pass |
| WSL Ollama Qwen | Request was `16384`, but `ollama ps` showed `262144` after the pass; count it as large-context evidence |
| Ollama Gemma mappings | Request was `16384`, but observed loaded contexts were higher (`32768` for `gemma3n:e4b`, `131072` for `gemma3:12b` during earlier rows) |
| LM Studio Qwen / small Qwen | 16k loads worked, but correctness and edit format failed |

Because Ollama OpenAI-compatible `options.num_ctx` did not produce a clean
strict-16k observed context in this run, the Ollama rows should be treated as
`>=16k` practical rows rather than exact context-window comparisons.

## Current Recommendation

Use this as the current local direct API coding recommendation:

```text
Endpoint: LM Studio
Model: google/gemma-4-12b
Context: 32768
Parallel: 1
Eval batch: 2048
Physical batch: 512
Reasoning effort: none
```

Use Windows or WSL Ollama `qwen3-coder:30b` when Qwen behavior is specifically
needed or when testing Ollama/OpenAI-compatible endpoint behavior. Keep in mind
that the current Ollama direct rows paid a large first-token/load penalty.

Do not promote the smaller Qwen quants, Gemma E4B, DeepSeek, or Kimi as a local
coding default from this run:

- Small Qwen lanes were fast but produced invalid or incomplete edits.
- Gemma E4B either spent the budget poorly or emitted non-JSON output.
- DeepSeek reasoning models streamed but did not produce final actionable
  output in the smoke.
- Kimi could answer a tiny LM Studio smoke, but timed out on the real task.

## Artifacts

| Artifact | Path |
| --- | --- |
| Planning note | `notes/2026-06-25_07-33-51_local-model-16k-benchmark-plan.md` |
| Windows Ollama 16k one-attempt matrix | `benchmarks/real-usage-agent-benchmark/results/20260625-073431-ollama-windows-16k-direct-matrix/ollama-direct-api-matrix-summary.json` |
| WSL Ollama 16k one-attempt matrix | `benchmarks/real-usage-agent-benchmark/results/20260625-073903-ollama-wsl-16k-direct-matrix/ollama-direct-api-matrix-summary.json` |
| Windows Ollama repair matrix | `benchmarks/real-usage-agent-benchmark/results/20260625-074156-ollama-windows-16k-repair-direct-matrix/ollama-direct-api-matrix-summary.json` |
| WSL Ollama repair matrix | `benchmarks/real-usage-agent-benchmark/results/20260625-074652-ollama-wsl-16k-repair-direct-matrix/ollama-direct-api-matrix-summary.json` |
| LM Studio Gemma 12B 16k | `benchmarks/real-usage-agent-benchmark/results/20260625-075400-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |
| LM Studio Gemma 12B 32k | `benchmarks/real-usage-agent-benchmark/results/20260625-080022-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |
| LM Studio Qwen full quant | `benchmarks/real-usage-agent-benchmark/results/20260625-075041-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |
| LM Studio Qwen smaller quant | `benchmarks/real-usage-agent-benchmark/results/20260625-075254-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |
| LM Studio Qwen 1.5B Q4 | `benchmarks/real-usage-agent-benchmark/results/20260625-075939-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |
| LM Studio Qwen 1.5B Q8 | `benchmarks/real-usage-agent-benchmark/results/20260625-075953-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |
| Heavy Ollama smokes | `benchmarks/real-usage-agent-benchmark/results/20260625-080100-heavy-ollama-smokes/` |
| Heavy LM Studio smokes | `benchmarks/real-usage-agent-benchmark/results/20260625-081300-heavy-lmstudio-smokes/` |
| LM Studio Kimi full task timeout | `benchmarks/real-usage-agent-benchmark/results/20260625-081547-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |

## Cleanup State

After the benchmark:

- `lms ps --json` returned `[]`.
- Windows `ollama ps` showed no loaded models.
- WSL `OLLAMA_HOST=127.0.0.1:11435 ollama ps` showed no loaded models.
- The WSL Ollama service process remained available on `127.0.0.1:11435`,
  matching the pre-run reachable endpoint state.
