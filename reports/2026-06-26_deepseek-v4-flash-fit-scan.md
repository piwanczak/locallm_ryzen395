# DeepSeek V4 Flash Quant Fit Scan

Date: 2026-06-26

## Summary

I broadened the search beyond the 0xSero Spark files and found several DeepSeek V4 Flash quant families. On this AMD/WSL machine, only two candidates are currently runnable and benchmarked without destructive cleanup or a new experimental runtime: 0xSero Spark K160 and 0xSero Spark-Mini K144.

Best result remains K160:

- K160: 53.52 GiB, DS4 ROCm SSD streaming, real-usage 5/7.
- K144: 48.98 GiB, DS4 ROCm SSD streaming, real-usage 1/7, runtime instability.

The broadened search did find smaller/lower-bit generic GGUFs, but the practical ones need a V4-aware llama.cpp fork and either CPU, Apple Metal, NVIDIA CUDA, or an experimental ROCm fork. Current local disk free space is about 48 GiB, below the smallest untested full-model candidate.

## Sources

- 0xSero K160 DS4 GGUF: <https://huggingface.co/0xSero/DeepSeek-V4-Flash-180B-GGUF>
- 0xSero K144 DS4 GGUF: <https://huggingface.co/0xSero/DeepSeek-V4-Flash-162B-GGUF>
- Antirez DS4 GGUF: <https://huggingface.co/antirez/deepseek-v4-gguf>
- Teamblobfish llama.cpp GGUFs: <https://huggingface.co/teamblobfish/DeepSeek-V4-Flash-GGUF>
- ssweens experimental llama.cpp GGUFs: <https://huggingface.co/ssweens/DeepSeek-V4-Flash-GGUF-YMMV>
- eouya2 REAP compact DS4: <https://huggingface.co/eouya2/DeepSeek-V4-Flash-REAP25-LCB50-DS4>
- Huihui abliterated DS4 GGUF: <https://huggingface.co/huihui-ai/Huihui-DeepSeek-V4-Flash-abliterated-ds4-GGUF>
- Persadian IQ1_S-XL GGUF: <https://huggingface.co/persadian/DeepSeek-V4-Flash-IQ1_S-XL>
- Preyazz GGUF: <https://huggingface.co/Preyazz/DeepSeek-V4-Flash-GGUF>

## Fit Filter

Current host constraints:

| Constraint | Value |
| --- | --- |
| Host | ASUS ProArt PX13 HN7306EA |
| APU/GPU | AMD Ryzen AI MAX+ 395 / Radeon 8060S |
| RAM | 132,766,306,304 bytes |
| WSL ROCm device | `gfx1151`, AMD Radeon 8060S |
| Current Windows free disk | about 50.5 GB / 48 GiB |
| Installed relevant runtime | DS4 ROCm build; Ollama present; no standalone V4 llama.cpp fork |

This matters because many published “small” quants are split GGUFs whose first shard is under 50 GiB but total model size is 57-100+ GiB.

## Candidate List

Generated machine-readable summary:

```text
benchmarks/wsl-local-inference-benchmark/results/20260626-deepseek-v4-flash-quant-scan/candidate-summary.json
```

| Candidate | Size | Runtime | Result |
| --- | ---: | --- | --- |
| 0xSero Spark-Mini K144 Q2-REAP DS4 | 48.98 GiB | DS4 ROCm local patch | Tested; runs, unstable, 1/7 |
| 0xSero Spark K160 Q2-REAP DS4 | 53.52 GiB | DS4 ROCm local patch | Tested; best local fit, 5/7 |
| teamblobfish IQ1_S-XL | 57.31 GiB | V4 llama.cpp fork | Not tested: runtime/disk blocked |
| persadian IQ1_S-XL | 57.31 GiB | generic GGUF lineage | Not tested: duplicate/larger generic candidate |
| teamblobfish IQ1_M | 60.08 GiB | V4 llama.cpp fork | Not tested: runtime/disk blocked |
| ssweens IQ1_M | 62.87 GiB | experimental V4 llama.cpp fork | Not tested: runtime not installed, disk blocked |
| eouya2 REAP25 LCB50 compact IQ2XXS DS4 | 63.87 GiB | bundled REAP DS4, Metal-oriented tree | Not tested: wrong runtime/hardware, disk blocked |
| teamblobfish IQ2_XXS-XL | 73.13 GiB | V4 llama.cpp fork | Not tested: runtime/disk blocked |
| Huihui abliterated IQ2_XXS DS4 | 74.72 GiB | DS4-style | Not tested: larger, abliterated, disk blocked |
| antirez official Flash IQ2XXS DS4 | 80.76 GiB | DS4 | Not tested: relevant but disk blocked |
| Preyazz Q2_K GGUF | 96.19 GiB | generic GGUF/llama.cpp | Not tested: too large/current runtime mismatch |

## Tested Candidates

K160 inspect:

| Metric | Value |
| --- | ---: |
| File size | 53.52 GiB |
| Logical parameters | 180.43B |
| Experts | 160 count, 6 used |

K144 inspect:

| Metric | Value |
| --- | ---: |
| File size | 48.98 GiB |
| Logical parameters | 163.12B |
| Experts | 144 count, 6 used |

Both require local DS4 patches in `build/ds4`; stock DS4 did not recognize K160 or K144.

## Synthetic Bench

| Candidate | 64 ctx gen t/s | 128 ctx gen t/s | 192 ctx gen t/s | 256 ctx gen t/s |
| --- | ---: | ---: | ---: | ---: |
| K160 | 3.19 | 3.60 | 3.61 | 4.09 |
| K144 | 3.87 | 4.78 | 4.68 | 5.68 |

K144 is faster in this tiny synthetic test.

## Real-Usage Bench

| Candidate | Tasks | Passes | Timeouts | Avg TTFT | Avg decode | Avg wall TPS | Notes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| K160 | 7 | 5 | 0 | 39256.5 ms | 3.25 tok/s | 2.63 tok/s | Stable enough for full suite |
| K144 | 7 | 1 | 0 | 33414 ms | 2.73 tok/s | 1.95 tok/s | Faster synthetic rows, but decode instability |

K144 server logs during the real-usage run contained repeated `selected expert id -1`, `seed expert id -1`, and `rocm decode failed` lines. That makes the local K144 patch a smoke-test success but not a practical runtime.

## Exclusions

Generic llama.cpp GGUFs:

- teamblobfish explicitly requires a V4-aware llama.cpp fork and says ROCm/Vulkan/Metal-on-AMD lack V4 kernels in that fork.
- ssweens has an experimental fork with ROCm claims, but the runtime is not installed locally and the smallest useful download exceeds current free disk.
- Preyazz and other generic GGUFs are larger than the already excluded generic candidates.

DS4 but larger:

- antirez q2 is the most interesting untested DS4 candidate, but at 80.76 GiB it needs disk cleanup before download.
- Huihui abliterated IQ2_XXS is 74.72 GiB and not a better primary target than antirez q2.
- eouya2 compact REAP DS4 is 63.87 GiB but needs a REAP-aware runtime; the published tree is Metal-oriented and not directly usable on this AMD ROCm setup.

## Recommendation

Keep K160 as the preferred local DeepSeek V4 Flash quant on this machine. K144 is useful evidence that the smaller Spark-Mini profile can start, but its runtime behavior is not reliable. The next meaningful test would be antirez q2 or ssweens IQ1_M only after freeing disk and, for ssweens, building its experimental V4 llama.cpp fork.
