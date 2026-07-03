# Real-Usage Result Rollup

Generated: 2026-06-23T19:21:45.674Z

Inputs:
- [results/20260623-075932-lmstudio-opencode-matrix/lmstudio-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260623-211617-lmstudio-pi-matrix/lmstudio-pi-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Allowlist | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- |
| opencode | `google/gemma-4-12b` | 0 | 4 | 4 | 0 | 4 |  |
| opencode | `google/gemma-4-e4b` | 1 | 4 | 3 | 0 | 13 | 1 |
| opencode | `qwen/qwen3-coder-30b` | 2 | 4 | 4 | 1 | 53 | 5 |
| pi | `qwen/qwen3-coder-30b` | 1 | 1 | 0 | 0 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| opencode | `qwen/qwen3-coder-30b` | `backend-api` | no | timeout | yes | 9 | 1 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `qwen/qwen3-coder-30b` | `multi-file-cart` | yes | pass | yes | 10 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `qwen/qwen3-coder-30b` | `frontend-filter` | yes | pass | yes | 17 | 0 | app.js | [json](../../../public-results/results-summary.md) |
| opencode | `qwen/qwen3-coder-30b` | `failing-command-recovery` | no | allowlist | yes | 17 | 4 | final_verification.md, package.json, solution.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `backend-api` | no | timeout | yes | 3 | 0 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `multi-file-cart` | yes | pass | no | 3 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `frontend-filter` | no | timeout | yes | 3 | 1 | app.js | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-e4b` | `failing-command-recovery` | no | timeout | yes | 4 | 0 | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `backend-api` | no | timeout | yes | 1 | 0 |  | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `multi-file-cart` | no | timeout | yes | 2 | 0 |  | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `frontend-filter` | no | timeout | yes | 0 | 0 |  | [json](../../../public-results/results-summary.md) |
| opencode | `google/gemma-4-12b` | `failing-command-recovery` | no | timeout | yes | 1 | 0 |  | [json](../../../public-results/results-summary.md) |
| pi | `qwen/qwen3-coder-30b` | `multi-file-cart` | yes | pass | no |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
