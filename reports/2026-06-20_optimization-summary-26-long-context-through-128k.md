# Optimization Summary 26 - Long Context Through 128k

Created: 2026-06-20 17:05 Europe/Warsaw

## Scope

This phase inspected LM Studio/llama.cpp long-context controls, preserved the existing fast 8k throughput profile, added separate long-context tooling, and benchmarked `qwen/qwen3-coder-30b` at 32k, 64k, and 128k.

## Preserved throughput profile

The known-good profile remains separate and was restored after each long-context rung:

| Field | Value |
| --- | --- |
| Model | `qwen/qwen3-coder-30b` |
| Context | `8192` |
| Parallel | `4` |
| Runtime | `llama.cpp-win-x86_64-vulkan-avx2@2.22.0` |
| Throughput reference | `167.62 tok/s` aggregate |

## Long-context settings used

| Setting | Value |
| --- | --- |
| Context | ladder value |
| Parallel | `1` |
| Eval batch size | `2048` |
| Physical batch size | `512` |
| Flash attention | `true` |
| Number of experts | `4` |
| KV cache offload to GPU/shared memory | `true` |

LM Studio exposes context and parallel through `lms load`; the local REST load endpoint also accepted batch size, flash attention, expert count, and KV offload settings. The underlying bundled `llama-server.exe` exposes `--cache-type-k` and `--cache-type-v`, but direct LM Studio REST support for KV cache quantization is still unconfirmed.

## Results So Far

| Context | Load | Retrieval | Prompt / Estimated TTFT | Prefill Speed | Decode Speed | Interpretation |
| ---: | --- | --- | ---: | ---: | ---: | --- |
| `32768` | pass | 2/2 pass | `87.5-93.6 s` | `332.9-356.8 tok/s` | `35.1-36.1 tok/s` | Usable, but slow TTFT |
| `65536` | pass | 1/2 pass after blocking retry | `344.8-382.9 s` | `167.1-185.4 tok/s` | `23.4-23.7 tok/s` | Not usable: repeatability failed |
| `131072` | pass | 1/1 pass | `1520.1 s` / `25.3 min` | `85.2 tok/s` | `13.9 tok/s` | Not practical: latency dominates |

## Important Failure Mode

Streaming mode failed at 64k because no output token was produced before a several-minute idle period. The client disconnected around 83-86% prompt processing. Blocking mode avoids that transport failure and relies on llama.cpp logs for prompt eval and decode timings.

## Current Interpretation

32k is the highest rung that currently meets the repeatability and retrieval criteria.

64k is not usable by the stated criteria because exact retrieval failed in one of two complete runs. The failure was small but decisive: the model returned the middle code with `ctx66536` instead of `ctx65536`.

128k can load and passed one retrieval test, but a 25-minute TTFT makes it unsuitable for interactive or agentic use here. It is now bottleneck characterization rather than a candidate profile.

## Next

A monitored `196608` run is in progress as of this summary. Higher rungs should be judged primarily by load stability, memory behavior, full-prompt prefill cost, and whether retrieval fails outright. The likely recommendation is to keep `32768` as the stable long-context LM Studio profile unless a lower-latency serving path or effective prefix reuse changes the economics.
