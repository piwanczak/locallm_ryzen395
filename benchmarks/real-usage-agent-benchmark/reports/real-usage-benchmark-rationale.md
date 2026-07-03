# Real Usage Agent Benchmark Rationale

Date: 2026-06-22

## Purpose

This benchmark suite closes a gap in the local-inference journal. Earlier work measured endpoint loadability, throughput, context windows, small controlled edits, OpenCode behavior, Pi tool calls, Docker-controlled execution, and Gemma/Qwen-specific constraints. Those results are necessary but not sufficient to answer whether a local stack is useful for actual small development tasks.

The new suite evaluates realistic usage patterns while keeping the work bounded enough to run repeatedly:

- backend API feature implementation;
- multi-file bugfixes;
- schema and edge-case validation;
- CLI tool enhancement;
- browser-visible frontend behavior;
- failing-command recovery;
- canary and workspace-boundary preservation.

## External Design Anchors

This suite is intentionally smaller and more local than public leaderboards, but it borrows their strongest evaluation patterns:

| Source | Relevant Pattern | Local Adaptation |
| --- | --- | --- |
| [SWE-bench](https://www.swebench.com/) | repository issue resolution with execution-backed scoring | small pinned workspaces with deterministic verifiers and modified-file allowlists |
| [Terminal-Bench](https://www.tbench.ai/) | agents completing realistic terminal tasks in disposable environments | CLI/Pi wrappers around the same task workspaces, with wall-time and command-recovery evidence |
| [Berkeley Function-Calling Leaderboard](https://gorilla.cs.berkeley.edu/leaderboard.html) | tool/function-call accuracy, latency, cost, and agentic subcategories | runner-neutral summaries that separate direct API, CLI, Docker/Pi, and future MCP/tool overhead |
| [tau-bench](https://github.com/sierra-research/tau-bench) | stateful tool-agent-user workflows scored by final state | future MCP/tool adapter should record structured tool calls and compare final workspace/test state |
| [Model Context Protocol docs](https://modelcontextprotocol.io/docs/getting-started/intro) | standardized protocol boundary between AI apps, files, tools, and workflows | MCP is treated as its own runner layer, not as a synonym for direct API prompting |
| [BigCodeBench](https://arxiv.org/abs/2406.15877) | practical coding tasks involving library/API use rather than only standalone algorithms | backend, CLI, schema, and frontend tasks require project-specific APIs and edge-case handling |

The main local difference is scale. Public benchmarks are better for leaderboard-grade model ranking; this suite is better for answering whether this specific Windows/WSL/local-runner stack can do useful small development work repeatably, cheaply, and without unsafe file behavior.

## Why This Is A Better Eval Shape

Small edit tasks answer whether a model can produce a correct patch once. Real local-agent use also depends on whether the runner can inspect the right files, choose a safe edit surface, run commands, recover from failures, avoid modifying unrelated files, and do all of that with tolerable token and latency overhead.

This suite separates three layers that were previously mixed together:

| Layer | What It Measures | Why It Matters |
| --- | --- | --- |
| Direct API harness | endpoint/model behavior with minimal runner overhead | establishes the clean baseline for latency, token use, and patch quality |
| CLI agent | autonomous tool use, file reads, shell commands, retries | represents actual agent workflows such as OpenCode |
| Pi/Docker agent | containerized agent behavior and Docker boundary costs | checks whether a portable agent setup remains practical |
| MCP/tool-mediated adapter | structured tool boundaries and tool overhead | planned path when a local MCP coding runner is available |

The direct API harness is not intended to replace agent benchmarks. It is a control group. If the direct harness passes and a CLI agent fails, the issue is likely runner/tool loop/configuration overhead. If both fail, the task is probably model/prompt/endpoint limited.

## Task Taxonomy

| Task | Class | Evaluation Signal |
| --- | --- | --- |
| `backend-api` | backend API feature | route design, validation, integer money math, preserving existing behavior |
| `multi-file-cart` | multi-file bugfix | reading multiple files before editing one, rule application, error handling |
| `schema-validation` | data validation | defaults, duplicate detection, edge cases, safe normalization |
| `cli-report` | CLI enhancement | args, stdout contracts, process exit behavior, no dependencies |
| `frontend-filter` | frontend/browser-visible | DOM behavior, state updates, protected UI invariant |
| `failing-command-recovery` | recovery | broken command plus code bug, realistic diagnostic loop |
| `sandbox-canary` | boundary | useful file generation while preserving outside-workspace canary |

## Metrics

Each runner should report as much of this common shape as it can:

| Metric | Direct API | OpenCode CLI | Pi Docker | MCP Adapter |
| --- | --- | --- | --- | --- |
| pass/fail and verifier output | yes | yes | yes | planned |
| wall time | yes | yes | yes | planned |
| first byte/content | yes | via proxy when used | endpoint/proxy dependent | planned |
| prompt/input/output tokens | endpoint usage | OpenCode step tokens | endpoint/proxy dependent | planned |
| reasoning tokens | endpoint dependent | endpoint/proxy dependent | endpoint/proxy dependent | planned |
| tool calls and failed tools | none by design | parsed from JSONL | raw runner output today | planned |
| modified files and allowlist | yes | yes | yes | planned |
| protected text and canary | yes | yes | yes | planned |

## Runner Commands

Local self-test:

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\real-usage-suite.mjs self-test
```

Direct API single task:

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\real-usage-suite.mjs run-api `
  --task backend-api `
  --base-url http://127.0.0.1:8080/v1 `
  --model qwen/qwen3-coder-30b-q4 `
  --max-attempts 2
```

LM Studio direct API wrapper with load/restore:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\real-usage-agent-benchmark\scripts\run-lmstudio-real-usage-api.ps1 `
  -Tasks frontend-filter `
  -Profile gemma12-16k `
  -Model google/gemma-4-12b `
  -ReasoningEffort none
```

OpenCode pilot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\real-usage-agent-benchmark\scripts\run-opencode-real-usage.ps1 `
  -Tasks backend-api,multi-file-cart `
  -BaseUrl http://127.0.0.1:5678/v1 `
  -Model qwen/qwen3-coder-30b-q4 `
  -TimeoutMinutes 12
```

Pi pilot:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\real-usage-agent-benchmark\scripts\run-pi-real-usage.ps1 `
  -Tasks backend-api,frontend-filter `
  -BaseUrl http://host.docker.internal:8080/v1 `
  -Model qwen/qwen3-coder-30b-q4 `
  -TaskTimeoutSeconds 900
```

## MCP Status

No local benchmark-specific MCP coding runner is currently exposed in this thread. The suite is MCP-ready in the important sense: each task has a neutral workspace, prompt, verifier, manifest, allowlist, and canary. A future MCP adapter should emit the same summary shape and add structured tool-call counts from MCP request logs.

Do not claim MCP benchmark evidence until an adapter actually runs the tasks and records tool events.

## Pilot Policy

Use a representative subset before any full sweep:

- direct API: `backend-api`, `schema-validation`, `frontend-filter`;
- OpenCode: `backend-api`, `multi-file-cart`;
- Pi Docker: `backend-api`, `frontend-filter`.

Run the full seven-task set only after the pilot confirms endpoint state, runner duration, and cleanup behavior.

## Current Status

As of this report, the suite source, wrappers, local self-test, and bounded LM Studio direct API pilots exist.

Validation evidence:

| Evidence | Result | Link |
| --- | --- | --- |
| seven-task self-test | pass; every fixture failed initially and passed with reference solution; canary stayed unchanged | `../results/20260622-212319-self-test/real-usage-self-test-summary.json` |
| OpenCode dry run | pass as command/workspace generation for `backend-api` and `multi-file-cart`; no model contacted | `../results/20260622-212335-opencode-real-usage/opencode-real-usage-summary.json` |
| Pi dry run | pass as command/workspace generation for `backend-api` and `frontend-filter`; no model contacted | `../results/20260622-212400-pi-real-usage/pi-real-usage-summary.json` |
| Gemma 4 12B direct API `backend-api` | fail after two attempts; useful negative evidence with verifier diagnostics, zero reasoning tokens, and clean canary/allowlist | `../results/20260622-212601-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |
| Gemma 4 12B direct API `frontend-filter` | pass in one attempt; first content about `4542.3 ms`, wall about `10513.2 ms`, `1526` prompt tokens, `137` completion tokens, zero reasoning tokens | `../results/20260622-212819-lmstudio-api-real-usage/lmstudio-real-usage-api-summary.json` |

The first model-backed pilot already shows why this benchmark is useful: the same model that passed small controlled prompts can pass a browser-facing task but fail a backend API task because it mishandled JavaScript `Map` introspection and did not repair that mistake on the second attempt. That is a better real-usage signal than a context-window pass alone.

Next pilots should compare the same task subset across direct API, OpenCode, and Pi against the promoted Qwen3 Coder 30B Q4 WSL endpoint. Do not claim API vs CLI vs MCP conclusions until those comparable runs exist.
