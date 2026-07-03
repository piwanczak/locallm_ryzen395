# Ollama WSL ROCm Fairness Correction, 2026-06-24

This report corrects the earlier Ollama Windows-vs-WSL comparison. The previous WSL Ollama rows were not a fair GPU comparison: WSL Ollama loaded Qwen on CPU only. The corrected comparison keeps Windows Ollama as the Windows endpoint and uses the verified WSL ROCm llama.cpp endpoint for the WSL GPU lane, using the same local Ollama Qwen GGUF blob.

## What Was Wrong

WSL itself had ROCm visibility:

- `/dev/dxg` was present.
- `rocminfo` saw `gfx1151` / `AMD Radeon(TM) 8060S Graphics`.
- The `ollama` service user was in `video` and `render`.

But WSL Ollama did not use that GPU path. After installing the official `ollama-linux-amd64-rocm.tar.zst` runtime and forcing `OLLAMA_IGPU_ENABLE=1`, `OLLAMA_LLM_LIBRARY=rocm_v7_2`, and `ROCR_VISIBLE_DEVICES=0`, the service still logged:

```text
inference compute id=cpu library=cpu
```

and model placement still showed:

```text
qwen3-coder:30b ... 100% CPU ... CONTEXT 4096
```

The immediate reason is that Ollama's WSL service path did not discover the ROCDXG ROCm device, even though direct ROCm tools and the AMD llama.cpp runtime can use it.

## Corrected Endpoint

For the fair WSL GPU lane, I started the existing AMD ROCm/ROCDXG llama.cpp launcher against the exact Ollama model blob:

```text
/usr/share/ollama/.ollama/models/blobs/sha256-1194192cf2a187eb02722edcc3f77b11d21f537048ce04b67ccf8ba78863006a
```

Device evidence from `benchmarks/wsl-local-inference-benchmark/logs/20260624-fair-rocm-262k-smoke/llama-server-amd.log`:

```text
ggml_cuda_init: found 1 ROCm devices
Device 0: AMD Radeon(TM) 8060S Graphics, gfx1151
llama_model_load_from_file_impl: using device ROCm0
load_tensors: offloaded 49/49 layers to GPU
llama_context: n_ctx = 262144
llama_kv_cache: ROCm0 KV buffer size = 24576.00 MiB
```

Windows Ollama placement after the corrected direct run showed:

```text
qwen3-coder:30b ... 45 GB ... 100% GPU ... CONTEXT 262144
```

The direct wrapper requested `4096` context for Windows, but Ollama's OpenAI-compatible route ignored that request and loaded the model at `262144`. I therefore loaded the WSL ROCm endpoint at `262144` for the corrected comparison.

## Corrected Results

| Lane | Endpoint | Passes | Main result | Avg TTFT | Avg TPS | Avg wall TPS |
| --- | --- | ---: | --- | ---: | ---: | ---: |
| Direct API | Windows Ollama GPU | 1/3 | Passed `frontend-filter`; failed backend/schema verifiers. | 1.33 s | 46.12 | 42.15 |
| Direct API | WSL ROCm llama.cpp | 0/3 | Failed all three direct verifiers. | 3.08 s | 38.37 | 32.81 |
| OpenCode | Windows Ollama GPU | 3/4 | Passed all except `backend-api`, which timed out. | n/a | 25.85 | 18.69 |
| OpenCode | WSL ROCm llama.cpp | 3/4 | Same pass count; `backend-api` timed out. | n/a | 13.11 | 9.96 |
| Pi Docker | Windows Ollama GPU | 1/1 | Passed `multi-file-cart`; canary unchanged. | 0.08 s | n/a | n/a |
| Pi Docker | WSL ROCm llama.cpp | 1/1 | Passed `multi-file-cart`; canary unchanged. | 0.11 s | n/a | n/a |

## Interpretation

The corrected result is not "WSL is hopelessly slow." It is:

- WSL Ollama is still not a valid performance endpoint here because it remains CPU-only.
- Verified WSL ROCm llama.cpp is the fair Linux GPU path.
- Windows Ollama remains faster in direct API and much faster in OpenCode at the same actual 262k context.
- Pi is clean on both corrected endpoints; WSL Pi no longer times out under the ROCm llama.cpp endpoint.
- `backend-api` remains the hard discriminator. Neither corrected endpoint solved it.

## Promoted Artifacts

| Artifact | Link |
| --- | --- |
| Corrected rollup Markdown | [2026-06-24-ollama-fair-wsl-rocm-correction-rollup.md](2026-06-24-ollama-fair-wsl-rocm-correction-rollup.md) |
| Corrected rollup JSON | [2026-06-24-ollama-fair-wsl-rocm-correction-rollup.json](2026-06-24-ollama-fair-wsl-rocm-correction-rollup.json) |
| Windows direct matrix | [summary](../../../public-results/results-summary.md) |
| WSL ROCm direct matrix | [summary](../../../public-results/results-summary.md) |
| Windows OpenCode matrix | [summary](../../../public-results/results-summary.md) |
| WSL ROCm OpenCode matrix | [summary](../../../public-results/results-summary.md) |
| Windows Pi matrix | [summary](../../../public-results/results-summary.md) |
| WSL ROCm Pi matrix | [summary](../../../public-results/results-summary.md) |
| WSL ROCm 262k server log | [llama-server-amd.log](../../../public-results/results-summary.md) |

## Updated Recommendation

Use Windows Ollama when the goal is a simple Qwen OpenAI-compatible endpoint with good speed and clean OpenCode/Pi behavior. Use WSL ROCm llama.cpp when the goal is an honest Linux/WSL GPU path. Do not use WSL Ollama for performance conclusions until Ollama discovers ROCDXG/ROCm correctly.

Keep the old WSL Ollama CPU-only result as a diagnostic artifact, not as a fair Windows-vs-WSL performance benchmark.
