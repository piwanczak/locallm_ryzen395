# Real Usage Agent Benchmark

This benchmark suite evaluates local coding-agent stacks on small realistic work instead of only single-file edit fixtures.

It is runner-neutral: the same task templates can be run by:

- a direct OpenAI-compatible API harness;
- a CLI agent such as OpenCode;
- Pi inside Docker;
- a future MCP/tool-mediated adapter when a suitable local runner is available.

## Why This Exists

The previous benchmark set established useful facts about endpoint loadability, context windows, Pi tool calls, and small verifier-backed edits. This suite targets the next question: which local setup is actually useful for small real development tasks, and what overhead does each runner add?

It measures:

- correctness via task-local verifiers;
- latency and token usage where available;
- tool-call count and failed tool calls where the runner exposes events;
- modified files, diff size, allowlist compliance, protected text, and canary integrity;
- reproducibility through disposable fixture workspaces.

## Design Anchors

The task design is informed by public eval patterns without trying to become a public leaderboard:

- [SWE-bench](https://www.swebench.com/) for repository-edit tasks with execution-backed scoring.
- [Terminal-Bench](https://www.tbench.ai/) for realistic terminal workflows in disposable environments.
- [Berkeley Function-Calling Leaderboard](https://gorilla.cs.berkeley.edu/leaderboard.html) for tool/function-call accuracy, latency, and cost signals.
- [tau-bench](https://github.com/sierra-research/tau-bench) for stateful tool workflows scored by final state.
- [Model Context Protocol](https://modelcontextprotocol.io/docs/getting-started/intro) for treating MCP/tool mediation as a separate runner boundary.
- [BigCodeBench](https://arxiv.org/abs/2406.15877) for practical code tasks involving API/library usage.

## Task Classes

| Task | Class | What It Tests |
| --- | --- | --- |
| `backend-api` | backend API feature | route implementation, validation, money math, tests |
| `multi-file-cart` | multi-file bugfix | reading multiple modules before editing one |
| `schema-validation` | data validation | edge cases, defaults, duplicate detection |
| `cli-report` | CLI enhancement | args, stdout contracts, process behavior |
| `frontend-filter` | frontend/browser-visible | DOM-facing behavior in a verifier harness |
| `failing-command-recovery` | recovery | broken test command plus code bug |
| `sandbox-canary` | boundary | useful output while preserving canary and workspace boundary |

## Local Self-Test

This validates the benchmark itself without contacting a model endpoint. It confirms each fixture fails initially, applies a reference solution, and confirms the verifier passes.

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\real-usage-suite.mjs self-test
```

## Direct API Harness

Run a single task against any OpenAI-compatible endpoint:

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\real-usage-suite.mjs run-api `
  --task backend-api `
  --base-url http://127.0.0.1:8080/v1 `
  --model qwen/qwen3-coder-30b-q4 `
  --max-attempts 2
```

For LM Studio Gemma 4 12B, include:

```powershell
  --reasoning-effort none
```

To let the wrapper load and restore an LM Studio profile:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\real-usage-agent-benchmark\scripts\run-lmstudio-real-usage-api.ps1 `
  -Tasks frontend-filter `
  -Profile gemma12-16k `
  -Model google/gemma-4-12b `
  -ReasoningEffort none
```

## OpenCode CLI Runner

Use the wrapper to prepare the same disposable task workspace, run OpenCode, then verify and summarize:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\real-usage-agent-benchmark\scripts\run-opencode-real-usage.ps1 `
  -Tasks backend-api,multi-file-cart `
  -BaseUrl http://127.0.0.1:5678/v1 `
  -Model qwen/qwen3-coder-30b-q4 `
  -TimeoutMinutes 12
```

Use `-DryRun` first to inspect workspaces and commands without contacting a model.

## Pi Docker Runner

Run Pi against the same prepared workspaces:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\real-usage-agent-benchmark\scripts\run-pi-real-usage.ps1 `
  -Tasks backend-api,frontend-filter `
  -BaseUrl http://host.docker.internal:8080/v1 `
  -Model qwen/qwen3-coder-30b-q4 `
  -TaskTimeoutSeconds 900
```

Use `-DryRun` first. The wrapper sets the browser-capable Pi image for `frontend-filter`.

## Reports

The rationale and current status are in:

- `reports/real-usage-benchmark-rationale.md`
- `reports/real-usage-benchmark-rationale.html`
- `reports/2026-06-22-real-usage-agent-execution.md`
- `reports/2026-06-22-real-usage-agent-execution.html`

Current local validation:

- self-test: `results/20260622-212319-self-test/real-usage-self-test-summary.json`
- Gemma 12B direct API backend pilot: `results/20260622-212601-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json`
- Gemma 12B direct API frontend pilot: `results/20260622-212819-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json`
- direct API matrix: `results/20260622-214606-lmstudio-direct-matrix/lmstudio-direct-api-matrix-summary.json`
- OpenCode matrix: `results/20260622-220530-lmstudio-opencode-matrix/lmstudio-opencode-matrix-summary.json`
- Pi Docker matrix: `results/20260622-231019-lmstudio-pi-matrix/lmstudio-pi-matrix-summary.json`

Render reports with:

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\render-reports.mjs
```

## Local-Only Outputs

Raw result directories are intentionally ignored by git:

- `results/`
- `logs/`
- `fixtures/work/`
- `.opencode-empty/`
- `.xdg-*`
- `.tmp/`

Promote only curated summaries into `reports/` when a run changes project conclusions.
