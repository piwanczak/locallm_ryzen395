# Real-Usage Result Rollup

Generated: 2026-06-27T08:38:30.205Z

Inputs:
- [results/20260627-072603-ollama-windows-ornith-9b-q4km-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260627-083841-ollama-windows-ornith-9b-q4km-native-chat-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260627-092710-ollama-ornith-tuned-r3-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260627-095010-ollama-ornith-q5-tuned-r3-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260627-101831-ollama-ornith-q4-card-sampling-r3-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | 1 | 7 | 0 |  | 19.42 | 16.48 |  |  |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | 1 | 7 | 0 |  | 16.67 | 15.32 |  |  |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | 2 | 7 | 0 |  | 19.21 | 16.57 |  |  |
| ollama-direct-api:windows-ornith-9b-q4km | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | 1 | 7 | 0 | 39116.6 | 42.93 | 17.18 |  |  |
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | 1 | 7 | 0 |  | 17.74 | 15.85 |  |  |

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
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `backend-api` | no | verifier | no |  | 17.82 | 1019 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `multi-file-cart` | no | verifier | no |  | 17.77 | 485 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `schema-validation` | no | verifier | no |  | 17.75 | 702 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `cli-report` | no | verifier | no |  | 17.75 | 970 |  |  |  | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `frontend-filter` | no | verifier | no |  | 17.78 | 195 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `failing-command-recovery` | no | verifier | no |  | 17.49 | 348 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-ornith-9b-q4km-native-chat | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `sandbox-canary` | yes | pass | no |  | 17.8 | 284 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `backend-api` | no | verifier | no |  | 19.09 | 4529 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `multi-file-cart` | no | verifier | no |  | 19.12 | 513 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `schema-validation` | no | verifier | no |  | 19.18 | 644 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `cli-report` | no | verifier | no |  | 18.97 | 702 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `frontend-filter` | yes | pass | no |  | 19.29 | 85 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `failing-command-recovery` | yes | pass | no |  | 19.54 | 72 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `sandbox-canary` | no | verifier | no |  | 19.26 | 224 |  |  | src/exportPlan.mjs, tmp/export.json | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | `backend-api` | no | verifier | no |  | 16.55 | 908 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | `multi-file-cart` | no | verifier | no |  | 16.56 | 431 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | `schema-validation` | no | verifier | no |  | 16.55 | 691 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | `cli-report` | no | verifier | no |  | 16.56 | 458 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | `frontend-filter` | no | verifier | no |  | 16.62 | 153 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | `failing-command-recovery` | no | verifier | no |  | 16.88 | 509 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q5-tuned-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q5_K_M` | `sandbox-canary` | yes | pass | no |  | 16.97 | 221 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `backend-api` | no | verifier | no |  | 19.52 | 102 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `multi-file-cart` | no | verifier | no |  | 19.35 | 800 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `schema-validation` | no | verifier | no |  | 19.41 | 484 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `cli-report` | no | verifier | no |  | 19.36 | 972 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `frontend-filter` | no | verifier | no |  | 19.44 | 350 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `failing-command-recovery` | no | verifier | no |  | 19.45 | 286 |  |  | package.json | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:ornith-q4-card-sampling-r3 | `hf.co/deepreinforce-ai/Ornith-1.0-9B-GGUF:Q4_K_M` | `sandbox-canary` | yes | pass | no |  | 19.43 | 303 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
