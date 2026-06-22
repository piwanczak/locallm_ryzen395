# Optimization Summary 27 - Long Context 196k and Upper Loads

Created: 2026-06-20 18:42 Europe/Warsaw

## Scope

This phase completed the large-context end of the ladder for `qwen/qwen3-coder-30b` after the earlier 32k, 64k, and 128k summary. It covered one full 196k needle-in-context run plus load-only checks at 229k and 262k.

The existing fast throughput profile remained separate and was restored after the large-context checks.

## Preserved throughput profile

| Field | Value |
| --- | --- |
| Model | `qwen/qwen3-coder-30b` |
| Context | `8192` |
| Parallel | `4` |
| Final state | `IDLE` in `lms ps` |

## Long-context settings used

| Setting | Value |
| --- | --- |
| Context | ladder value |
| Parallel | `1` |
| Eval batch size | `2048` |
| Physical batch size | `512` |
| Flash attention | `true` |
| Number of experts | `4` |
| KV cache offload | `true` |

## Results

| Context | Test type | Load | Retrieval | Prompt / Estimated TTFT | Prefill Speed | Decode Speed | Memory Behavior | Interpretation |
| ---: | --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `196608` | full needle benchmark | pass | 1/1 pass | `4830.5 s` / `80.5 min` | `40.38 tok/s` | `9.71 tok/s` | peak GPU adapter committed `43.08 GiB`; shared usage `38.41 GiB`; min free RAM `50.94 GiB` | Not usable: latency dominates |
| `229376` | load-only | pass | not run | not run | not run | not run | after load: GPU adapter committed `45.04 GB`; shared usage `40.51 GB`; available RAM `52887 MB` | Loadable, but projected unusable |
| `262144` | load-only | pass | not run | not run | not run | not run | after load: GPU adapter committed `48.33 GB`; shared usage `43.80 GB`; available RAM `49746 MB` | Loadable, but projected unusable |

## Stability

No matching Display/AMD driver reset, resource-exhaustion, OOM, or Kernel-Power instability events were captured for the 196k run. The failure mode was not a crash. The decisive bottleneck was prefill latency and decode slowdown after the long prompt.

## Important finding

The 196k rung proves the practical limit for this LM Studio/Vulkan/shared-memory setup. It can load and complete a single retrieval test, but spending about 80.5 minutes before generation fails the usability criteria. Since 64k already failed repeatability and 128k already took about 25.3 minutes to prefill, the 229k and 262k rungs were limited to load checks rather than multi-hour full prompts.

## Current interpretation

The highest stable long-context LM Studio profile remains `32768`, `parallel=1`.

`65536` should be treated as experimental only because exact middle-needle retrieval failed in one of two complete blocking runs. `131072` and above are bottleneck-characterization profiles, not practical profiles, on this hardware.

## Next path

For 200k-250k usable context, the next realistic path is not a larger LM Studio profile on the same stack. The next evaluation should test direct llama.cpp controls such as KV cache quantization (`--cache-type-k`, `--cache-type-v`) and prompt reuse (`--cache-prompt`, `--cache-reuse`, `--cache-ram`), or move to a serving stack such as vLLM/SGLang on hardware with more suitable GPU memory and long-context throughput.
