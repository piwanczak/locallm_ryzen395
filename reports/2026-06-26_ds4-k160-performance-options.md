---
title: DS4 K160 performance options
date: 2026-06-26
tags:
  - local-inference
  - deepseek-v4-flash
  - ds4
  - rocm
  - performance
---

# DS4 K160 performance options

## Summary

The 0xSero DeepSeek V4 Flash K160 DS4 variant can do better than the earlier 3-4 tok/s synthetic result, but MTP/speculative decoding is not currently useful on this machine because DS4 refuses `--mtp` with `--ssd-streaming`. Under the current healthy ROCm state, K160 reached 6.81 tok/s on a 256-token context / 128-token decode `ds4-bench` run with the simple `48GB` automatic streaming cache.

The most realistic path to a major step up is not MTP. It is increasing WSL's memory allocation so ROCm exposes more than the current ~65.65 GiB total, then retrying K160 full residency. Full residency is the path that would unlock MTP and remove SSD-streaming expert misses.

## What Was Tested

Model:

- `0xSero/DeepSeek-V4-Flash-180B-GGUF`
- File: `DeepSeek-V4-Flash-Spark-Q2-REAP-ds4.gguf`
- Local WSL path: `/root/ds4-models/DeepSeek-V4-Flash-Spark-Q2-REAP-ds4.gguf`

Common benchmark shape:

- DS4 ROCm backend
- `--ssd-streaming`
- Prompt: DS4 bundled `speed-bench/promessi_sposi.txt`
- Short sweep: 64-256 context, 16 generated tokens per frontier
- Long check: 256 context, 128 generated tokens

Result directory:

- `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-cache-mtp-sweep/`

## Cache And Preload Sweep

| Setting | 64 ctx gen tok/s | 128 ctx gen tok/s | 192 ctx gen tok/s | 256 ctx gen tok/s |
| --- | ---: | ---: | ---: | ---: |
| `48GB` automatic preload | 4.56 | 6.12 | 6.73 | 7.17 |
| `6200` cache + preload | 4.62 | 5.91 | 6.36 | 7.07 |
| `6600` cache + preload | 4.20 | 6.13 | 6.40 | 7.70 |
| `6800` cache + preload | 4.77 | 6.49 | 6.59 | 7.03 |
| `6880` cache + preload | 4.97 | 6.40 | 6.90 | 7.62 |

Longer 128-token decode check:

| Setting | Prefill tok/s | Gen tok/s |
| --- | ---: | ---: |
| `48GB` automatic preload | 9.37 | 6.81 |
| `6880` cache + preload | 9.04 | 6.64 |
| `48GB` automatic preload under temporary Windows Performance plan | 8.00 | 6.79 |

Conclusion: manual near-full preload is not clearly better than DS4's automatic `48GB` cache on the longer check. The short-run best value was `6600`, but the stable setting to use first is still:

```bash
--rocm --ssd-streaming --ssd-streaming-cache-experts 48GB
```

The previous K160 synthetic CSV from the original run topped out at 4.09 tok/s at 256 ctx / 16 generated tokens. This pass reached 7.17 tok/s with the same short shape. The likely explanation is healthier warmed ROCm/WSL/device state plus cache behavior, not a magic manual preload setting, because `48GB` automatic cache already captured most of the gain.

## MTP / Speculative Decoding

Downloaded:

- `DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf`
- Local path: `/root/ds4-models/DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf`
- Size: about 3.8 GB

CLI baseline with SSD streaming completed:

```text
ds4: prefill: 57.61 t/s, generation: 3.27 t/s
```

MTP attempts failed immediately for both `--mtp-draft 2` and `--mtp-draft 4`:

```text
ds4: --ssd-streaming is not compatible with --mtp yet
```

Conclusion: MTP cannot improve the practical K160 setup unless K160 can be made full-resident first.

## Power Plan Check

Windows was on `Whisper`. I temporarily switched to the ASUS `Performance` power scheme, ran the same 256 ctx / 128-token DS4 bench, and restored `Whisper`.

Result:

- Whisper/current baseline: 6.81 gen tok/s
- Temporary Windows Performance plan: 6.79 gen tok/s

Conclusion: the Windows power scheme alone did not improve this short DS4 run. Fan/thermal mode may still matter under longer sustained runs, but it was not the immediate bottleneck in this check.

## Ranked Next Moves

1. Increase WSL memory with `.wslconfig`, then retry K160 full residency and MTP. This is the highest-upside experiment because WSL currently exposes only about 64 GiB of the 128 GiB host memory.
2. Keep `48GB` automatic cache for K160 SSD streaming unless a longer real workload proves a manual count better.
3. Stop WSL Ollama during DS4 runs. A transient DS4 `no ROCm-capable device` failure occurred while WSL Ollama/GPU discovery was active; DS4 worked again immediately after. This is not proof of contention, but clean GPU state is cheap.
4. If larger WSL memory enables full residency, test `--mtp-draft 2` and `--mtp-draft 4` again without `--ssd-streaming`.
5. Test K128 REAP only if the goal shifts from quality to speed. K128 may fit/cache better, but quality risk is high.

## Artifacts

- `logs/2026-06-26_run-k160-cache-sweep.sh`
- `logs/2026-06-26_run-k160-long-decode.sh`
- `logs/2026-06-26_run-k160-mtp-cli.sh`
- `logs/2026-06-26_run-k160-power-plan-check.sh`
- `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-cache-mtp-sweep/cache48gb_auto.csv`
- `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-cache-mtp-sweep/long_cache48gb_auto.csv`
- `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-cache-mtp-sweep/cli_mtp_draft2_128.log`
- `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-cache-mtp-sweep/long_cache48gb_auto_windows_performance.csv`

Sources:

- DS4 repository: https://github.com/antirez/ds4
- K160 GGUF source: https://huggingface.co/0xSero/DeepSeek-V4-Flash-180B-GGUF
- AMD ROCm on WSL install docs: https://rocm.docs.amd.com/projects/radeon/en/latest/docs/install/wsl/install-radeon.html
- Microsoft `.wslconfig` docs: https://learn.microsoft.com/en-us/windows/wsl/wsl-config
