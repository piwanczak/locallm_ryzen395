# Real-Usage Result Rollup

Generated: 2026-06-26T08:30:43.945Z

Inputs:
- [results/20260626-ds4-k144-real-usage/ds4-k144-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | 1 | 7 | 0 | 33414 | 2.73 | 1.95 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | `backend-api` | no | verifier | no | 28449.6 | 2.73 | 78 |  |  |  | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | `cli-report` | no | verifier | no | 25984 | 4.04 | 619 |  |  |  | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | `failing-command-recovery` | yes | pass | no | 47086.2 | 4.06 | 311 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | `frontend-filter` | no | verifier | no |  | 0 | 0 |  |  |  | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | `multi-file-cart` | no | verifier | no |  | 0 | 0 |  |  |  | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | `sandbox-canary` | no | verifier | no | 44111.6 | 4.01 | 347 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ds4-direct-api:ds4-k144-rocm-ssd45-ctx8192 | `deepseek-chat (0xSero DeepSeek-V4-Flash-162B-GGUF Spark-Mini Q2-REAP DS4 K144)` | `schema-validation` | no | verifier | no | 21438.6 | 4.27 | 545 |  |  |  | [json](../../../public-results/results-summary.md) |
