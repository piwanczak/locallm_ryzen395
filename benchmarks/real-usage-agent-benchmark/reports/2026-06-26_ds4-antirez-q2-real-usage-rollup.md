# Real-Usage Result Rollup

Generated: 2026-06-26T15:20:12.188Z

Inputs:
- [results/20260626-ds4-antirez-q2-real-usage/ds4-antirez-q2-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | 3 | 7 | 0 | 41370.5 | 2.69 | 2.15 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | `backend-api` | no | verifier | no | 31382.7 | 2.82 | 715 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | `cli-report` | yes | pass | no | 37649.9 | 2.63 | 729 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | `failing-command-recovery` | yes | pass | no | 53341.9 | 2.86 | 363 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | `frontend-filter` | yes | pass | no | 36794.4 | 2.42 | 142 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | `multi-file-cart` | no | verifier | no | 35210.4 | 2.65 | 500 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | `sandbox-canary` | no | verifier | no | 61014.1 | 2.75 | 495 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-antirez-q2-imatrix-rocm-ssd45-ctx8192 | `deepseek-chat (antirez deepseek-v4-gguf q2-imatrix DS4)` | `schema-validation` | no | verifier | no | 34200.4 | 2.68 | 983 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
