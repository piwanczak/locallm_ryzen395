# Real-Usage Result Rollup

Generated: 2026-06-25T19:27:06.832Z

Inputs:
- [results/20260625-211501-ollama-windows-qwen3-coder-next-ud-q2-xl-direct-matrix/ollama-direct-api-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | 5 | 7 | 0 | 4823.9 | 18.59 | 16 |  |  |

## Interpretation

This run used the exact Qwen3-Coder-Next GGUF through Ollama on the Windows
OpenAI-compatible endpoint. The selected artifact was
`hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL`, a `26 GB` 2-bit XL quant
chosen because the Q4_K_M LM Studio download is about `48.5 GB` and was not
locally available in time for an interactive benchmark pass.

Result: `5/7` tasks passed with no timeouts and no canary breach. The model was
fast enough for interactive small tasks after load, with average TTFT `4823.9
ms`, average output throughput `18.59 tok/s`, and average wall throughput `16
tok/s`.

The two failures were semantic, not infrastructure failures:

- `backend-api` failed the order tax verifier after two attempts. The generated
  implementation computed `taxCents` as `286` instead of expected `258`, omitted
  `taxableCents`, and returned total `6089` instead of `6061`.
- `schema-validation` failed after two attempts because invalid input did not
  raise the expected configuration validation exception.

Practical reading: this quant is viable for small direct API coding tasks, but
it should not replace the already promoted local coding stack on this evidence.
The run is weaker than a Q4/Q8 quality run and weaker than a full agent-lane
evaluation with guarded filesystem execution.

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `backend-api` | no | verifier | no | 6679.1 | 18.82 | 734 |  |  | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `multi-file-cart` | yes | pass | no | 4826.3 | 18.81 | 779 |  |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `schema-validation` | no | verifier | no | 6729 | 16.97 | 2013 |  |  | src/validateConfig.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `cli-report` | yes | pass | no | 4466.6 | 18.91 | 676 |  |  | bin/usage-report.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `frontend-filter` | yes | pass | no | 4983.9 | 18.8 | 278 |  |  | app.js | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `failing-command-recovery` | yes | pass | no | 2820.7 | 18.99 | 361 |  |  | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-direct-api:windows-qwen3-coder-next-ud-q2-xl | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `sandbox-canary` | yes | pass | no | 3262 | 18.81 | 302 |  |  | src/exportPlan.mjs | [json](../../../public-results/results-summary.md) |
