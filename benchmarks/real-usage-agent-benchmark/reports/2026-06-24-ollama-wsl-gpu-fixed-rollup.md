# Real-Usage Result Rollup

Generated: 2026-06-24T06:47:43.141Z

Inputs:
- [results/20260624-000943-ollama-windows-fair-4k-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-001457-ollama-wsl-rocm-fair-262k-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-080828-ollama-wsl-ollama-gpu-fixed-4k-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-003717-ollama-windows-fair-opencode-matrix/ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-001746-ollama-wsl-rocm-fair-262k-opencode-matrix/ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-081621-ollama-wsl-ollama-gpu-fixed-4k-opencode-matrix/ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-004930-ollama-windows-fair-pi-matrix/ollama-pi-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-003529-ollama-wsl-rocm-fair-262k-pi-matrix/ollama-pi-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-083200-ollama-wsl-ollama-gpu-fixed-4k-pi-matrix/ollama-pi-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-fair-4k | `qwen3-coder:30b` | 1 | 3 | 0 | 1325.9 | 46.12 | 42.15 |  |  |
| ollama-direct-api:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | 1 | 3 | 0 | 9880.2 | 10.33 | 8.95 |  |  |
| ollama-direct-api:wsl-rocm-fair-262k | `qwen3-coder:30b` | 0 | 3 | 0 | 3082.7 | 38.37 | 32.81 |  |  |
| ollama-opencode:windows-fair | `qwen3-coder:30b` | 3 | 4 | 1 |  | 25.85 | 18.69 | 43 | 1 |
| ollama-opencode:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | 0 | 4 | 0 |  | 4.72 | 2.24 | 12 | 4 |
| ollama-opencode:wsl-rocm-fair-262k | `qwen3-coder:30b` | 3 | 4 | 1 |  | 13.11 | 9.96 | 37 | 1 |
| ollama-pi:windows-fair | `qwen3-coder:30b` | 1 | 1 | 0 | 82 |  |  | 7 |  |
| ollama-pi:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | 0 | 1 | 1 | 98 |  |  | 21 |  |
| ollama-pi:wsl-rocm-fair-262k | `qwen3-coder:30b` | 1 | 1 | 0 | 108 |  |  | 8 |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-fair-4k | `qwen3-coder:30b` | `backend-api` | no | verifier | no | 1485.7 | 45.84 | 986 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-fair-4k | `qwen3-coder:30b` | `schema-validation` | no | verifier | no | 1209.9 | 46.16 | 678 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-fair-4k | `qwen3-coder:30b` | `frontend-filter` | yes | pass | no | 1282.2 | 46.36 | 449 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl-rocm-fair-262k | `qwen3-coder:30b` | `backend-api` | no | verifier | no | 3496.5 | 36.15 | 1153 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl-rocm-fair-262k | `qwen3-coder:30b` | `schema-validation` | no | verifier | no | 3143.8 | 38.88 | 671 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl-rocm-fair-262k | `qwen3-coder:30b` | `frontend-filter` | no | verifier | no | 2607.7 | 40.07 | 483 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `backend-api` | no | verifier | no | 11715.6 | 10.14 | 1009 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `schema-validation` | no | verifier | no | 9399.4 | 10.16 | 664 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `frontend-filter` | yes | pass | no | 8525.6 | 10.7 | 448 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-fair | `qwen3-coder:30b` | `backend-api` | no | timeout | yes |  | 27.82 | 3198 | 8 | 0 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-fair | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | no |  | 26.25 | 1964 | 7 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-fair | `qwen3-coder:30b` | `frontend-filter` | yes | pass | no |  | 24.53 | 3516 | 15 | 1 | app.js | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-fair | `qwen3-coder:30b` | `failing-command-recovery` | yes | pass | no |  | 24.82 | 2444 | 13 | 0 | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-rocm-fair-262k | `qwen3-coder:30b` | `backend-api` | no | timeout | yes |  | 13.53 | 3484 | 8 | 1 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-rocm-fair-262k | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | no |  | 13.08 | 2644 | 8 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-rocm-fair-262k | `qwen3-coder:30b` | `frontend-filter` | yes | pass | no |  | 12.58 | 1873 | 8 | 0 | app.js | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-rocm-fair-262k | `qwen3-coder:30b` | `failing-command-recovery` | yes | pass | no |  | 13.27 | 2375 | 13 | 0 | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `backend-api` | no | verifier | no |  | 4.43 | 218 | 1 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `multi-file-cart` | no | verifier | no |  | 1.28 | 869 | 10 | 4 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `frontend-filter` | no | verifier | no |  | 9.22 | 112 | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `failing-command-recovery` | no | verifier | no |  | 3.95 | 168 | 1 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-pi:windows-fair | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | no | 82 |  |  | 7 |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-pi:wsl-rocm-fair-262k | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | no | 108 |  |  | 8 |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-pi:wsl-ollama-gpu-fixed-4k | `qwen3-coder:30b` | `multi-file-cart` | no | timeout | yes | 98 |  |  | 21 |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
