# Real-Usage Result Rollup

Generated: 2026-06-26T07:24:11.898Z

Inputs:
- [results/20260626-ds4-k160-real-usage/ds4-k160-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | 5 | 7 | 0 | 39256.5 | 3.25 | 2.63 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | `backend-api` | no | verifier | no | 38449 | 3.6 | 716 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | `cli-report` | yes | pass | no | 29419.2 | 3.29 | 686 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | `failing-command-recovery` | yes | pass | no | 49603.2 | 3.31 | 373 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | `frontend-filter` | yes | pass | no | 33124.4 | 3.08 | 464 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | `multi-file-cart` | yes | pass | no | 37916.8 | 3.1 | 620 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | `sandbox-canary` | yes | pass | no | 55679 | 2.98 | 399 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k160-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-180B-GGUF Q2-REAP DS4 K160)` | `schema-validation` | no | verifier | no | 30604 | 3.37 | 816 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
