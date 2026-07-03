# DeepSeek V4 Flash Smaller Quant Search

Date: 2026-06-26

## Summary

I did not find a smaller quant of the exact `0xSero/DeepSeek-V4-Flash-180B-GGUF` K160 file. The only smaller standalone DS4-compatible candidate I found was the related `0xSero/DeepSeek-V4-Flash-162B-GGUF` Spark-Mini K144 variant.

I downloaded and tested that K144 candidate. It can be made to start with another local DS4 patch, passes basic CLI/API smoke tests, and is faster than K160 in the tiny synthetic bench. It is not reliable in the real-usage suite: 1/7 tasks passed, and the DS4 server log showed repeated K144 runtime errors involving `-1` expert IDs and `rocm decode failed`.

Conclusion: K144 is smaller and faster in short synthetic runs, but K160 remains the better tested local DS4 path from this family on this machine.

## Sources Checked

- 180B DS4 GGUF: <https://huggingface.co/0xSero/DeepSeek-V4-Flash-180B-GGUF>
- 162B DS4 GGUF: <https://huggingface.co/0xSero/DeepSeek-V4-Flash-162B-GGUF>
- Antirez DS4 GGUF repo: <https://huggingface.co/antirez/deepseek-v4-gguf>
- Huihui abliterated DS4 GGUF repo: <https://huggingface.co/huihui-ai/Huihui-DeepSeek-V4-Flash-abliterated-ds4-GGUF>
- Persadian IQ1_S-XL repo: <https://huggingface.co/persadian/DeepSeek-V4-Flash-IQ1_S-XL>

## Candidate Filter

| Repo | Candidate | Size | Decision |
| --- | --- | ---: | --- |
| `0xSero/DeepSeek-V4-Flash-180B-GGUF` | `DeepSeek-V4-Flash-Spark-Q2-REAP-ds4.gguf` | 57,468,757,600 bytes | Existing K160 baseline |
| `0xSero/DeepSeek-V4-Flash-162B-GGUF` | `DeepSeek-V4-Flash-Spark-Mini-Q2-REAP-ds4.gguf` | 52,593,532,000 bytes | Tested |
| `antirez/deepseek-v4-gguf` | Flash IQ2/Q4 files | 86.7GB+ | Larger than baseline |
| `huihui-ai/Huihui-DeepSeek-V4-Flash-abliterated-ds4-GGUF` | IQ2/Q2/Q4 abliterated files | 80.2GB+ | Larger and abliterated |
| `persadian/DeepSeek-V4-Flash-IQ1_S-XL` | `DeepSeek-V4-Flash-IQ1_S-XL.gguf` | 61,540,805,344 bytes | Lower nominal quant, but larger than K160 baseline |

The tiny `DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf` files in some repos are MTP sidecars, not standalone base model candidates.

## Tested Candidate

Downloaded file:

```text
/root/ds4-models/DeepSeek-V4-Flash-Spark-Mini-Q2-REAP-ds4.gguf
```

Validation:

| Field | Value |
| --- | --- |
| Size | 52,593,532,000 bytes / 48.98 GiB |
| SHA256 | `e917278028d7a9e25dfc9d04bf5848375dad7573c5aeab1720d6a83714352406` |
| DS4 shape | DeepSeek V4 Flash Spark Mini K144 |
| Logical parameters | 163.12B |
| Experts | 144 count, 6 used |

Local patch:

- `build/ds4/ds4.c`: added `DS4_SHAPE_FLASH_SPARK_MINI_K144`.
- `build/ds4/rocm/ds4_rocm_runtime.cuh`: added K144 and K160 expert-count constants.
- `build/ds4/rocm/ds4_rocm_router.cuh`: added K144/K160 router dispatch branches.

## Runtime Results

Non-streaming ROCm did not become usable. It progressed to:

```text
ds4: ROCm prepared model tensor mappings 32.28 GiB
```

Then it stopped making visible progress for about five minutes and was terminated.

SSD streaming worked:

| Test | Result |
| --- | --- |
| Raw CLI smoke | Generated text; prefill 0.71 t/s, generation 2.02 t/s |
| API server | `/v1/models` served `DeepSeek V4 Flash Spark Mini K144` at 8192 context |
| API calibration | Passed; first byte 4914.5 ms, first content 16298.8 ms, decode estimate 2.68 tok/s |

## Synthetic Bench

Result CSV:

```text
benchmarks/wsl-local-inference-benchmark/results/20260626-ds4-k144-rocm-streaming/ds4-bench-64-256.csv
```

| Context tokens | Prefill tokens | Prefill t/s | Gen tokens | Gen t/s |
| ---: | ---: | ---: | ---: | ---: |
| 64 | 64 | 2.83 | 16 | 3.87 |
| 128 | 64 | 8.12 | 16 | 4.78 |
| 192 | 64 | 10.93 | 16 | 4.68 |
| 256 | 64 | 13.15 | 16 | 5.68 |

For comparison, K160 previously produced 3.19, 3.60, 3.61, and 4.09 gen t/s on the same synthetic rows.

## Real-Usage Benchmark

Run details:

- Run ID: `20260626-ds4-k144-real-usage`
- Endpoint: `http://127.0.0.1:8000/v1`
- Model: `deepseek-chat`
- Context: 8192
- Max attempts: 1
- Max tokens: 2048
- Rollup: `benchmarks/real-usage-agent-benchmark/reports/2026-06-26_ds4-k144-real-usage-rollup.md`
- Rendered rollup: `benchmarks/real-usage-agent-benchmark/reports/2026-06-26_ds4-k144-real-usage-rollup.html`

Overview:

| Tasks | Passes | Timeouts | Allowlist violations | Canary failures | Avg TTFT | Avg decode | Avg wall TPS |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 7 | 1 | 0 | 0 | 0 | 33414 ms | 2.73 tok/s | 1.95 tok/s |

Task rows:

| Task | Pass | Output tokens | Decode tok/s | Modified files |
| --- | --- | ---: | ---: | --- |
| `backend-api` | no | 78 | 2.73 | none |
| `cli-report` | no | 619 | 4.04 | none |
| `failing-command-recovery` | yes | 311 | 4.06 | `package.json`, `src/parser.mjs` |
| `frontend-filter` | no | 0 | 0 | none |
| `multi-file-cart` | no | 0 | 0 | none |
| `sandbox-canary` | no | 347 | 4.01 | `src/exportPlan.mjs` |
| `schema-validation` | no | 545 | 4.27 | none |

The task pass rate is much worse than K160's earlier 5/7. Some failures were ordinary verifier failures, but several were contaminated by runtime decode errors: the server log had 88 lines matching `rocm decode failed`, `selected expert id -1`, or `seed expert id -1`.

## Disk Impact

The K144 file is currently left in WSL for reproducibility:

```text
/root/ds4-models/DeepSeek-V4-Flash-Spark-Mini-Q2-REAP-ds4.gguf
```

After the run, Windows `C:` had about 48 GiB free. Removing the K144 WSL file would recover roughly 49 GiB from the WSL VHD over time, subject to VHD compaction behavior.

## Recommendation

Do not promote K144 as the preferred local DeepSeek V4 Flash path. It is smaller and faster in short synthetic runs, but the patched DS4 K144 ROCm streaming path is not stable enough for real work. Keep K160 as the better tested DS4 fallback unless upstream DS4 adds official Spark-Mini/K144 support or the local patch is hardened beyond shape/router dispatch.
