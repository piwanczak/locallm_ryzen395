# Optimization Summary 21 - Post-driver Warmed Throughput

This chunk covers the pass after the AMD graphics/chipset driver upgrade. The main result is that Qwen3 Coder 30B now exceeds the original `3x` throughput target when run in a warmed `parallel=4` throughput profile.

## Baseline

| Item | Value |
| --- | --- |
| Original API wall-clock baseline | about `40.5 tok/s` |
| `3x` target | about `121.5 tok/s` |
| Earlier best unique 4-way aggregate | `122.26 tok/s` |
| Earlier fixed-prompt aggregate ceiling | `139.95 tok/s` |

## Post-driver State

| Item | Value |
| --- | --- |
| GPU | `AMD Radeon(TM) 8060S Graphics` |
| AMD graphics driver | `32.0.31019.2002` |
| Driver date | `2026-05-29` |
| LM Studio runtime | `llama.cpp-win-x86_64-vulkan-avx2@2.22.0` |
| Target model | `qwen/qwen3-coder-30b` |

The driver upgrade reset the active Windows scheme to `Standard` and reset AMD AC power-slider values to `2`. I restored the previously tested performance state: `Performance` scheme, `Max Performance Overlay`, AMD `Overlay=3`, and AMD `PMF Controller=3` on AC.

## Applied Profile

| Setting | Value |
| --- | --- |
| `context_length` | `8192` |
| `eval_batch_size` | `2048` |
| `physical_batch_size` | `512` |
| `parallel` | `4` |
| `num_experts` | `4` |
| flash attention | enabled |
| GPU KV cache offload | enabled |

I also added `tools/benchmark-lmstudio-warmed-throughput.ps1`, which performs a short single-request warmup before the 4-way throughput benchmark.

## Measurements

| Test | Result | Notes |
| --- | ---: | --- |
| Post-driver direct 4-way before clean reload | `90.23 tok/s` | below target |
| Clean `parallel=4` reload, best observed | `149.6 tok/s` | above target |
| Immediate direct repeat | `70.39 tok/s` | cold/ramp variability |
| Later direct no-warmup 4-way | `61.21 tok/s` | still variable |
| Single stream | `58.83 tok/s` | decode path healthy |
| `parallel=3` aggregate | `100.08 tok/s` | not enough |
| Warmup then 4-way, run 1 | `139.64 tok/s` | above target |
| Warmup then 4-way, run 2 | `148.71 tok/s` | above target |
| Warmed helper script verification | `143.0 tok/s` | above target |

## Interpretation

- The upgraded AMD driver plus restored performance power policy makes the `3x` target reachable.
- The practical successful recipe is warmed aggregate throughput:
  - short single-request decode warmup,
  - then 4 concurrent Qwen3 Coder requests.
- ADL telemetry shows the remaining bad direct runs are tied to slow GPU clock ramp behavior rather than a broken Vulkan decode path.
- Direct cold 4-way runs are still unreliable, so the warmup is currently part of the operating recipe.

## Current Recipe

1. Keep Windows on `Performance` with `Max Performance Overlay`.
2. Keep AMD AC `Overlay=3` and `PMF Controller=3`.
3. Keep LM Studio on Vulkan runtime `2.22.0`.
4. Load Qwen3 Coder 30B with the `parallel=4` profile above.
5. Before throughput-sensitive work, run a short warmup decode or use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\benchmark-lmstudio-warmed-throughput.ps1 -BaseUrl http://127.0.0.1:1234 -Model qwen/qwen3-coder-30b -WarmupTokens 160 -Concurrency 4 -MaxTokens 320 -UniquePrompt -TimeoutSec 240
```

## Failures and Caveats

- The driver upgrade reset power policy, so future driver updates may need the same power setting restoration.
- A `parallel=3` profile did not reach the `3x` target.
- Direct no-warmup 4-way runs remain inconsistent.
- ASUS/ProArt mode may still be the deeper control needed to remove the warmup requirement.

## Status

The warmed `parallel=4` profile has repeated measurements above the `3x` target for Qwen3 Coder 30B. The remaining quality issue is making that performance automatic from a cold/direct request path rather than requiring a warmup.
