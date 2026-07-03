# Real-Usage Result Rollup

Generated: 2026-06-29T20:04:47.704Z

Inputs:
- [results/20260629-215824-ollama-windows-qwen36-q4km-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | 4 | 7 | 0 |  | 40.6 | 35.49 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | `backend-api` | no | verifier | no |  | 39.76 | 730 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | `multi-file-cart` | yes | pass | no |  | 41.34 | 719 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | `schema-validation` | no | verifier | no |  | 40.76 | 895 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | `cli-report` | yes | pass | no |  | 41.28 | 864 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | `frontend-filter` | no | verifier | no |  | 41.24 | 236 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | `failing-command-recovery` | yes | pass | no |  | 39.3 | 363 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen36-q4km | `hf.co/lmstudio-community/Qwen3.6-35B-A3B-GGUF:Q4_K_M` | `sandbox-canary` | yes | pass | no |  | 40.5 | 325 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
