# Ollama Inference Server Comparison, 2026-06-23

This milestone installed Ollama on Windows and WSL, pulled the nearest comparable model set, reran the real-usage benchmark lanes against Ollama, and compared the result with the latest LM Studio baseline runs.

## Scope

Endpoints:

- Windows Ollama `0.30.10`: `http://127.0.0.1:11434`
- WSL Ollama `0.30.10`: `http://127.0.0.1:11435`
- Docker/Pi access to those endpoints through `host.docker.internal:11434` and `host.docker.internal:11435`

Model mapping:

| Prior LM Studio model | Ollama model used | Note |
| --- | --- | --- |
| `qwen/qwen3-coder-30b` | `qwen3-coder:30b` | Direct comparable Ollama library model. |
| `google/gemma-4-e4b` | `gemma3n:e4b` | Nearest Ollama E4B/effective-4B Gemma mapping, not identical weights. |
| `google/gemma-4-12b` | `gemma3:12b` | Nearest Ollama 12B Gemma mapping, not identical weights. |

Official model references used for this mapping:

- [Ollama qwen3-coder](https://ollama.com/library/qwen3-coder)
- [Ollama gemma3n](https://ollama.com/library/gemma3n)
- [Ollama gemma3](https://ollama.com/library/gemma3)
- [Ollama OpenAI compatibility](https://ollama.readthedocs.io/en/openai/)

## Promoted Artifacts

| Artifact | Link |
| --- | --- |
| Combined Ollama rollup Markdown | [2026-06-23-ollama-rollup.md](2026-06-23-ollama-rollup.md) |
| Combined Ollama rollup JSON | [2026-06-23-ollama-rollup.json](2026-06-23-ollama-rollup.json) |
| Windows direct API matrix | [ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md) |
| WSL direct API matrix | [ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md) |
| Windows OpenCode matrix | [ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md) |
| Windows Pi matrix | [ollama-pi-matrix-summary.json](../../../public-results/results-summary.md) |
| WSL Pi matrix | [ollama-pi-matrix-summary.json](../../../public-results/results-summary.md) |
| Prior LM Studio/OpenCode/Pi report | [2026-06-23-real-usage-followup-and-pi-guard.html](2026-06-23-real-usage-followup-and-pi-guard.md) |

## Direct API Results

Direct API used the OpenAI-compatible chat-completions endpoint with streaming. TTFT is first streamed content; TPS is derived from reported completion tokens.

| Endpoint | Model | Passes | Tasks | Main result | Avg TTFT | Avg TPS |
| --- | --- | ---: | ---: | --- | ---: | ---: |
| Windows | `qwen3-coder:30b` | 1 | 3 | Passed `frontend-filter`; `backend-api` hit one zero-output timeout row. | 1.2 s | 47.6 |
| Windows | `gemma3n:e4b` | 0 | 3 | Generated text but failed all verifiers. | 2.1 s | 40.1 |
| Windows | `gemma3:12b` | 1 | 3 | Passed `frontend-filter`; failed backend/schema. | 3.7 s | 18.1 |
| WSL | `qwen3-coder:30b` | 1 | 3 | Passed `frontend-filter`; failed backend/schema without timeout. | 10.8 s | 17.1 |
| WSL | `gemma3n:e4b` | 0 | 3 | Failed all verifiers. | 12.9 s | 16.3 |
| WSL | `gemma3:12b` | 1 | 3 | Passed `frontend-filter`; failed backend/schema. | 28.1 s | 7.6 |

Windows was much faster for direct API generation. WSL was CPU-only in observed `ollama ps` output and showed materially higher TTFT/lower TPS, despite having enough memory. The 60 GiB WSL cap is sufficient for one model at a time, but it is not equivalent to Windows' roughly 123 GiB visible RAM, and it did not produce comparable acceleration.

## OpenCode Results

OpenCode was run on the Windows Ollama endpoint with the same four tasks and six-minute task cap used by the corrected LM Studio baseline.

| Model | Ollama passes | Prior LM Studio passes | Interpretation |
| --- | ---: | ---: | --- |
| `qwen3-coder:30b` | 2/4 | 2/4 | Same pass count, different mix: Ollama passed `multi-file-cart` and `failing-command-recovery`; LM Studio passed `multi-file-cart` and `frontend-filter`. `backend-api` still failed. |
| `gemma3n:e4b` | 0/4 | 1/4 | Ollama rejected tool-use requests for this model. |
| `gemma3:12b` | 0/4 | 0/4 | Ollama rejected tool-use requests for this model. |

The Gemma failures were not slow coding failures. OpenCode received API errors from Ollama such as:

```text
registry.ollama.ai/library/gemma3n:e4b does not support tools
registry.ollama.ai/library/gemma3:12b does not support tools
```

That makes these Gemma Ollama tags unsuitable for OpenCode/Pi-style tool-calling unless the harness avoids tool calls, the endpoint is changed, or the model is imported/configured with tool support.

## Pi Results

Pi was run with the guarded workspace harness on `multi-file-cart`.

| Endpoint | Model | Verifier | Runner timeout | Safety result |
| --- | --- | --- | --- | --- |
| Windows | `qwen3-coder:30b` | pass | no | Modified only `src/cart.mjs`; canary unchanged. |
| WSL | `qwen3-coder:30b` | pass | yes | Modified only `src/cart.mjs`; canary unchanged, but the runner did not terminate before the 360s cap. |
| Windows | `gemma3n:e4b` | fail | no | Endpoint/tool support error, no useful edit. |
| WSL | `gemma3n:e4b` | fail | no | Endpoint/tool support error, no useful edit. |
| Windows | `gemma3:12b` | fail | no | Endpoint/tool support error, no useful edit. |
| WSL | `gemma3:12b` | fail | no | Endpoint/tool support error, no useful edit. |

Pi remains viable with Qwen through Ollama. Windows Qwen is cleaner than WSL Qwen for Pi because it exits without timeout. WSL Qwen still verifies correctly, so the issue is termination discipline/performance, not the file guard or verifier.

## Comparison To Prior Goal

Main changes from the LM Studio baseline:

- Direct API now has TTFT/TPS accounting. Ollama Windows direct exposes usable token usage and is faster than WSL by a large margin.
- `qwen3-coder:30b` remains the only model that works across direct API, OpenCode, and Pi.
- `backend-api` remains the main hard task. No tested Ollama lane solved it.
- Ollama's Gemma mappings are useful for direct text generation but fail agentic tool lanes because the endpoint reports no tool support.
- The guarded Pi harness still works. Its strongest result is still Qwen on `multi-file-cart`.

The practical winner did not change: use Qwen for local agentic coding. Ollama is a viable inference server for Qwen in both direct and tool-agent lanes, but LM Studio remains competitive and may be better for some model/runtime combinations. Ollama's biggest immediate value here is cleaner install/runtime management and standard OpenAI-compatible serving; its biggest blocker is model-level tool support for Gemma tags.

## Follow-Up Work

- Add a tool-support preflight to every agentic matrix: call a minimal tool request first and mark unsupported models as `tool-unsupported` instead of spending a full task row.
- Test whether Ollama Modelfile/import options can enable tool support for Gemma-class local models, or whether a different Ollama model tag is needed.
- Add an early-stop verifier monitor for Pi and OpenCode so a verifier-passing run can terminate before the host timeout.
- For WSL, investigate GPU acceleration explicitly. Current observed WSL Ollama rows ran CPU-only with 4096 context, so this run is not a fair GPU-vs-GPU throughput comparison.
- Keep `backend-api` as the discriminator task for future model/server changes.
