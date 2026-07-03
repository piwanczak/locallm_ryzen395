# Qwen3-Coder-Next Q4 Follow-Up

Date: 2026-06-25

## Scope

This milestone follows the next steps from
`reports/2026-06-25_qwen3-coder-next-ud-q2-xl-agent-harness-eval.md`:

- acquire or confirm a Q4_K_M-or-better Qwen3-Coder-Next quant;
- rerun the key direct API `backend-api` row;
- rerun the OpenCode backend agent probe;
- rerun the guarded Pi agent lane;
- update guidance only if both direct API and OpenCode backend behavior improve.

Mode under test:

- model: `hf.co/unsloth/Qwen3-Coder-Next-GGUF:UD-Q4_K_M`;
- Ollama id: `76f165a13e00`;
- displayed size: `49 GB`;
- host endpoint: `http://127.0.0.1:11434/v1`;
- Docker endpoint: `http://host.docker.internal:11434/v1`.

When loaded, Ollama reported about `101 GB` runtime memory with mixed
`48%` CPU / `52%` GPU placement.

## Evidence

- [Q4 rollup](../benchmarks/real-usage-agent-benchmark/reports/2026-06-25-qwen3-coder-next-ud-q4-k-m-followup.md)
- [Direct API backend matrix](../public-results/results-summary.md)
- [OpenCode backend matrix](../public-results/results-summary.md)
- [Guarded Pi matrix](../public-results/results-summary.md)

## Results

| Lane | Task | Result | Time | Key failure or reading |
| --- | --- | --- | ---: | --- |
| Direct API | `backend-api` | fail | `228.7 s` | Repeated tax/taxable-total failure after an initial `body` runtime error. |
| OpenCode | `backend-api` | timeout/fail | `600.4 s` | Corrected `taxCents` and `totalCents`, but left `taxableCents=3948` instead of `3553`. |
| Pi Docker guarded | `multi-file-cart` | pass | `279.4 s` | Passed with guarded workspace mode and Qwen/Ollama tool-call reminder. |

Backend verifier details:

- Direct API expected `taxableCents=3553`, `taxCents=258`, `totalCents=6061`.
- Direct API actual was `taxableCents=3948`, `taxCents=286`,
  `totalCents=6089`.
- OpenCode expected `taxableCents=3553`, `taxCents=258`, `totalCents=6061`.
- OpenCode actual was `taxableCents=3948`, `taxCents=258`,
  `totalCents=6061`.

Safety checks inside the benchmark rows:

- canary unchanged in all rows;
- no allowlist violations;
- no protected-text violations.

## Decision

Leave the dashboard recommendation unchanged. The Q4_K_M quant did not improve
both backend gates to passing. It is stronger evidence for low-memory Qwen3-
Coder-Next viability than the UD-Q2_XL pass, but not promotion evidence.

The practical reading is:

- Q4_K_M can run on this machine through Ollama, but only with partial CPU
  placement and slower effective generation.
- OpenCode backend behavior improved slightly on the tax result, but not enough
  to pass.
- Pi remains viable on `multi-file-cart`, but this does not offset the backend
  failure.

## Cleanup Audit

- Stopped the Ollama Q4 model after the run; the final `ollama ps` showed no
  loaded model.
- Docker reported no running containers.
- WSL exact-name checks found no `llama-server` or `llama-bench` processes.
- No user `.wslconfig` existed.

## Follow-Up

- Do not spend more time on Pi or visual tasks for this quant until backend
  behavior improves.
- If Qwen3-Coder-Next remains interesting, test a higher quant only if it can
  fit without heavy CPU offload or if a backend-specific prompt/harness change
  is intentionally being evaluated.
- Keep the existing promoted local stack in place.
