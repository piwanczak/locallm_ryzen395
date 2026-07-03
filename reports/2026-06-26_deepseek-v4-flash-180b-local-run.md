# DeepSeek V4 Flash 180B Local Run

Date: 2026-06-26

## Summary

The BF16 `0xSero/DeepSeek-V4-Flash-180B` path did not fit this machine's runtime stack because the model card targets NVIDIA DGX Spark / GB10 with vLLM. The DS4-specific GGUF fallback did run on this AMD Strix Halo machine, but only after a local DS4 shape patch for the 160-expert K160 variant and only with DS4 ROCm SSD streaming.

Result: local inference was successful in a constrained but usable form. It served an OpenAI-compatible endpoint, passed a short API smoke, and completed the seven-task real-usage benchmark suite with 5/7 passes. Throughput was slow: about 3.25 tok/s measured decode and 2.63 tok/s wall-inclusive output across the real-usage tasks.

## Sources

- BF16 model: <https://huggingface.co/0xSero/DeepSeek-V4-Flash-180B>
- DS4 GGUF model: <https://huggingface.co/0xSero/DeepSeek-V4-Flash-180B-GGUF>
- DS4 runtime: <https://github.com/antirez/ds4>

The BF16 card describes a 180B DeepSeek V4 Flash model targeting DGX Spark/vLLM. The GGUF card provides `DeepSeek-V4-Flash-Spark-Q2-REAP-ds4.gguf`, SHA256 `dae2ed196e8ad87d6667d3fa04f65d78302ea4f148ed0ee0f3ff0b829d1f9c5d`, and states that it is DS4-specific rather than a generic llama.cpp GGUF.

## Host And Runtime

| Item | Value |
| --- | --- |
| Machine | ASUS ProArt PX13 HN7306EA |
| APU | AMD Ryzen AI MAX+ 395 w/ Radeon 8060S |
| Windows RAM | 132,766,306,304 bytes |
| GPU | AMD Radeon(TM) 8060S Graphics |
| GPU driver | `32.0.31021.1015` |
| WSL distro | Ubuntu-24.04 |
| WSL memory | 60 GiB RAM, 16 GiB swap |
| ROCm device | `gfx1151`, AMD Radeon 8060S |

## Setup Outcome

Stock DS4 built with `make strix-halo`, but rejected the downloaded GGUF because upstream DS4 did not recognize the model's 160-expert shape:

```text
ds4: unsupported DeepSeek4 shape: layers=43 embd=4096 heads=64 q_lora=1024 out_groups=8 experts=160 ff_exp=2048 indexer_top_k=512
```

I added a local-only patch under ignored `build/ds4`:

- `build/ds4/ds4.c`: `DS4_SHAPE_FLASH_SPARK_K160`, named `DeepSeek V4 Flash Spark K160`.
- `build/ds4/rocm/ds4_rocm_runtime.cuh`: minimum expert count constant for 160 experts.
- `build/ds4/rocm/ds4_rocm_router.cuh`: 160-expert router kernel launch branches.

After rebuilding, DS4 inspect recognized the model:

| Metric | Value |
| --- | --- |
| Layers | 43 |
| Experts | 160 count, 6 used |
| File size | 53.52 GiB |
| Logical parameters | 180.43 B |
| Main tensor types | `q2_k` 17.64 GiB, `iq2_xxs` 27.71 GiB, `q8_0` 6.15 GiB, `f16` 2.01 GiB |

Non-streaming ROCm loading did not complete. Both DrvFs and WSL ext4 model paths stalled after preparing about 48.34 GiB of tensor mappings. SSD streaming did complete, with a requested 48GB expert cache capped by DS4 to 45GB.

## Smoke Results

Short generation with SSD streaming worked:

| Cache request | Result | Prefill | Generation |
| --- | --- | ---: | ---: |
| 8GB | `OK` smoke | 0.82 t/s | 1.66 t/s |
| 32GB | Redis Streams sentence | 0.87 t/s | 2.28 t/s |
| 48GB capped to 45GB | Redis Streams sentence | 0.76 t/s | 2.30 t/s |

OpenAI-compatible smoke through `ds4-server`:

| Metric | Value |
| --- | ---: |
| First byte | 4736.8 ms |
| First content | 12089.6 ms |
| Wall time | 15185.5 ms |
| Output token estimate | 8 |
| Decode estimate | 2.58 tok/s |
| Output preview | `add(a,b){return a+b}` |

## Synthetic DS4 Bench

Result CSV: `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-rocm-streaming/ds4-bench-64-256.csv`

| Context tokens | Prefill tokens | Prefill t/s | Gen tokens | Gen t/s |
| ---: | ---: | ---: | ---: | ---: |
| 64 | 64 | 2.51 | 16 | 3.19 |
| 128 | 64 | 6.47 | 16 | 3.60 |
| 192 | 64 | 8.48 | 16 | 3.61 |
| 256 | 64 | 9.17 | 16 | 4.09 |

## Real-Usage Benchmark

Run details:

- Run ID: `20260626-ds4-k160-real-usage`
- Endpoint: `http://127.0.0.1:8000/v1`
- Model: `deepseek-chat`
- Context: 8192
- Max attempts: 1
- Max tokens: 2048
- Rollup: `benchmarks/real-usage-agent-benchmark/reports/2026-06-26_ds4-k160-real-usage-rollup.md`
- Rendered rollup: `benchmarks/real-usage-agent-benchmark/reports/2026-06-26_ds4-k160-real-usage-rollup.html`

Overview:

| Tasks | Passes | Timeouts | Allowlist violations | Canary failures | Avg TTFT | Avg decode | Avg wall TPS |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 7 | 5 | 0 | 0 | 0 | 39256.5 ms | 3.25 tok/s | 2.63 tok/s |

Task rows:

| Task | Pass | Class | Prompt tokens | Output tokens | Decode tok/s | Wall tok/s | Modified files |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| `backend-api` | no | verifier | 1374 | 716 | 3.60 | 3.02 | `src/orders.mjs` |
| `cli-report` | yes | pass | 1041 | 686 | 3.29 | 2.88 | `bin/usage-report.mjs` |
| `failing-command-recovery` | yes | pass | 667 | 373 | 3.31 | 2.30 | `package.json`, `src/parser.mjs` |
| `frontend-filter` | yes | pass | 1337 | 464 | 3.08 | 2.53 | `app.js` |
| `multi-file-cart` | yes | pass | 1217 | 620 | 3.10 | 2.60 | `src/cart.mjs` |
| `sandbox-canary` | yes | pass | 816 | 399 | 2.98 | 2.11 | `src/exportPlan.mjs` |
| `schema-validation` | no | verifier | 1058 | 816 | 3.37 | 2.99 | `src/validateConfig.mjs` |

Failure notes:

- `backend-api`: implementation was close but failed expected cents/line-count behavior. It rounded discount to 644 instead of 645, counted quantity as line count, and computed taxable/tax/total differently from the verifier.
- `schema-validation`: failed to throw one expected validation error matching `/config|mode|service|endpoint|duplicate|retry|timeout|header/i`.

Both failures were normal verifier failures. They were not timeouts, sandbox violations, protected-file edits, or canary corruption.

## Interpretation

This is not a practical preferred local coding stack for this machine today. It is useful as proof that the 180B K160 DS4 GGUF can be made operational on the AMD 8060S through WSL ROCm, but it needs a local DS4 patch and SSD streaming. The latency is high enough that broad benchmark sweeps are expensive, and full-residency ROCm loading did not work.

The model quality in this one-pass benchmark was respectable for such a constrained run: 5/7 real-usage tasks passed, and the two failures were semantic/test mismatches rather than malformed output. For day-to-day local coding, previous smaller local coder stacks remain more practical unless the goal is specifically to test this 180B DS4 path.

## Artifacts

- Operational note: `notes/2026-06-26_09-24-19_deepseek-v4-flash-k160-ds4-run.md`
- Real-usage rollup: `benchmarks/real-usage-agent-benchmark/reports/2026-06-26_ds4-k160-real-usage-rollup.md`
- Synthetic DS4 bench CSV: `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-rocm-streaming/ds4-bench-64-256.csv`
- API smoke JSON: `benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k160-rocm-streaming/openai-compatible-calibration-short.json`
- Raw real-usage summaries: `benchmarks/real-usage-agent-benchmark/results/20260626-ds4-k160-real-usage/`
- Runtime logs: `logs/2026-06-26_ds4-*`
- Local DS4 checkout and patch: `build/ds4/`
- Downloaded GGUF: `downloads/ds4/DeepSeek-V4-Flash-Spark-Q2-REAP-ds4.gguf`

## Cleanup

After the benchmark, the DS4 server was stopped. A process audit found no remaining `ds4-server`, `ds4 --rocm`, `llama-server`, or `llama-bench` process other than the audit command itself. The model file, DS4 build tree, benchmark results, and logs remain under local-only artifact directories.
