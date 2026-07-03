# Real-Usage Result Rollup

Generated: 2026-06-23T21:38:01.039Z

Inputs:
- [results/20260622-214606-lmstudio-direct-matrix/lmstudio-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-075932-lmstudio-opencode-matrix/lmstudio-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-211617-lmstudio-pi-matrix/lmstudio-pi-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-222016-ollama-windows-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-224125-ollama-wsl-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-230219-ollama-windows-opencode-matrix/ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-232051-ollama-windows-pi-matrix/ollama-pi-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-232857-ollama-wsl-pi-matrix/ollama-pi-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| direct-api | `google/gemma-4-12b` | 1 | 3 | 0 |  |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | 0 | 3 | 0 |  |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | 0 | 3 | 0 |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | 0 | 3 | 0 |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | 0 | 3 | 0 |  |  |  |  |  |
| direct-api | `qwen3-0.6b` | 0 | 3 | 0 |  |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | 0 | 3 | 0 |  |  |  |  |  |
| ollama-direct-api:windows | `gemma3:12b` | 1 | 3 | 0 | 3706.8 | 18.12 | 14.93 |  |  |
| ollama-direct-api:windows | `gemma3n:e4b` | 0 | 3 | 0 | 2121.8 | 40.05 | 29.71 |  |  |
| ollama-direct-api:windows | `qwen3-coder:30b` | 1 | 3 | 1 | 1216.6 | 47.62 | 43.01 |  |  |
| ollama-direct-api:wsl | `gemma3:12b` | 1 | 3 | 0 | 28068.9 | 7.55 | 3.4 |  |  |
| ollama-direct-api:wsl | `gemma3n:e4b` | 0 | 3 | 0 | 12873.1 | 16.33 | 9.29 |  |  |
| ollama-direct-api:wsl | `qwen3-coder:30b` | 1 | 3 | 0 | 10816.4 | 17.06 | 13.47 |  |  |
| ollama-opencode:windows | `gemma3:12b` | 0 | 4 | 0 |  |  |  |  |  |
| ollama-opencode:windows | `gemma3n:e4b` | 0 | 4 | 0 |  |  |  |  |  |
| ollama-opencode:windows | `qwen3-coder:30b` | 2 | 4 | 1 |  | 28.41 | 20.84 | 40 | 2 |
| ollama-pi:windows | `gemma3:12b` | 0 | 1 | 0 |  |  |  |  |  |
| ollama-pi:windows | `gemma3n:e4b` | 0 | 1 | 0 |  |  |  |  |  |
| ollama-pi:windows | `qwen3-coder:30b` | 1 | 1 | 0 | 101 |  |  | 10 |  |
| ollama-pi:wsl | `gemma3:12b` | 0 | 1 | 0 |  |  |  |  |  |
| ollama-pi:wsl | `gemma3n:e4b` | 0 | 1 | 0 |  |  |  |  |  |
| ollama-pi:wsl | `qwen3-coder:30b` | 1 | 1 | 1 | 41 |  |  | 12 |  |
| opencode | `google/gemma-4-12b` | 0 | 4 | 4 |  |  |  | 4 |  |
| opencode | `google/gemma-4-e4b` | 1 | 4 | 3 |  |  |  | 13 | 1 |
| opencode | `qwen/qwen3-coder-30b` | 2 | 4 | 4 |  |  |  | 53 | 5 |
| pi | `qwen/qwen3-coder-30b` | 1 | 1 | 0 |  |  |  |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| direct-api | `google/gemma-4-12b` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `frontend-filter` | yes | pass | no |  |  |  |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `frontend-filter` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `frontend-filter` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `frontend-filter` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `frontend-filter` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `frontend-filter` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen3-0.6b` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen3-0.6b` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `qwen3-0.6b` | `frontend-filter` | no | no-edit | no |  |  |  |  |  |  |  |
| opencode | `qwen/qwen3-coder-30b` | `backend-api` | no | timeout | yes |  |  |  | 9 | 1 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `qwen/qwen3-coder-30b` | `multi-file-cart` | yes | pass | yes |  |  |  | 10 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `qwen/qwen3-coder-30b` | `frontend-filter` | yes | pass | yes |  |  |  | 17 | 0 | app.js | [json](../../../public-results/results-summary.md) |
| opencode | `qwen/qwen3-coder-30b` | `failing-command-recovery` | no | allowlist | yes |  |  |  | 17 | 4 | final_verification.md, package.json, solution.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `backend-api` | no | timeout | yes |  |  |  | 3 | 0 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `multi-file-cart` | yes | pass | no |  |  |  | 3 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `frontend-filter` | no | timeout | yes |  |  |  | 3 | 1 | app.js | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `failing-command-recovery` | no | timeout | yes |  |  |  | 4 | 0 | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `backend-api` | no | timeout | yes |  |  |  | 1 | 0 |  | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `multi-file-cart` | no | timeout | yes |  |  |  | 2 | 0 |  | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `frontend-filter` | no | timeout | yes |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `failing-command-recovery` | no | timeout | yes |  |  |  | 1 | 0 |  | [json](../../../public-results/results-summary.md) |
| pi | `qwen/qwen3-coder-30b` | `multi-file-cart` | yes | pass | no |  |  |  |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `qwen3-coder:30b` | `backend-api` | no | timeout | yes |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `qwen3-coder:30b` | `schema-validation` | no | verifier | no | 1220.7 | 47.24 | 676 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `qwen3-coder:30b` | `frontend-filter` | yes | pass | no | 1212.5 | 48 | 449 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `gemma3n:e4b` | `backend-api` | no | verifier | no | 2294.7 | 40.02 | 602 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `gemma3n:e4b` | `schema-validation` | no | verifier | no | 1774.5 | 40.4 | 434 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `gemma3n:e4b` | `frontend-filter` | no | verifier | no | 2296.2 | 39.73 | 90 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `gemma3:12b` | `backend-api` | no | verifier | no | 4238.8 | 18.09 | 958 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `gemma3:12b` | `schema-validation` | no | verifier | no | 3125.9 | 17.98 | 683 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows | `gemma3:12b` | `frontend-filter` | yes | pass | no | 3755.7 | 18.3 | 114 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `qwen3-coder:30b` | `backend-api` | no | verifier | no | 13710.2 | 15.72 | 1185 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `qwen3-coder:30b` | `schema-validation` | no | verifier | no | 9469.1 | 17.21 | 670 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `qwen3-coder:30b` | `frontend-filter` | yes | pass | no | 9269.8 | 18.24 | 450 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `gemma3n:e4b` | `backend-api` | no | verifier | no | 13702.1 | 16.22 | 572 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `gemma3n:e4b` | `schema-validation` | no | verifier | no | 11440.2 | 16.4 | 434 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `gemma3n:e4b` | `frontend-filter` | no | verifier | no | 13476.9 | 16.37 | 90 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `gemma3:12b` | `backend-api` | no | verifier | no | 33181.3 | 7.53 | 67 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `gemma3:12b` | `schema-validation` | no | verifier | no | 23150.2 | 7.48 | 671 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl | `gemma3:12b` | `frontend-filter` | yes | pass | no | 27875.1 | 7.63 | 114 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `qwen3-coder:30b` | `backend-api` | no | timeout | yes |  | 30.71 | 4998 | 10 | 0 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | no |  | 28.75 | 1652 | 6 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `qwen3-coder:30b` | `frontend-filter` | no | allowlist | no |  | 27.26 | 3408 | 14 | 2 | app.js, debug.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `qwen3-coder:30b` | `failing-command-recovery` | yes | pass | no |  | 26.9 | 1914 | 10 | 0 | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3n:e4b` | `backend-api` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3n:e4b` | `multi-file-cart` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3n:e4b` | `frontend-filter` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3n:e4b` | `failing-command-recovery` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3:12b` | `backend-api` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3:12b` | `multi-file-cart` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3:12b` | `frontend-filter` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows | `gemma3:12b` | `failing-command-recovery` | no | verifier | no |  |  |  | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| ollama-pi:windows | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | no | 101 |  |  | 10 |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-pi:windows | `gemma3n:e4b` | `multi-file-cart` | no | verifier | no |  |  |  | 0 |  |  | [json](../../../public-results/results-summary.md) |
| ollama-pi:windows | `gemma3:12b` | `multi-file-cart` | no | verifier | no |  |  |  | 0 |  |  | [json](../../../public-results/results-summary.md) |
| ollama-pi:wsl | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | yes | 41 |  |  | 12 |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-pi:wsl | `gemma3n:e4b` | `multi-file-cart` | no | verifier | no |  |  |  | 0 |  |  | [json](../../../public-results/results-summary.md) |
| ollama-pi:wsl | `gemma3:12b` | `multi-file-cart` | no | verifier | no |  |  |  | 0 |  |  | [json](../../../public-results/results-summary.md) |
