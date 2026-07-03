# Real-Usage Result Rollup

Generated: 2026-06-25T21:26:57.833Z

Inputs:
- [results/20260625-230655-ollama-windows-qwen3-coder-next-ud-q4-k-m-backend-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260625-231125-ollama-windows-qwen3-coder-next-ud-q4-k-m-backend-probe-opencode-matrix/ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260625-232152-ollama-windows-qwen3-coder-next-ud-q4-k-m-tool-reminder-pi-matrix/ollama-pi-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-qwen3-coder-next-ud-q4-k-m-backend | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | 0 | 1 | 0 | 7886.8 | 8.8 | 6.99 |  |  |
| ollama-opencode:windows-qwen3-coder-next-ud-q4-k-m-backend-probe | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | 0 | 1 | 1 |  | 7.21 | 6.54 | 10 | 1 |
| ollama-pi:windows-qwen3-coder-next-ud-q4-k-m-tool-reminder | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | 1 | 1 | 0 | 111 |  |  | 9 |  |

## Interpretation

This follow-up uses the stronger Qwen3-Coder-Next Ollama quant
`hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M`, displayed by Ollama as `49 GB`.
When loaded for the benchmark, Ollama reported about `101 GB` runtime memory
with mixed placement, roughly `48%` CPU and `52%` GPU.

The stronger quant did not clear the backend promotion gate:

- Direct API `backend-api` failed after two attempts. Attempt 1 introduced a
  `body is not defined` runtime error. Attempt 2 fixed that but repeated the tax
  failure: actual `taxableCents=3948`, `taxCents=286`, `totalCents=6089`;
  expected `taxableCents=3553`, `taxCents=258`, `totalCents=6061`.
- OpenCode `backend-api` timed out at `600 s` and failed verification. It got
  `taxCents=258` and `totalCents=6061` right, but still returned
  `taxableCents=3948` instead of `3553`.
- Guarded Pi Docker `multi-file-cart` passed with the same Qwen/Ollama
  tool-call compatibility note used in the earlier UD-Q2_XL run. It took about
  `279.4 s` and used `9` tool-call starts.

All rows kept the canary unchanged and had no allowlist or protected-text
violations. Because both direct API backend and OpenCode backend did not
improve to passing, the dashboard recommendation should remain unchanged.

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-qwen3-coder-next-ud-q4-k-m-backend | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `backend-api` | no | verifier | no | 7886.8 | 8.8 | 269 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-qwen3-coder-next-ud-q4-k-m-backend-probe | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `backend-api` | no | timeout | yes |  | 7.21 | 3925 | 10 | 1 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-pi:windows-qwen3-coder-next-ud-q4-k-m-tool-reminder | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M` | `multi-file-cart` | yes | pass | no | 111 |  |  | 9 |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
