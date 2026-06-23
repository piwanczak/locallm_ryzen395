# Phase 01 WSL ROCm Runtime Report

Date: 2026-06-21

## Runtime

| Item | Value |
| --- | --- |
| Distro | `Ubuntu-24.04` under WSL2 |
| Runtime | AMD validated llama.cpp ROCm binary, build `8407` |
| Model | `downloads/Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf` |
| Backend | ROCm/HIP through ROCDXG and `/dev/dxg` |
| Server wrapper | `scripts/start-wsl-llama-server-amd.sh` |
| Stop wrapper | `scripts/stop-wsl-llama-server-amd.sh` |

## Loader Finding

Direct `llama-server` invocation failed until the extracted runtime directory was placed on `LD_LIBRARY_PATH`. The checked-in launcher sets:

```bash
HSA_ENABLE_DXG_DETECTION=1
LD_LIBRARY_PATH="$runtime_dir:${LD_LIBRARY_PATH:-}"
```

## Smoke Results

Artifacts:

- `results/20260621-212450-calibration-qwen3-coder-30b-q2-wsl-rocm-single.json`
- `results/20260621-212503-calibration-qwen3-coder-30b-q2-wsl-rocm-4way.json`

| Shape | Context | Result |
| --- | ---: | ---: |
| Single request, 128 completion tokens | `4096` | `70.20 tok/s`, first content `752.9 ms` |
| 4-way request, 128 completion tokens each | `4096` | `84.65 tok/s` aggregate |

## Decision

The WSL ROCm llama.cpp path is viable for small local coding-agent experiments. Use `CTX_SIZE=8192` and `PARALLEL=1` as the default agent profile. Use higher `PARALLEL` only for throughput tests.
