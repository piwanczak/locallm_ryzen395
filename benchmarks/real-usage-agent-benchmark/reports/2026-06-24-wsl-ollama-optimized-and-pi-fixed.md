# WSL Ollama Optimized And Pi Fixed

Created: 2026-06-24 Europe/Warsaw

## Executive Result

WSL Ollama is now a viable `qwen3-coder:30b` endpoint on this machine after two
separate fixes:

1. Wake the Windows platform out of the Modern Standby/iGPU clock-cap state.
2. Add an explicit Qwen/Ollama tool-call compatibility note for the Pi lane.

With those in place, WSL Ollama meets the goal's performance gate:

- Direct API throughput is within the accepted 30% envelope versus Windows Ollama.
- OpenCode reaches the same pass count as corrected Windows Ollama evidence: `3/4`, with `backend-api` still failing.
- Pi passes the guarded `multi-file-cart` task with the same compatibility note on WSL and Windows.

This should be promoted as "usable with caveats", not as a blanket replacement
for the verified standalone WSL ROCm llama.cpp lane.

## Root Cause

The earlier WSL Ollama slowdown had two independent causes.

First, the GPU was clock-capped below the inference layer. This was proven by a
standalone WSL ROCm `llama-bench` run using the same Ollama Qwen model blob:
when the machine was stuck after Modern Standby, generation stayed near
`11.37 tok/s` and ADL PMLog showed GFXCLK around `609 MHz` with about `14 W`
ASIC power. After a synthetic local wake produced a new Windows Modern Standby
exit event, the same low-level path recovered to `59.41 tok/s` generation,
GFXCLK max `2836 MHz`, and ASIC power average `67.6 W`.

Second, the WSL Pi failure was a tool-call parser compatibility issue, not a
reasoning or throughput issue. The baseline WSL Pi transcript reached the right
edit plan, then ended with `Stream ended without finish_reason`; Ollama logs
showed Qwen tool-call XML parsing failures. No file was changed. Adding an
explicit complete `<tool_call>` reminder to the Pi prompt file made WSL Pi pass.

## Working WSL Ollama Configuration

The working WSL Ollama service configuration is:

```text
OLLAMA_HOST=127.0.0.1:11435
OLLAMA_DEBUG=1
OLLAMA_IGPU_ENABLE=1
OLLAMA_LLM_LIBRARY=rocm_v7_2
HSA_ENABLE_DXG_DETECTION=1
LD_PRELOAD=/usr/local/lib/ollama/rocm_v7_2/libhsa-runtime64.so.1
LD_LIBRARY_PATH=/usr/local/lib/ollama/rocm_v7_2:/usr/local/lib/ollama
GGML_BACKEND_PATH=/usr/local/lib/ollama/rocm_v7_2:/usr/local/lib/ollama
OLLAMA_LIBRARY_PATH=/usr/local/lib/ollama
OLLAMA_CONTEXT_LENGTH=262144
OLLAMA_LOAD_TIMEOUT=15m
OLLAMA_NUM_PARALLEL=1
OLLAMA_FLASH_ATTENTION=true
LLAMA_ARG_FLASH_ATTN=on
```

Post-wake runner evidence:

- `qwen3-coder:30b` loads `100% GPU`.
- Context is `262144`.
- `flash_attn=enabled`.
- `n_batch=2048`, `n_ubatch=2048`.
- Runner backend is ROCm.

## Direct API Comparison

Fresh direct API matrix summaries:

- [Windows direct matrix](../../../public-results/results-summary.md)
- [WSL direct matrix](../../../public-results/results-summary.md)

| Task | Windows output TPS | WSL output TPS | WSL slowdown |
| --- | ---: | ---: | ---: |
| `backend-api` | `45.44` | `44.14` | `2.9%` |
| `schema-validation` | `45.83` | `43.77` | `4.5%` |
| `frontend-filter` | `46.52` | `46.11` | `0.9%` |

Pass behavior did not change: `frontend-filter` passes; `backend-api` and
`schema-validation` still fail in direct mode for both Windows and WSL.

The separate warm/cold probe also cleared the gate:

- WSL warm run: `46.72 output tok/s`.
- Windows warm run: `48.46 output tok/s`.
- WSL warm slowdown: about `3.6%`.

## OpenCode Comparison

Fresh WSL OpenCode matrix:

- [WSL OpenCode matrix](../../../public-results/results-summary.md)

Prior corrected Windows OpenCode matrix:

- [Corrected Windows OpenCode matrix](../../../public-results/results-summary.md)

| Task | Windows corrected | WSL post-wake | WSL output TPS |
| --- | --- | --- | ---: |
| `backend-api` | fail | fail | `27.87` |
| `multi-file-cart` | pass | pass | `23.25` |
| `frontend-filter` | pass | pass | `25.43` |
| `failing-command-recovery` | pass | pass | `25.70` |

OpenCode is fair enough to compare as pass behavior, but not as a precise speed
metric: agent token counts vary materially between runs. The meaningful result
is that WSL Ollama no longer has the earlier `0/4` failure pattern.

## Pi Comparison

Baseline WSL Pi, without compatibility note:

- [WSL baseline Pi matrix](../../../public-results/results-summary.md)
- Result: failed.
- `toolCallCount`: `4`.
- Verifier: failed because no file changed.
- Failure mode: `Stream ended without finish_reason` after the model prepared
  to edit `src/cart.mjs`.

Baseline Windows Pi, without compatibility note:

- [Windows baseline Pi matrix](../../../public-results/results-summary.md)
- Result: passed.
- Elapsed: `236.2 s`.
- `toolCallCount`: `12`.

Like-for-like Pi runs with the prompt-file compatibility note:

- [WSL compatibility Pi matrix](../../../public-results/results-summary.md)
- [Windows compatibility Pi matrix](../../../public-results/results-summary.md)

| Endpoint | Result | Elapsed | TTFT proxy | Tool-call starts |
| --- | --- | ---: | ---: | ---: |
| WSL Ollama + note | pass | `215.4 s` | `44 ms` | `9` |
| Windows Ollama + note | pass | `235.1 s` | `38 ms` | `8` |

The compatibility note was embedded in the benchmark prompt file:

```text
For this local Qwen/Ollama endpoint, when you call a tool you must output a complete tool block with the opening <tool_call> tag, then the <function=tool_name> block, then </function>, then </tool_call>. Never omit the opening <tool_call> tag. Do not write prose after a tool call.
```

## Harness Changes

The Pi harness was extended so this can be repeated without fragile command-line
quoting:

- `benchmarks/pi-docker-agent-runner/scripts/run-pi-docker.ps1` accepts `-PromptFile`.
- `benchmarks/real-usage-agent-benchmark/scripts/run-pi-real-usage.ps1` passes prompt files instead of multi-line prompt text, emits a per-task invocation script, supports extra Pi args, and embeds the optional compatibility note in the prompt file.
- `benchmarks/real-usage-agent-benchmark/scripts/run-ollama-pi-matrix.ps1` forwards the compatibility note.

This is not just convenience. Passing multi-line prompts through nested Windows
PowerShell command strings caused parameter binding corruption during the
compatibility experiment. Prompt files make the benchmark runner more honest.

## Current Recommendation

Use WSL Ollama for Qwen only when all of these are true:

- The machine has a fresh wake from Modern Standby and ADL/throughput sanity checks show the GPU is not clock-capped.
- The service uses the ROCm/ROCDXG configuration above.
- Pi or other XML-tool-call agents get the explicit local Qwen/Ollama tool-call reminder.

Use Windows Ollama when you want the simpler endpoint with fewer WSL power-state
variables. Use standalone WSL ROCm llama.cpp when you want the more controlled
Linux GPU comparison lane.

## Remaining Limits

- Modern Standby can silently invalidate both WSL and Windows GPU comparisons.
- WSL Pi without the tool-call reminder still fails on this endpoint.
- `backend-api` remains the strongest unresolved discriminator; it fails in the comparable Qwen Ollama direct/OpenCode lanes.
- Pi metrics still do not expose reliable token counts from the local OpenAI-compatible path, so Pi reports TTFT proxy, wall time, and tool count rather than true output TPS.
