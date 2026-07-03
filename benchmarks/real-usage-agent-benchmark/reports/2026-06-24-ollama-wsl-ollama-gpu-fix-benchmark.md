# WSL Ollama GPU Fix and Benchmark Rerun, 2026-06-24

This run fixes the earlier WSL Ollama diagnosis. WSL Ollama can use the AMD GPU on this machine, but it needs explicit ROCDXG/HSA loader settings. After the fix, `qwen3-coder:30b` loads through Ollama on WSL with `100% GPU` placement.

## Working WSL Ollama Configuration

The successful service override is:

```ini
[Service]
Environment=OLLAMA_HOST=127.0.0.1:11435
Environment=OLLAMA_DEBUG=1
Environment=OLLAMA_IGPU_ENABLE=1
Environment=OLLAMA_LLM_LIBRARY=rocm_v7_2
Environment=HSA_ENABLE_DXG_DETECTION=1
Environment=LD_PRELOAD=/usr/local/lib/ollama/rocm_v7_2/libhsa-runtime64.so.1
Environment=LD_LIBRARY_PATH=/usr/local/lib/ollama/rocm_v7_2:/usr/local/lib/ollama
Environment=GGML_BACKEND_PATH=/usr/local/lib/ollama/rocm_v7_2:/usr/local/lib/ollama
Environment=OLLAMA_LIBRARY_PATH=/usr/local/lib/ollama
Environment=OLLAMA_CONTEXT_LENGTH=4096
Environment=OLLAMA_LOAD_TIMEOUT=10m
Environment=OLLAMA_NUM_PARALLEL=1
Environment=LLAMA_ARG_FIT=off
```

The two decisive changes after GPU discovery were:

- `LLAMA_ARG_FIT=off`, because the default llama.cpp fit pass stalled in WSL Ollama.
- `LD_PRELOAD=/usr/local/lib/ollama/rocm_v7_2/libhsa-runtime64.so.1`, because `librocdxg.so` otherwise failed to resolve `hsa_signal_store_screlease` during model tensor load.

Target evidence:

```text
qwen3-coder:30b ... 18 GB ... 100% GPU ... CONTEXT 4096
runner.inference="[{ID:0 Library:ROCm}]"
runner.vram="17.6 GiB"
llama-server started in 130.94 seconds
```

## Benchmark Rerun

The rerun used the same real-usage benchmark family as the prior Ollama comparison:

- Direct API: `backend-api`, `schema-validation`, `frontend-filter`
- OpenCode: `backend-api`, `multi-file-cart`, `frontend-filter`, `failing-command-recovery`
- Pi Docker: `multi-file-cart`

The new fixed endpoint was `wsl-ollama-gpu-fixed-4k`:

- Windows/OpenCode direct endpoint: `http://127.0.0.1:11435/v1`
- Pi Docker endpoint: `http://host.docker.internal:11435/v1`

## Results

| Lane | Endpoint | Passes | Timeouts | Avg TTFT | Avg TPS | Avg wall TPS | Main result |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Direct API | Windows Ollama GPU | 1/3 | 0 | 1.33 s | 46.12 | 42.15 | Passed `frontend-filter`; failed backend/schema verifiers. |
| Direct API | WSL ROCm llama.cpp | 0/3 | 0 | 3.08 s | 38.37 | 32.81 | Failed all direct verifiers. |
| Direct API | WSL Ollama GPU fixed | 1/3 | 0 | 9.88 s | 10.33 | 8.95 | Same pass count as Windows direct, but much slower. |
| OpenCode | Windows Ollama GPU | 3/4 | 1 | n/a | 25.85 | 18.69 | Passed all except `backend-api`, which timed out. |
| OpenCode | WSL ROCm llama.cpp | 3/4 | 1 | n/a | 13.11 | 9.96 | Same pass count as Windows, slower. |
| OpenCode | WSL Ollama GPU fixed | 0/4 | 0 | n/a | 4.72 | 2.24 | Failed all four; outputs were short and low-quality. |
| Pi Docker | Windows Ollama GPU | 1/1 | 0 | 0.08 s | n/a | n/a | Passed `multi-file-cart`. |
| Pi Docker | WSL ROCm llama.cpp | 1/1 | 0 | 0.11 s | n/a | n/a | Passed `multi-file-cart`. |
| Pi Docker | WSL Ollama GPU fixed | 0/1 | 1 | 0.10 s | n/a | n/a | Reached endpoint and tools, then timed out after 15 minutes. |

## Interpretation

The original statement "WSL Ollama is CPU-only" is no longer correct after the service fix. The corrected statement is:

- WSL Ollama can run Qwen on the AMD GPU through ROCm/ROCDXG.
- WSL Ollama's fixed GPU lane is still not the best practical endpoint here.
- Windows Ollama remains the best Ollama endpoint for Qwen.
- Verified WSL ROCm llama.cpp remains the better Linux/WSL GPU endpoint.
- WSL Ollama fixed GPU is useful as a diagnostic proof and fallback, not as the promoted benchmark endpoint.

The poor OpenCode/Pi result appears performance-driven rather than connectivity-driven. The Pi run reached the endpoint, generated multiple requests, and still had `ollama ps` showing Qwen at `100% GPU`; it timed out because the lane was too slow for the task window.

## Promoted Artifacts

| Artifact | Link |
| --- | --- |
| Combined rollup Markdown | [2026-06-24-ollama-wsl-gpu-fixed-rollup.md](2026-06-24-ollama-wsl-gpu-fixed-rollup.md) |
| Combined rollup JSON | [2026-06-24-ollama-wsl-gpu-fixed-rollup.json](2026-06-24-ollama-wsl-gpu-fixed-rollup.json) |
| WSL Ollama GPU fix note | [note](../../../public-results/results-summary.md) |
| WSL Ollama fixed direct matrix | [summary](../../../public-results/results-summary.md) |
| WSL Ollama fixed OpenCode matrix | [summary](../../../public-results/results-summary.md) |
| WSL Ollama fixed Pi matrix | [summary](../../../public-results/results-summary.md) |
| Successful Qwen GPU load log | [trial log](../../../public-results/results-summary.md) |
| Successful Gemma GPU load log | [trial log](../../../public-results/results-summary.md) |

## Updated Recommendation

Use Windows Ollama when the goal is a simple Qwen OpenAI-compatible endpoint with good speed and clean OpenCode/Pi behavior. Use WSL ROCm llama.cpp when the goal is an honest Linux/WSL GPU path. Keep WSL Ollama GPU fixed as a working but slower experimental endpoint, and do not promote it over the other two lanes for practical coding-agent work.
