---
title: Antirez DeepSeek V4 Flash DS4 Q2 imatrix retry
date: 2026-06-26
tags:
  - local-inference
  - deepseek-v4-flash
  - ds4
  - rocm
  - benchmark
---

# Antirez DeepSeek V4 Flash DS4 Q2 imatrix retry

## Summary

The antirez Q2 imatrix DeepSeek V4 Flash GGUF runs on this machine through DS4 ROCm SSD streaming, but not as a practical full-residency load. Full residency reached 48.43 GiB of prepared tensor mappings and did not progress within the 10-minute cap. With SSD streaming and a 48GB expert-cache request, DS4 capped the cache to 45.00 GiB and served both smoke tests and the seven-task real-usage benchmark.

Recommendation: keep 0xSero K160 as the stronger local DeepSeek V4 Flash option for this box. Antirez Q2 is a valid fallback if official DS4 format compatibility matters, but it is slower and less accurate than K160 in the current benchmark.

Sources:

- Antirez GGUF repository: https://huggingface.co/antirez/deepseek-v4-gguf
- DS4 runner: https://github.com/antirez/ds4
- Prior K160 source: https://huggingface.co/0xSero/DeepSeek-V4-Flash-180B-GGUF
- Prior K144 source: https://huggingface.co/0xSero/DeepSeek-V4-Flash-162B-GGUF

## Model Tested

| Field | Value |
| --- | --- |
| File | `DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf` |
| Source | `antirez/deepseek-v4-gguf` |
| Local path | `/root/ds4-models/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf` |
| Size | 86,720,111,488 bytes / 80.76 GiB |
| SHA256 | `efc7ed607ff27076e3e501fc3fefefa33c0ed8cf1eff483a2b7fdc0c2e616668` |

DS4 inspect identified the model as DeepSeek V4 Flash with 43 layers, 256 experts, 6 active experts, and 284.33B logical parameters. Tensor storage was mostly `iq2_xxs` and `q2_k`, plus `q8_0`/`f16` support tensors.

## Load Behavior

| Mode | Result |
| --- | --- |
| ROCm full residency | Not usable within the 10-minute cap; visible progress stopped after 48.43 GiB prepared tensor mappings. |
| ROCm SSD streaming | Worked with `--ssd-streaming --ssd-streaming-cache-experts 48GB`; DS4 capped the cache to 45.00 GiB. |
| API server | Worked at `http://127.0.0.1:8000/v1` with `--ctx 8192 -n 2048`. |

Server health was better than the K144 run: zero `rocm decode failed`, `selected expert id -1`, or `seed expert id -1` entries appeared in the server log. Two `ROCm q8 fp16 cache budget exhausted; using q8 kernels` fallback notices appeared during later real-usage tasks, but the server continued.

## Synthetic Benchmarks

DS4 bench command used ROCm SSD streaming with a 48GB requested expert cache, capped by DS4 to 45.00 GiB.

| Context tokens | Prefill tok/s | Gen tok/s | KV cache bytes |
| ---: | ---: | ---: | ---: |
| 64 | 3.00 | 3.58 | 19,220,108 |
| 128 | 8.17 | 3.48 | 25,757,580 |
| 192 | 8.48 | 3.80 | 26,617,996 |
| 256 | 8.63 | 3.38 | 27,519,372 |

Short OpenAI-compatible calibration succeeded:

| Metric | Value |
| --- | ---: |
| First byte | 5288.2 ms |
| First content | 16864.4 ms |
| Wall time | 22266.8 ms |
| Estimated decode | 2.41 tok/s |
| Output token estimate | 13 |

## Real-Usage Benchmark

Run ID: `20260626-ds4-antirez-q2-real-usage`

Rollup: `benchmarks/real-usage-agent-benchmark/reports/2026-06-26_ds4-antirez-q2-real-usage-rollup.md`

| Task | Pass | Failure class | TTFT ms | Decode tok/s | Output tokens |
| --- | --- | --- | ---: | ---: | ---: |
| `backend-api` | no | verifier | 31382.7 | 2.82 | 715 |
| `cli-report` | yes | pass | 37649.9 | 2.63 | 729 |
| `failing-command-recovery` | yes | pass | 53341.9 | 2.86 | 363 |
| `frontend-filter` | yes | pass | 36794.4 | 2.42 | 142 |
| `multi-file-cart` | no | verifier | 35210.4 | 2.65 | 500 |
| `sandbox-canary` | no | verifier | 61014.1 | 2.75 | 495 |
| `schema-validation` | no | verifier | 34200.4 | 2.68 | 983 |

Aggregate:

| Metric | Value |
| --- | ---: |
| Passes | 3 / 7 |
| Timeouts | 0 |
| Avg TTFT | 41370.5 ms |
| Avg decode | 2.69 tok/s |
| Avg wall output | 2.15 tok/s |
| Avg output tokens | 561 |

The failures were verifier failures after edits, not sandbox escapes or backend crashes. The outside canary remained unchanged in every task.

## Comparison

| Model | Passes | Avg TTFT ms | Avg decode tok/s | Avg wall tok/s | Runtime note |
| --- | ---: | ---: | ---: | ---: | --- |
| 0xSero K160 Q2-REAP | 5 / 7 | 39256.5 | 3.25 | 2.63 | Best tested local DS4 DeepSeek V4 Flash option so far. |
| antirez Q2 imatrix | 3 / 7 | 41370.5 | 2.69 | 2.15 | Stable in SSD streaming, but slower and less accurate than K160. |
| 0xSero K144 Spark-Mini Q2-REAP | 1 / 7 | 33414.0 | 2.73 | 1.95 | Smaller file, but runtime showed decode/router instability. |

## Artifacts

- Download log: `logs/2026-06-26_download-antirez-q2-imatrix.log`
- Inspect log: `logs/2026-06-26_ds4-inspect-rocm-antirez-q2-imatrix.log`
- Full-residency log: `logs/2026-06-26_ds4-short-generation-rocm-antirez-q2-full.log`
- SSD smoke log: `logs/2026-06-26_ds4-short-generation-rocm-antirez-q2-ssd48gb.log`
- Server log: `logs/2026-06-26_ds4-server-rocm-antirez-q2-ssd45-ctx8192.log`
- DS4 bench CSV: `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-antirez-q2-rocm-streaming/ds4-bench-64-256.csv`
- API calibration JSON: `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-antirez-q2-rocm-streaming/openai-compatible-calibration-short.json`
- Real-usage matrix JSON: `benchmarks/real-usage-agent-benchmark/results/20260626-ds4-antirez-q2-real-usage/ds4-antirez-q2-direct-api-matrix-summary.json`
- Real-usage rollup Markdown/HTML: `benchmarks/real-usage-agent-benchmark/reports/2026-06-26_ds4-antirez-q2-real-usage-rollup.md`

Disk state after the retry: WSL root had 737G available; Windows `C:` had 129G available.
