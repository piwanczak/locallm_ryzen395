# Optimization Summary 28 - Long Context Final Report

Created: 2026-06-20 18:31 Europe/Warsaw

## Executive conclusion

`qwen/qwen3-coder-30b` is not practically usable at 200k-250k context in LM Studio on this hardware with the tested Vulkan/shared-memory stack. The model can load at 196k, 229k, and 262k, and 196k completed one successful needle retrieval, but the prompt eval bottleneck is decisive: the 196k prompt took `4830.468 s` (`80.51 min`) before generation and decode speed dropped to `9.71 tok/s`.

The recommended separate long-context LM Studio profile is:

| Field | Value |
| --- | --- |
| Model | `qwen/qwen3-coder-30b` |
| Context | `32768` |
| Parallel | `1` |
| Eval batch size | `2048` |
| Physical batch size | `512` |
| Flash attention | `true` |
| Experts | `4` |
| KV cache offload | `true` |

The existing fast throughput profile was preserved and restored:

| Field | Value |
| --- | --- |
| Model | `qwen/qwen3-coder-30b` |
| Context | `8192` |
| Parallel | `4` |
| Throughput reference | `167.62 tok/s` aggregate |
| Final verification | `lms ps` showed `CONTEXT 8192`, `PARALLEL 4`, `STATUS IDLE` |

## Settings inspected

LM Studio CLI exposed `--context-length`, `--parallel`, `--gpu`, `--ttl`, `--identifier`, and `--estimate-only` on `lms load`.

LM Studio REST load accepted the long-context load fields used here: `context_length`, `eval_batch_size`, `flash_attention`, `num_experts`, `offload_kv_cache_to_gpu`, and `echo_load_config`. LM Studio's current REST docs describe these fields on `POST /api/v1/models/load`, including context length, eval batch size, flash attention, MoE expert count, and KV-cache GPU offload. The model listing docs also expose loaded-instance config fields such as context length, parallel, flash attention, expert count, and KV offload.

The local llama.cpp `llama-server.exe` exposed deeper long-context controls that LM Studio did not directly confirm through the REST load path in this run:

| Area | Local llama.cpp flags observed |
| --- | --- |
| Context and slots | `--ctx-size`, `--parallel` |
| Batching | `--batch-size`, `--ubatch-size` |
| Attention | `--flash-attn` |
| KV placement | `--kv-offload`, `--kv-unified` |
| KV quantization | `--cache-type-k`, `--cache-type-v` with `f32`, `f16`, `bf16`, `q8_0`, `q4_0`, `q4_1`, `iq4_nl`, `q5_0`, `q5_1` |
| Prompt/cache reuse | `--cache-prompt`, `--cache-reuse`, `--cache-ram`, `--ctx-checkpoints` |
| RoPE/YaRN | `--rope-scaling`, `--rope-scale`, `--rope-freq-base`, `--rope-freq-scale`, `--yarn-*` |

The LM Studio TypeScript docs describe cache quantization fields (`llamaKCacheQuantizationType`, `llamaVCacheQuantizationType`) and note that value-cache quantization requires flash attention. I did not verify a working LM Studio REST JSON field for those cache quantization controls during this run, so KV quantization remains a next-path item rather than part of the tested profile.

## Resource estimates

`lms load --estimate-only --gpu max --parallel 1` estimated:

| Context | Estimated GPU memory | Estimated total memory |
| ---: | ---: | ---: |
| `32768` | `19.53 GiB` | `19.53 GiB` |
| `65536` | `21.18 GiB` | `21.18 GiB` |
| `131072` | `24.47 GiB` | `24.47 GiB` |
| `196608` | `27.76 GiB` | `27.76 GiB` |
| `229376` | `29.41 GiB` | `29.41 GiB` |
| `262144` | `31.05 GiB` | `31.05 GiB` |

Actual Windows GPU adapter committed memory was materially higher during long-prompt tests because the integrated GPU/shared-memory path accounts differently than the LM Studio estimator.

## Benchmark ladder

| Context | Runs | Load reliability | Retrieval result | TTFT / prompt eval | Prefill speed | Decode speed | Peak GPU committed | Pass/fail |
| ---: | ---: | --- | --- | ---: | ---: | ---: | ---: | --- |
| `32768` | 2 | pass | 2/2 pass | `87.9-94.6 s` | `332.92-356.82 tok/s` | `35.06-36.08 tok/s` | `27.30 GiB` | pass |
| `65536` | 2 blocking runs after streaming failure | pass | 1/2 pass | `344.8-382.9 s` | `167.12-185.44 tok/s` | `23.37-23.66 tok/s` | `31.17-31.19 GiB` | fail: retrieval repeatability |
| `131072` | 1 | pass | 1/1 pass | `1520.1 s` / `25.3 min` | `85.22 tok/s` | `13.89 tok/s` | `37.08 GiB` | fail: latency |
| `196608` | 1 | pass | 1/1 pass | `4830.5 s` / `80.5 min` | `40.38 tok/s` | `9.71 tok/s` | `43.08 GiB` | fail: latency |
| `229376` | load-only | pass | not run | not run | not run | not run | `45.04 GB` after load | fail: projected latency |
| `262144` | load-only | pass | not run | not run | not run | not run | `48.33 GB` after load | fail: projected latency |

## Failure and stability notes

Streaming transport failed at 64k before first token because the server spent several minutes in prefill with no streamed output. Blocking mode avoided that client-side read failure, and timings were then taken from llama.cpp server logs.

At 64k, one full blocking run retrieved the middle needle incorrectly, returning `ctx66536` instead of `ctx65536`. This fails the repeatability criterion even though the model loaded and avoided OS-level instability.

No matching Display/AMD driver reset, resource exhaustion, OOM, or Kernel-Power instability events were captured during the measured rungs. The problem is not a hard crash; it is latency and throughput collapse as context grows.

## Bottleneck

The bottleneck is long-prompt prefill on the LM Studio llama.cpp Vulkan path using integrated GPU/shared system memory. Memory capacity is sufficient to load very large contexts, but attention/prompt processing slows sharply:

| Context | Prefill speed |
| ---: | ---: |
| `32768` | `332.92-356.82 tok/s` |
| `65536` | `167.12-185.44 tok/s` |
| `131072` | `85.22 tok/s` |
| `196608` | `40.38 tok/s` |

The shape is roughly the expected long-context attention cost showing up in practice: doubling context approximately halves prefill throughput, and decode also falls after very long prompts.

## Recommended path

1. Keep the existing fast profile unchanged: `8192`, `parallel=4`.
2. Add/use a separate LM Studio long-context profile at `32768`, `parallel=1`, with the settings listed above.
3. Treat `65536` as experimental only. It loads, but it failed exact middle-needle repeatability and has 5.7-6.4 minute TTFT.
4. Do not use 128k-262k as interactive LM Studio profiles on this hardware. They load, but the prefill latency is the blocker.
5. For a serious 200k-250k path, test outside the current LM Studio REST profile with direct llama.cpp flags for KV cache quantization and prompt reuse, especially `--cache-type-k`, `--cache-type-v`, `--cache-prompt`, `--cache-reuse`, and `--cache-ram`.
6. If 200k-250k must be interactive, evaluate a serving stack with stronger long-context throughput and GPU memory behavior, such as vLLM or SGLang on a CUDA/HIP-capable discrete GPU with sufficient VRAM, then retest the same needle ladder.

## Artifacts

| Artifact | Path |
| --- | --- |
| Reload fast throughput profile | `tools/reload-qwen30b-throughput.ps1` |
| Reload separate long-context profile | `tools/reload-qwen30b-long-context.ps1` |
| Long-context benchmark harness | `tools/benchmark-lmstudio-long-context.ps1` |
| Ladder runner | `tools/run-qwen30b-long-context-ladder.ps1` |
| Raw benchmark JSONL | `logs/long-context/long-context-results-20260620.jsonl` |
| Ladder JSONL | `logs/long-context/long-context-ladder-20260620.jsonl` |
| 196k background run log | `logs/long-context/run-196608-20260620-170539.out.log` |

## Sources checked

- LM Studio REST load docs: https://lmstudio.ai/docs/developer/rest/load
- LM Studio REST list/model config docs: https://lmstudio.ai/docs/developer/rest/list
- LM Studio TypeScript load config docs: https://lmstudio.ai/docs/typescript/api-reference/llm-load-model-config
- LM Studio API changelog for `lms load --estimate-only`: https://lmstudio.ai/docs/developer/api-changelog
- Local `lms load --help`
- Local `downloads/llama-vulkan/b9728-vulkan/llama-server.exe --help`
