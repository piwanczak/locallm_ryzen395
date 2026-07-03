# Real-Usage Agent Execution, 2026-06-22

This run executed the real-usage coding benchmark across the local model set using three runner lanes:

- LM Studio direct OpenAI-compatible API
- OpenCode CLI against LM Studio
- Pi Docker against LM Studio

The suite is intentionally stricter than the earlier controlled edit probes. It scores disposable coding workspaces with task-local verifiers, allowlist checks, protected text checks, and an outside-fixture canary.

## Bottom Line

The current local stack is not yet reliable for this broader real-usage benchmark.

OpenCode produced the only verified agentic passes in this run: Gemma 4 E4B passed `frontend-filter` and `failing-command-recovery`, while official Qwen3 Coder 30B passed `multi-file-cart` and `frontend-filter`. Direct API produced one pass, Gemma 4 12B on `frontend-filter`. Pi Docker now runs through LM Studio and uses tools, but no Pi/model combination passed these tasks.

This is useful evidence because it separates three things that earlier checks could conflate:

- endpoint/model loadability
- tool and runner plumbing
- actual small coding task correctness

## Run Artifacts

| Lane | Summary |
| --- | --- |
| Direct API matrix | [lmstudio-direct-api-matrix-summary.json](../../../public-results/results-summary.md) |
| OpenCode matrix | [lmstudio-opencode-matrix-summary.json](../../../public-results/results-summary.md) |
| Pi Docker matrix | [lmstudio-pi-matrix-summary.json](../../../public-results/results-summary.md) |
| Benchmark rationale | [real-usage-benchmark-rationale.html](real-usage-benchmark-rationale.md) |

## Environment

| Item | Value |
| --- | --- |
| Host | Windows, LocalInference workspace |
| WSL memory note | WSL configured around 60 to 65 GiB RAM, 16 GiB swap |
| Host memory note | Windows host has about 124 GiB RAM visible |
| GPU note | AMD Radeon 8060S reported through WMI with about 4 GiB adapter RAM |
| LM Studio context | 16,384 tokens for matrix runs |
| Docker | Installed and WSL integration enabled |
| Cleanup result | No loaded LM Studio model, no running Docker container, no WSL `llama-server` or `llama-bench`, no `.wslconfig` |

## Direct API Results

Direct API used JSON edit output against the same verifier-backed workspaces. The full installed coding-model set was tested on `backend-api`, `schema-validation`, and `frontend-filter`.

| Model | backend-api | schema-validation | frontend-filter | Notes |
| --- | --- | --- | --- | --- |
| `google/gemma-4-12b` | fail | fail | pass | Required `reasoning_effort=none`; only direct pass |
| `google/gemma-4-e4b` | fail | fail | fail | No direct passes |
| `qwen/qwen3-coder-30b` | fail | fail | fail | No direct passes |
| `unsloth/qwen3-coder-30b-a3b-instruct` | fail | fail | fail | Very fast failures |
| `qwen2.5-coder-1.5b-instruct@q4_k_m` | fail | fail | fail | No direct passes |
| `qwen2.5-coder-1.5b-instruct@q8_0` | fail | fail | fail | No direct passes |
| `qwen3-0.6b` | fail | fail | fail | No direct passes |

The direct harness is useful for isolating model/code-output capability, but it is not representative of a full coding agent because it cannot inspect files incrementally or recover through tool use.

## OpenCode Results

OpenCode was run on four candidate models and four tasks: `backend-api`, `multi-file-cart`, `frontend-filter`, and `failing-command-recovery`.

| Model | backend-api | multi-file-cart | frontend-filter | failing-command-recovery |
| --- | --- | --- | --- | --- |
| `google/gemma-4-12b` | fail | fail | fail | fail |
| `google/gemma-4-e4b` | fail | fail | pass | pass |
| `qwen/qwen3-coder-30b` | fail | pass | pass | fail |
| `unsloth/qwen3-coder-30b-a3b-instruct` | fail | fail | fail | fail |

Tool-use evidence:

| Model | Passing task | Tool calls | Failed tool calls | Elapsed |
| --- | --- | ---: | ---: | ---: |
| `google/gemma-4-e4b` | `frontend-filter` | 6 | 0 | 141.7 s |
| `google/gemma-4-e4b` | `failing-command-recovery` | 6 | 1 | 148.9 s |
| `qwen/qwen3-coder-30b` | `multi-file-cart` | 9 | 1 | 83.1 s |
| `qwen/qwen3-coder-30b` | `frontend-filter` | 8 | 0 | 77.2 s |

Caveat: this OpenCode matrix completed before the wrapper was patched to wrap the task spec in an agent-lane prompt. The evidence is still valid as a first pass, because verified workspace edits occurred, but key candidates should be rerun with the patched prompt before treating OpenCode ordering as final.

## Pi Docker Results

Pi Docker was run on four candidate models and three tasks: `backend-api`, `frontend-filter`, and `failing-command-recovery`.

| Model | backend-api | frontend-filter | failing-command-recovery | Model-level behavior |
| --- | --- | --- | --- | --- |
| `google/gemma-4-12b` | fail, timeout | fail, timeout | fail, timeout | Timed out all tasks |
| `google/gemma-4-e4b` | fail | fail, timeout | fail | Acted, but failed verification |
| `qwen/qwen3-coder-30b` | fail | fail | fail | Completed quickly, failed exact behavior |
| `unsloth/qwen3-coder-30b-a3b-instruct` | fail | fail | fail | Completed almost immediately with no useful pass |

Pi is no longer failing only because Docker or endpoint configuration is absent. The runner reaches the model, uses tools, edits files, and preserves the outside canary. The failures are now practical correctness failures:

- Qwen official edited `src/orders.mjs` for `backend-api`, but money math remained wrong.
- Qwen official edited `app.js` for `frontend-filter`, but failed a case-insensitive owner query assertion.
- Qwen official modified `tools/test.mjs` in `failing-command-recovery`, which triggered an allowlist violation.
- Gemma 12B repeatedly hit the 240 second task cap.

During execution, the Pi wrapper needed fixes:

- replaced the invalid `run --message` path with Pi noninteractive prompt mode
- avoided PowerShell `-p` forwarding ambiguity by writing a prompt file and mounting it into the container
- added an agent-lane prompt wrapper so Pi ignores direct-API JSON-output instructions and edits files directly
- patched timeout cleanup so future timed-out Pi runs stop newly-created Pi containers instead of leaving Docker children alive

## Interpretation

The prior project conclusion remains valid for controlled tasks: Qwen3 Coder 30B Q4 is the strongest default local coding model and Gemma 4 12B is useful as an experimental high-context Windows LM Studio lane. This run adds a stricter caveat: controlled task success is not enough to promote a stack as broadly useful for small coding work.

For this real-usage suite, OpenCode plus official Qwen3 Coder 30B currently has the best evidence among the local full-agent paths because it produced verified multi-file and frontend passes. Gemma 4 E4B also deserves follow-up because it passed two OpenCode tasks despite being a fallback model in the larger context work.

Pi should be treated as plumbing-correct but benchmark-failing on this suite until rerun with the patched wrapper and perhaps a more explicit task discipline prompt. The current failures are valuable because they are now ordinary agent failures rather than basic endpoint failures.

## Next Steps

- Rerun OpenCode key candidates with the patched agent-lane prompt: official Qwen3 Coder 30B, Gemma 4 E4B, and Gemma 4 12B.
- Rerun Pi official Qwen3 Coder 30B with the patched timeout cleanup and a tighter verifier-first prompt.
- Add a true MCP or API-tool lane once a local runner can expose comparable tool-call accounting.
- Add per-run aggregation that automatically extracts pass counts, tool counts, failure classes, and links into the report.
- Keep `backend-api` in the suite; it is currently the best discriminator because every runner/model combination failed it.
