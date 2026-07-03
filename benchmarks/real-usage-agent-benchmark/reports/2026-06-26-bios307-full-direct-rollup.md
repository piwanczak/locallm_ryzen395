# Real-Usage Result Rollup

Generated: 2026-06-26T22:09:06.019Z

Inputs:
- [results/20260626-195253-ollama-windows-bios307-full-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260626-214512-lmstudio-direct-matrix/lmstudio-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| direct-api | `deepseek-r1-0528-qwen3-8b` | 0 | 7 | 0 |  | 30.42 | 30.42 |  |  |
| direct-api | `google/gemma-4-12b` | 3 | 7 | 0 | 7471.7 | 18.7 | 14.13 |  |  |
| direct-api | `google/gemma-4-e4b` | 0 | 7 | 0 | 2048.3 | 38.4 | 37.22 |  |  |
| direct-api | `kimi-dev-72b` | 0 | 7 | 0 |  |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | 0 | 7 | 0 | 1889.2 | 65.26 | 55.5 |  |  |
| direct-api | `qwen/qwen3-coder-next` | 1 | 7 | 0 | 6293.9 | 18.4 | 15.34 |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | 0 | 7 | 0 | 593 | 123.81 | 94.78 |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | 0 | 7 | 0 | 597 | 89.08 | 72.42 |  |  |
| direct-api | `qwen3-0.6b` | 0 | 7 | 0 | 5154.2 | 707.25 | 161.57 |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | 0 | 7 | 0 | 1944.6 | 64.56 | 56.37 |  |  |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | 1 | 7 | 0 | 109203.3 | 11.76 | 4.87 |  |  |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | 0 | 7 | 0 |  | 24.77 | 24.77 |  |  |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | 0 | 7 | 0 | 11632.8 | 17.6 | 13.67 |  |  |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | 0 | 7 | 0 | 3164.9 | 30.93 | 23.64 |  |  |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | 0 | 7 | 0 |  |  |  |  |  |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | 5 | 7 | 0 | 14047.8 | 23.74 | 17.94 |  |  |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | 4 | 7 | 0 | 14940.9 | 12.54 | 10.52 |  |  |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | 1 | 7 | 0 | 25375.1 | 38.65 | 29.39 |  |  |

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `backend-api` | yes | pass | no | 82277.4 | 12.53 | 753 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `multi-file-cart` | yes | pass | no | 4306.2 | 12.48 | 734 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `schema-validation` | no | verifier | no | 3790.7 | 12.6 | 831 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `cli-report` | yes | pass | no | 3834.8 | 12.53 | 744 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `frontend-filter` | no | verifier | no | 4637.4 | 12.57 | 276 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `failing-command-recovery` | yes | pass | no | 2607.2 | 12.57 | 380 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `sandbox-canary` | no | verifier | no | 3132.9 | 12.5 | 309 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `backend-api` | no | verifier | no | 75680.3 | 23.75 | 643 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `multi-file-cart` | yes | pass | no | 4477.7 | 23.76 | 727 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `schema-validation` | no | verifier | no | 3750 | 23.69 | 912 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `cli-report` | yes | pass | no | 3865 | 23.65 | 684 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `frontend-filter` | yes | pass | no | 4809.9 | 23.78 | 276 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `failing-command-recovery` | yes | pass | no | 2636.5 | 23.73 | 359 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `sandbox-canary` | yes | pass | no | 3115.2 | 23.79 | 305 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | `backend-api` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | `multi-file-cart` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | `schema-validation` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | `cli-report` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | `frontend-filter` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | `failing-command-recovery` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `hf.co/unsloth/Kimi-Dev-72B-GGUF:UD-IQ2_XXS` | `sandbox-canary` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | `backend-api` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | `multi-file-cart` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | `schema-validation` | no | verifier | no | 146182.5 | 9.58 | 1387 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | `cli-report` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | `frontend-filter` | no | verifier | no |  |  |  |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | `failing-command-recovery` | no | verifier | no | 79546.1 | 11.02 | 714 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:32b` | `sandbox-canary` | yes | pass | no | 101881.3 | 14.68 | 748 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | `backend-api` | no | verifier | no |  | 15.36 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | `multi-file-cart` | no | verifier | no |  | 26.3 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | `schema-validation` | no | verifier | no |  | 26.24 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | `cli-report` | no | verifier | no |  | 26.34 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | `frontend-filter` | no | verifier | no |  | 26.12 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | `failing-command-recovery` | no | verifier | no |  | 26.62 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `deepseek-r1:8b` | `sandbox-canary` | no | verifier | no |  | 26.39 | 4096 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | `backend-api` | no | verifier | no | 62279.9 | 17.57 | 948 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | `multi-file-cart` | no | verifier | no | 3642.7 | 17.49 | 266 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | `schema-validation` | no | verifier | no | 3248.1 | 17.43 | 835 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | `cli-report` | no | verifier | no | 3375.4 | 17.48 | 572 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | `frontend-filter` | no | verifier | no | 3898.4 | 17.56 | 124 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | `failing-command-recovery` | no | verifier | no | 2387.8 | 17.87 | 248 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3:12b` | `sandbox-canary` | no | verifier | no | 2597 | 17.8 | 219 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | `backend-api` | no | verifier | no | 9153.4 | 30.8 | 201 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | `multi-file-cart` | no | verifier | no | 2442.2 | 31.08 | 221 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | `schema-validation` | no | verifier | no | 2304.6 | 30.98 | 632 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | `cli-report` | no | verifier | no | 2256.4 | 30.81 | 1900 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | `frontend-filter` | no | verifier | no | 2596.7 | 30.73 | 339 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | `failing-command-recovery` | no | verifier | no | 1591.6 | 31.13 | 185 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `gemma3n:e4b` | `sandbox-canary` | no | verifier | no | 1809.5 | 30.99 | 150 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | `backend-api` | no | verifier | no | 167767.9 | 37.91 | 1018 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | `multi-file-cart` | yes | pass | no | 1969.5 | 38.52 | 523 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | `schema-validation` | no | verifier | no | 1606.6 | 38.61 | 789 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | `cli-report` | no | verifier | no | 1540 | 38.62 | 604 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | `frontend-filter` | no | verifier | no | 2218.4 | 38.8 | 268 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | `failing-command-recovery` | no | verifier | no | 1195.1 | 39.13 | 306 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-bios307-full | `qwen3-coder:30b` | `sandbox-canary` | no | verifier | no | 1328.4 | 38.97 | 265 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| direct-api | `qwen/qwen3-coder-next` | `backend-api` | no | no-edit | no | 7961.9 | 18.05 | 1083 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-next` | `multi-file-cart` | no | no-edit | no | 6909.1 | 18.75 | 867 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-next` | `schema-validation` | no | no-edit | no | 5996.1 | 18.28 | 924 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-next` | `cli-report` | no | no-edit | no | 5693.7 | 18.25 | 1185 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-next` | `frontend-filter` | no | no-edit | no | 7657.4 | 18.86 | 272 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-next` | `failing-command-recovery` | no | no-edit | no | 4642.5 | 17.99 | 388 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-next` | `sandbox-canary` | yes | pass | no | 5196.3 | 18.6 | 383 |  |  |  |  |
| direct-api | `kimi-dev-72b` | `backend-api` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `kimi-dev-72b` | `multi-file-cart` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `kimi-dev-72b` | `schema-validation` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `kimi-dev-72b` | `cli-report` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `kimi-dev-72b` | `frontend-filter` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `kimi-dev-72b` | `failing-command-recovery` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `kimi-dev-72b` | `sandbox-canary` | no | no-edit | no |  |  |  |  |  |  |  |
| direct-api | `deepseek-r1-0528-qwen3-8b` | `backend-api` | no | no-edit | no |  | 30.54 | 4096 |  |  |  |  |
| direct-api | `deepseek-r1-0528-qwen3-8b` | `multi-file-cart` | no | no-edit | no |  | 30.3 | 4096 |  |  |  |  |
| direct-api | `deepseek-r1-0528-qwen3-8b` | `schema-validation` | no | no-edit | no |  | 29.37 | 4096 |  |  |  |  |
| direct-api | `deepseek-r1-0528-qwen3-8b` | `cli-report` | no | no-edit | no |  | 30.17 | 4096 |  |  |  |  |
| direct-api | `deepseek-r1-0528-qwen3-8b` | `frontend-filter` | no | no-edit | no |  | 30.11 | 4096 |  |  |  |  |
| direct-api | `deepseek-r1-0528-qwen3-8b` | `failing-command-recovery` | no | no-edit | no |  | 31.43 | 4096 |  |  |  |  |
| direct-api | `deepseek-r1-0528-qwen3-8b` | `sandbox-canary` | no | no-edit | no |  | 31.05 | 4096 |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `backend-api` | no | no-edit | no | 8903.4 | 18.16 | 678 |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `multi-file-cart` | yes | pass | no | 8532.1 | 17.92 | 861 |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `schema-validation` | no | no-edit | no | 7444.8 | 18.12 | 803 |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `cli-report` | yes | pass | no | 7660 | 18.46 | 661 |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `frontend-filter` | no | no-edit | no | 9211.5 | 19.62 | 160 |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `failing-command-recovery` | yes | pass | no | 4816.7 | 19.26 | 334 |  |  |  |  |
| direct-api | `google/gemma-4-12b` | `sandbox-canary` | no | no-edit | no | 5733.6 | 19.36 | 289 |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `backend-api` | no | no-edit | no | 2500 | 64.4 | 2204 |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `multi-file-cart` | no | no-edit | no | 2313.7 | 62.58 | 1320 |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `schema-validation` | no | no-edit | no | 1848.3 | 63.87 | 1233 |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `cli-report` | no | no-edit | no | 1856.2 | 63.49 | 1438 |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `frontend-filter` | no | no-edit | no | 2330.3 | 63.92 | 639 |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `failing-command-recovery` | no | no-edit | no | 1293.3 | 68.4 | 283 |  |  |  |  |
| direct-api | `unsloth/qwen3-coder-30b-a3b-instruct` | `sandbox-canary` | no | no-edit | no | 1470.6 | 65.28 | 684 |  |  |  |  |
| direct-api | `qwen3-0.6b` | `backend-api` | no | no-edit | no | 12663.2 | 890.36 | 2277 |  |  |  |  |
| direct-api | `qwen3-0.6b` | `multi-file-cart` | no | no-edit | no | 3188.5 | 554.06 | 720 |  |  |  |  |
| direct-api | `qwen3-0.6b` | `schema-validation` | no | no-edit | no | 6695.4 | 701.89 | 1420 |  |  |  |  |
| direct-api | `qwen3-0.6b` | `cli-report` | no | no-edit | no | 4030.9 | 483.61 | 999 |  |  |  |  |
| direct-api | `qwen3-0.6b` | `frontend-filter` | no | no-edit | no | 3745.8 | 1024.76 | 687 |  |  |  |  |
| direct-api | `qwen3-0.6b` | `failing-command-recovery` | no | no-edit | no | 2689.3 | 779.68 | 568 |  |  |  |  |
| direct-api | `qwen3-0.6b` | `sandbox-canary` | no | no-edit | no | 3066.5 | 516.39 | 794 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `backend-api` | no | no-edit | no | 824.2 | 118.01 | 724 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `multi-file-cart` | no | no-edit | no | 662.9 | 121.44 | 341 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `schema-validation` | no | no-edit | no | 545.6 | 128.62 | 110 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `cli-report` | no | no-edit | no | 572.2 | 119.1 | 881 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `frontend-filter` | no | no-edit | no | 659.7 | 124.44 | 208 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `failing-command-recovery` | no | no-edit | no | 433 | 122.94 | 284 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q4_k_m` | `sandbox-canary` | no | no-edit | no | 453.2 | 132.14 | 90 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `backend-api` | no | no-edit | no | 802.2 | 84.3 | 746 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `multi-file-cart` | no | no-edit | no | 617 | 87.83 | 345 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `schema-validation` | no | no-edit | no | 583.9 | 93.13 | 110 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `cli-report` | no | no-edit | no | 578.2 | 84.98 | 817 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `frontend-filter` | no | no-edit | no | 690.5 | 88.93 | 236 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `failing-command-recovery` | no | no-edit | no | 391 | 88.57 | 282 |  |  |  |  |
| direct-api | `qwen2.5-coder-1.5b-instruct@q8_0` | `sandbox-canary` | no | no-edit | no | 516.5 | 95.8 | 90 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `backend-api` | no | no-edit | no | 2376.2 | 62.81 | 1652 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `multi-file-cart` | no | no-edit | no | 2194.5 | 64.23 | 966 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `schema-validation` | no | no-edit | no | 1786.5 | 64.51 | 1162 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `cli-report` | no | no-edit | no | 1809.1 | 64.95 | 887 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `frontend-filter` | no | no-edit | no | 2295.3 | 64.58 | 649 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `failing-command-recovery` | no | no-edit | no | 1287.5 | 68.27 | 348 |  |  |  |  |
| direct-api | `qwen/qwen3-coder-30b` | `sandbox-canary` | no | no-edit | no | 1475.6 | 67.5 | 328 |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `backend-api` | no | no-edit | no | 2551.6 | 37.94 | 4096 |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `multi-file-cart` | no | no-edit | no | 2336.5 | 38.4 | 2524 |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `schema-validation` | no | no-edit | no | 2000.2 | 38.57 | 1984 |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `cli-report` | no | no-edit | no | 2067.7 | 38.29 | 2184 |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `frontend-filter` | no | no-edit | no | 2495.8 | 38.3 | 2677 |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `failing-command-recovery` | no | no-edit | no | 1287.5 | 38.69 | 2127 |  |  |  |  |
| direct-api | `google/gemma-4-e4b` | `sandbox-canary` | no | no-edit | no | 1598.6 | 38.62 | 2110 |  |  |  |  |
