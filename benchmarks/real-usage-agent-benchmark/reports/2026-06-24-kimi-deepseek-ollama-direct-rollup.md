# Real-Usage Result Rollup

Generated: 2026-06-24T19:35:22.292Z

Inputs:
- [results/20260624-190108-ollama-windows-deepseek-r1-8b-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260624-192348-ollama-wsl-deepseek-r1-8b-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-deepseek-r1-8b | `deepseek-r1:8b` | 0 | 3 | 1 |  | 22.92 | 22.92 |  |  |
| ollama-direct-api:wsl-deepseek-r1-8b | `deepseek-r1:8b` | 0 | 1 | 0 |  | 16.49 | 16.49 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-deepseek-r1-8b | `deepseek-r1:8b` | `backend-api` | no | verifier | no |  | 23.95 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-deepseek-r1-8b | `deepseek-r1:8b` | `schema-validation` | no | verifier | no |  | 22.8 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-deepseek-r1-8b | `deepseek-r1:8b` | `frontend-filter` | no | timeout | yes |  | 22.02 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:wsl-deepseek-r1-8b | `deepseek-r1:8b` | `backend-api` | no | verifier | no |  | 16.49 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
