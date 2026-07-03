# Real-Usage Result Rollup

Generated: 2026-06-27T05:48:05.116Z

Inputs:
- [results/20260627-072603-ollama-windows-ornith-9b-q4km-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | 1 | 7 | 0 | 39116.6 | 42.93 | 17.18 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `backend-api` | no | verifier | no |  | 14.06 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `multi-file-cart` | no | verifier | no | 70043.6 | 61.39 | 1634 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `schema-validation` | no | verifier | no |  | 17.53 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `cli-report` | yes | pass | no | 71310.6 | 59.52 | 1938 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `frontend-filter` | no | verifier | no | 17161.5 | 66.24 | 385 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `failing-command-recovery` | no | verifier | no | 7983.1 | 25.06 | 539 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `sandbox-canary` | no | verifier | no | 29084.2 | 56.73 | 772 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
