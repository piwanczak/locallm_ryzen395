# Qwen3-Coder-Next Agent Harness Evaluation

Date: 2026-06-25

## Scope

This milestone evaluates the existing Qwen3-Coder-Next Ollama mode against the
remaining available agent harnesses in the project:

- mode: `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q2_K_XL`;
- host endpoint: `http://127.0.0.1:11434/v1`;
- Docker endpoint: `http://host.docker.internal:11434/v1`;
- harnesses: OpenCode real-usage matrix and guarded Pi Docker real-usage matrix.

This is still the `26 GB` low-memory quant. It is not a Q4/Q8 quality rerun.

The earlier pass already covered direct API JSON edits, controlled edit-agent,
and Kebab. This pass does not rerun those lanes except as context.

## Harness Selection

Selected:

- OpenCode real-usage matrix via
  `benchmarks/real-usage-agent-benchmark/scripts/run-ollama-opencode-matrix.ps1`.
- Guarded Pi Docker real-usage matrix via
  `benchmarks/real-usage-agent-benchmark/scripts/run-ollama-pi-matrix.ps1`.

Not selected:

- WSL Docker-controlled Q4 workflow, because the available wrapper starts a WSL
  llama.cpp server from a GGUF file path and model alias. The current mode is an
  already-loaded Ollama endpoint, so using that workflow would require a new
  wrapper rather than just invoking an available harness.
- The older standalone `opencode-agent-benchmark` wrapper, because it is built
  around LM Studio profiles and the LM Studio timing proxy. The Ollama-targetable
  OpenCode harness in this repo is the real-usage OpenCode wrapper used above.

An interrupted first OpenCode attempt created partial prepare artifacts under
`results/20260625-221000-opencode-real-usage`; it did not produce stdout or a
matrix summary and is excluded from the rollup.

## Results

Evidence:

- [Agent harness rollup](../benchmarks/real-usage-agent-benchmark/reports/2026-06-25-qwen3-coder-next-ud-q2-xl-agent-harnesses.md)
- [OpenCode three-task matrix](../public-results/results-summary.md)
- [OpenCode backend probe](../public-results/results-summary.md)
- [Pi guarded probe](../public-results/results-summary.md)

| Harness | Tasks | Result | Timeouts | Tool calls | Reading |
| --- | ---: | --- | ---: | ---: | --- |
| OpenCode three-task matrix | 3 | `3/3` pass | 0 | 14 | Good on non-backend real-usage tasks, with one failed tool call inside a passing recovery task. |
| OpenCode backend probe | 1 | `0/1` pass | 1 | 4 | Timed out at `600 s` and still failed tax verification. |
| Pi Docker guarded probe | 1 | `1/1` pass | 0 | 5 | Passed `multi-file-cart` with guarded workspace mode and the existing Qwen/Ollama tool-call note. |

OpenCode successful tasks:

- `multi-file-cart`: pass, `180.8 s`, `1085` output tokens, `5` tool calls.
- `frontend-filter`: pass, `84.5 s`, `500` output tokens, `3` tool calls.
- `failing-command-recovery`: pass, `95.3 s`, `767` output tokens, `6` tool calls.

OpenCode backend failure:

- timed out at `600.4 s`;
- modified only `src/orders.mjs`;
- no allowlist violation, no protected text violation, canary unchanged;
- verifier expected `taxableCents=3553`, `taxCents=258`, `totalCents=6061`;
- verifier saw `taxableCents=3948`, `taxCents=286`, `totalCents=6089`.

Pi Docker result:

- task: `multi-file-cart`;
- elapsed: `64.9 s`;
- verifier passed;
- guarded workspace mode: enabled;
- tool-call starts: `5`;
- Pi event-derived TTFT: `59211 ms`.

## Decision

This improves the prior Qwen3-Coder-Next `UD-Q2_K_XL` picture: the mode works
in both OpenCode and guarded Pi for small practical tasks. It still should not
be promoted. The same backend tax task remains unsolved across direct API and
OpenCode, and the evaluation is on a low-memory quant rather than Q4 or better.

Use this result as viability evidence for low-memory agent lanes, not as a
replacement recommendation for the existing promoted local stack.

## Cleanup Audit

- Ollama model was stopped after the run; `ollama ps` showed no loaded model.
- Docker reported no running containers.
- WSL exact-name checks found no `llama-server` or `llama-bench` processes.
- No user `.wslconfig` existed.

## Next Steps

- Repeat the OpenCode and Pi agent lanes on Q4_K_M or better once the stronger
  quant is available locally.
- If backend quality is the target, rerun `backend-api` with a stronger quant
  before spending time on more Pi or visual-task evidence.
- Keep the dashboard recommendation unchanged unless a higher-quality
  Qwen3-Coder-Next run improves both direct API and OpenCode backend behavior.
