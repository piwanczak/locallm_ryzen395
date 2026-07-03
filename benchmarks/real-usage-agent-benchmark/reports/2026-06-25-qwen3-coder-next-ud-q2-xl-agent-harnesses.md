# Real-Usage Result Rollup

Generated: 2026-06-25T20:33:11.946Z

Inputs:
- [results/20260625-221517-ollama-windows-qwen3-coder-next-ud-q2-xl-agent3-opencode-matrix/ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260625-222253-ollama-windows-qwen3-coder-next-ud-q2-xl-backend-probe-opencode-matrix/ollama-opencode-matrix-summary.json](../../../public-results/results-summary.md)
- [results/20260625-222133-ollama-windows-qwen3-coder-next-ud-q2-xl-tool-reminder-pi-matrix/ollama-pi-matrix-summary.json](../../../public-results/results-summary.md)

## Overview

| Runner | Model | Passes | Tasks | Timeouts | Avg TTFT ms | Avg TPS | Avg Wall TPS | Tools | Failed Tools |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-opencode:windows-qwen3-coder-next-ud-q2-xl-agent3 | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | 3 | 3 | 0 |  | 14.88 | 6.66 | 14 | 1 |
| ollama-opencode:windows-qwen3-coder-next-ud-q2-xl-backend-probe | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | 0 | 1 | 1 |  | 3.96 | 3.62 | 4 |  |
| ollama-pi:windows-qwen3-coder-next-ud-q2-xl-tool-reminder | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | 1 | 1 | 0 | 59211 |  |  | 5 |  |

## Interpretation

This rollup extends the earlier direct API, controlled edit-agent, and Kebab
results for Qwen3-Coder-Next `UD-Q2_K_XL` into the remaining practical
agent-harness lanes available for the current Ollama endpoint.

OpenCode passed the three non-backend tasks selected for the broader agent
matrix: `multi-file-cart`, `frontend-filter`, and `failing-command-recovery`.
Those runs used `14` tool calls total, had one failed tool call inside the
successful recovery task, and had no allowlist, protected text, or canary
violations. Average active output throughput across those rows was `14.88
tok/s`; wall throughput was lower at `6.66 tok/s` because OpenCode includes
agent/tool overhead and long first-step delays.

The separate OpenCode `backend-api` probe timed out at `600 s` and still failed
verification after modifying only `src/orders.mjs`. The canary remained
unchanged and there were no allowlist violations, but the tax calculation was
wrong in the same direction seen in the direct API run: expected
`taxableCents=3553`, `taxCents=258`, and `totalCents=6061`; actual output was
`taxableCents=3948`, `taxCents=286`, and `totalCents=6089`.

The guarded Pi Docker lane passed `multi-file-cart` with the existing
Qwen/Ollama tool-call compatibility note, `5` tool-call starts, no timeout, and
guarded workspace mode enabled. The Pi event-derived TTFT was `59211 ms`.

Practical reading: this low-memory quant is viable in the OpenCode and Pi
agent lanes for small non-backend tasks, but `backend-api` remains the hard
failure and the model should still not be promoted over the established local
stack on this evidence.

## Task Rows

| Runner | Model | Task | Pass | Class | Timeout | TTFT ms | TPS | Tokens Out | Tools | Failed | Modified | Verification |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ollama-opencode:windows-qwen3-coder-next-ud-q2-xl-agent3 | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `multi-file-cart` | yes | pass | no |  | 15.77 | 1085 | 5 | 0 | src/cart.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-qwen3-coder-next-ud-q2-xl-agent3 | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `frontend-filter` | yes | pass | no |  | 14.27 | 500 | 3 | 0 | app.js | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-qwen3-coder-next-ud-q2-xl-agent3 | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `failing-command-recovery` | yes | pass | no |  | 14.6 | 767 | 6 | 1 | package.json, src/parser.mjs | [json](../../../public-results/results-summary.md) |
| ollama-opencode:windows-qwen3-coder-next-ud-q2-xl-backend-probe | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `backend-api` | no | timeout | yes |  | 3.96 | 2171 | 4 | 0 | src/orders.mjs | [json](../../../public-results/results-summary.md) |
| ollama-pi:windows-qwen3-coder-next-ud-q2-xl-tool-reminder | `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL` | `multi-file-cart` | yes | pass | no | 59211 |  |  | 5 |  | src/cart.mjs | [json](../../../public-results/results-summary.md) |
