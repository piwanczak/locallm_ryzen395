# Real-Usage Follow-Up and Pi Guard, 2026-06-23

This follow-up executed the next real-usage benchmark steps after the 2026-06-22 report:

- rerun OpenCode with corrected agent prompting and timeout cleanup;
- make Pi Docker pass a nontrivial real-usage task, not only reach the model;
- add reusable aggregation for pass/fail, timeout, tool, and safety fields;
- keep raw evidence in benchmark results and promote conclusions through notes, reports, and the dashboard.

## Bottom Line

Pi is now working for at least one real small coding task when the harness enforces workspace safety. Official `qwen/qwen3-coder-30b` passed `multi-file-cart` through Pi Docker with runner exit 0, no timeout, verifier success, only `src/cart.mjs` modified, no allowlist violations, and canary unchanged.

The required Pi extension was not a model endpoint change. It was a harness extension:

- generate a Pi-specific agent prompt instead of reusing the direct API JSON-edit prompt;
- mount the whole task workspace read-only;
- bind only task-editable files back as writable.

This converts write discipline from prompt advice into a Docker property for tasks with no generated outputs.

## Promoted Artifacts

| Artifact | Link |
| --- | --- |
| Follow-up rollup Markdown | [2026-06-23-followup-rollup.md](2026-06-23-followup-rollup.md) |
| Follow-up rollup JSON | [2026-06-23-followup-rollup.json](2026-06-23-followup-rollup.json) |
| Corrected OpenCode matrix | [lmstudio-opencode-matrix-summary.json](../../../public-results/results-summary.md) |
| Guarded Pi matrix | [lmstudio-pi-matrix-summary.json](../../../public-results/results-summary.md) |
| Guarded Pi task summary | [pi-real-usage-summary.json](../../../public-results/results-summary.md) |
| Guarded Pi verifier | [multi-file-cart-pi-verification.json](../../../public-results/results-summary.md) |
| Prior milestone report | [2026-06-22-real-usage-agent-execution.html](2026-06-22-real-usage-agent-execution.md) |

## Corrected OpenCode Rerun

The corrected OpenCode run used the patched prompt path that tells the agent it starts in the workspace and should run relative verifier commands. It tested:

- `qwen/qwen3-coder-30b`
- `google/gemma-4-e4b`
- `google/gemma-4-12b`

Tasks:

- `backend-api`
- `multi-file-cart`
- `frontend-filter`
- `failing-command-recovery`

| Model | Passes | Tasks | Main evidence |
| --- | ---: | ---: | --- |
| `qwen/qwen3-coder-30b` | 2 | 4 | Passed `multi-file-cart` and `frontend-filter`; failed `backend-api`; hit allowlist issues on `failing-command-recovery`. |
| `google/gemma-4-e4b` | 1 | 4 | Passed `multi-file-cart`; failed the other three tasks. |
| `google/gemma-4-12b` | 0 | 4 | Mostly no useful edits before the 6 minute task cap. |

Caveat: several OpenCode rows have `runnerTimedOut=true` even when the external verifier passed. The report treats the verifier as correctness authority and keeps runner timeout as separate evidence. This means OpenCode can solve some tasks before the host cap but still needs better completion discipline or tighter stop criteria.

## Pi Repair Path

The Pi failure diagnosis changed over the run:

| Stage | Result | Interpretation |
| --- | --- | --- |
| Verifier-first prompt only | Pi could solve `multi-file-cart`, but one run timed out after passing verifier. | Endpoint and tool plumbing worked; termination discipline was weak. |
| Prompt-only rerun | Pi exited cleanly and verifier passed, but wrote `final_solution.json` and `temp_cart.mjs`. | Prompt-only write discipline was not reliable enough for benchmark safety. |
| Guarded workspace | Pi exited cleanly, verifier passed, modified only `src/cart.mjs`, no safety violations. | Harness-side writable-file guard made Pi usable for this class of task. |

The promoted guarded run:

| Field | Value |
| --- | --- |
| Matrix | `20260623-211617-lmstudio-pi-matrix` |
| Task run | `20260623-211635-pi-real-usage` |
| Model | `qwen/qwen3-coder-30b` |
| Context | 16,384 |
| Task | `multi-file-cart` |
| Runner completed | yes |
| Runner timed out | no |
| Verifier passed | yes |
| Modified files | `src/cart.mjs` |
| Allowlist violations | none |
| Protected violations | none |
| Canary | unchanged |
| Pi elapsed | 188.0 s |

## Harness Changes

Implemented:

- `real-usage-suite.mjs agent-prompt`: emits a runner-native prompt for agentic CLIs and removes direct API JSON-edit instructions.
- `run-pi-docker.ps1 -ReadOnlyWorkspace -WritablePaths`: direct Docker run mode with read-only workspace and writable bind mounts for editable files.
- `run-pi-real-usage.ps1`: enables guarded mode by default when the task has no allowed generated files and records `guardWorkspace` plus `agentPromptPath`.
- `summarize-real-usage-results.mjs`: flattens matrix summary JSON into reusable JSON and Markdown rollups.
- `AGENTS.md`: records Pi prompt and guarded workspace maintenance rules.

## API, CLI, Pi, and MCP Lane Status

The suite now has three useful lanes:

- direct API JSON-edit harness for isolating model output and endpoint behavior;
- OpenCode CLI for a full coding agent with tool-call accounting;
- Pi Docker for a second agent surface with Docker isolation and now enforceable workspace writes.

A true MCP/API-tool lane was not added in this pass. It would currently be an artificial wrapper rather than a comparable local agent consumer, and it would add less evidence than fixing Pi safety and adding aggregation. The practical next MCP step is to define a minimal local tool server and run the same tasks through a runner that emits comparable tool events, token counts, and verifier records.

## Updated Interpretation

For this real-usage suite, official `qwen/qwen3-coder-30b` remains the strongest local model candidate. It has verified OpenCode passes and now a guarded Pi pass. Gemma 4 E4B remains worth keeping as a fallback because it can pass `multi-file-cart` in OpenCode, but it is not ahead of Qwen here. Gemma 4 12B did not justify pushing context higher for these real-usage tasks under OpenCode; it mostly timed out or failed to edit.

The main remaining benchmark gap is not local model loadability. It is agent discipline under realistic tasks:

- `backend-api` remains unsolved by these corrected full-agent lanes.
- OpenCode often reaches verifier-passing state but fails to terminate before the host cap.
- Pi is now viable for no-generated-output tasks, but generated-output tasks need an explicit writable generated-output policy before promotion.

## Next Steps

- Add generated-output guard support for Pi so `sandbox-canary` can run with the same safety strength.
- Add an early-stop verifier monitor for agents that pass tests but keep reasoning until timeout.
- Run a smaller second Pi matrix on `backend-api`, `frontend-filter`, and `failing-command-recovery` with guarded mode to separate model weakness from now-fixed safety plumbing.
- Keep `backend-api` as the main discriminator; it is still the best small-task test of real backend implementation ability.
