# Repository Organization

This repository is a working journal and experiment workspace for local inference.
Keep the root shallow and predictable. Do not add new top-level folders unless the
content cannot fit one of the categories below.

## Canonical Structure

```text
.
|-- AGENTS.md
|-- README.md
|-- entries/
|-- notes/
|-- reports/
|-- tools/
|-- benchmarks/
|-- logs/        # local-only run logs
|-- downloads/   # local-only models, installers, archives, runtimes
`-- build/       # local-only build trees; legacy local build dirs may exist
```

Use these locations consistently:

- `entries/`: durable journal entries. Use `YYYY-MM-DD-NNNN-short-title.md`
  and the front matter format documented in `README.md`.
- `notes/`: timestamped operational notes and handoff notes. Use
  `YYYY-MM-DD_HH-MM-SS_short-topic.md`.
- `reports/`: curated summaries and conclusions. Prefer Markdown as the source
  format; generated HTML/PDF renders should be treated as local artifacts unless
  the user explicitly asks to keep them.
- `tools/`: reusable host scripts and small helper source files. Commit scripts
  and source, not compiled binaries such as `.exe`.
- `benchmarks/`: self-contained benchmark or runner projects. One direct child
  directory per benchmark area is enough; avoid nesting benchmark projects under
  extra grouping folders.
- `logs/`: local-only raw command output, server stdout/stderr, smoke-test logs,
  and long-context samples.
- `downloads/`: local-only downloaded models, runtime zips, installers, SDKs,
  and extracted third-party binaries.
- `build/`: local-only compiler and CMake/Ninja build outputs. If an old local
  build directory such as `bvk/` exists, treat it as generated local state unless
  the user asks to reorganize it.

## Benchmark Subfolders

Inside a benchmark project, prefer this small vocabulary:

```text
benchmarks/<name>/
|-- README.md
|-- scripts/
|-- fixtures/
|-- prompts/
|-- results/   # local-only raw outputs unless explicitly promoted
`-- reports/   # durable summaries for that benchmark
```

Do not create parallel `logs`, `runs`, `output`, `out`, and `artifacts` folders
for the same purpose. Pick the matching folder above.

## Local Inference Dashboard Maintenance

The WSL/local-inference benchmark dashboard is a durable project summary, not
only a raw artifact index:

- Source/generator:
  `benchmarks/wsl-local-inference-benchmark/scripts/generate-local-inference-dashboard.mjs`
- Generated Markdown:
  `benchmarks/wsl-local-inference-benchmark/reports/local-inference-dashboard.md`
- Generated HTML:
  `benchmarks/wsl-local-inference-benchmark/reports/local-inference-dashboard.html`
- Generated data:
  `benchmarks/wsl-local-inference-benchmark/reports/local-inference-dashboard-data.json`

When a future run changes the promoted stack, major benchmark conclusions,
memory guidance, runner recommendation, endpoint recommendation, or known
limits, update the `projectSummary` section in the generator and regenerate the
dashboard. Keep the top of the dashboard as an abridged narrative with links to
canonical reports and result summaries; keep the raw result table secondary.

Recommended order after major benchmark/report work:

```powershell
node .\benchmarks\wsl-local-inference-benchmark\scripts\render-markdown-reports.mjs
node .\benchmarks\wsl-local-inference-benchmark\scripts\generate-local-inference-dashboard.mjs
```

For dashboard links, use paths relative to
`benchmarks/wsl-local-inference-benchmark/reports/`. Root-level reports should
normally be linked as `../../../reports/<name>.html`; benchmark-local result
summaries should normally be linked as `../results/<run>/<summary>.json`.

## Real-Usage Benchmark Maintenance

The real-usage benchmark is the canonical next-step eval for small practical
coding work beyond controlled single-edit tasks:

- Project:
  `benchmarks/real-usage-agent-benchmark/`
- Task manifest:
  `benchmarks/real-usage-agent-benchmark/tasks.json`
- Main runner:
  `benchmarks/real-usage-agent-benchmark/scripts/real-usage-suite.mjs`
- LM Studio direct API wrapper:
  `benchmarks/real-usage-agent-benchmark/scripts/run-lmstudio-real-usage-api.ps1`
- OpenCode wrapper:
  `benchmarks/real-usage-agent-benchmark/scripts/run-opencode-real-usage.ps1`
- Pi wrapper:
  `benchmarks/real-usage-agent-benchmark/scripts/run-pi-real-usage.ps1`
- Rationale report:
  `benchmarks/real-usage-agent-benchmark/reports/real-usage-benchmark-rationale.md`
- Result rollup helper:
  `benchmarks/real-usage-agent-benchmark/scripts/summarize-real-usage-results.mjs`

After changing task definitions, templates, reference solutions, runner
metrics, or benchmark conclusions, run:

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\real-usage-suite.mjs self-test
node .\benchmarks\real-usage-agent-benchmark\scripts\render-reports.mjs
```

For Pi Docker runs, keep timeout cleanup explicit. A timed-out host PowerShell
wrapper can leave a Docker Compose child container alive; the Pi runner should
track newly-created `pi-docker-agent-runner-pi*` containers and stop only those
on timeout. Always finish benchmark goals with a cleanup audit: no loaded LM
Studio model, no running Pi Docker container, no WSL `llama-server` or
`llama-bench`, and no unintended `.wslconfig`.

Use the Pi-specific agent prompt path for Pi runs. Do not feed Pi the direct API
JSON-edit prompt; generate an agent prompt with `real-usage-suite.mjs
agent-prompt` or through `run-pi-real-usage.ps1`.

For promoted Pi evidence, prefer guarded workspace mode: bind the whole task
workspace read-only and bind only editable files back as writable. This is the
default for tasks with no allowed generated files. If a task needs generated
outputs, add an explicit generated-output mount policy before treating that Pi
run as strong safety evidence.

After meaningful real-usage runs, create a rollup report with
`summarize-real-usage-results.mjs` and render Markdown reports to HTML:

```powershell
node .\benchmarks\real-usage-agent-benchmark\scripts\summarize-real-usage-results.mjs --inputs <matrix-jsons> --out-json .\benchmarks\real-usage-agent-benchmark\reports\<name>.json --out-md .\benchmarks\real-usage-agent-benchmark\reports\<name>.md
node .\benchmarks\real-usage-agent-benchmark\scripts\render-reports.mjs
```

If the suite changes promoted runner/model guidance, also update the WSL/local
inference dashboard generator and regenerate the dashboard with the standard
dashboard commands above.

## Local-Only Artifacts

Before creating or staging files, separate durable content from generated state.
Do not commit these unless the user explicitly requests it:

- `downloads/`
- `logs/`
- `build/`
- legacy generated build trees such as `bvk/`
- benchmark `results/` and `logs/`
- `.tmp/`, `.runtime/`, `.pi-home/`, `.xdg-*`, `node_modules/`, caches, and
  `__pycache__/`
- compiled binaries generated from local helper source files

If raw evidence from a local artifact matters, summarize it in `notes/` or
`reports/` and link the local path instead of moving the whole artifact into git.

## Root Hygiene

- Root files should normally be limited to repo guidance and configuration:
  `README.md`, `AGENTS.md`, `.gitignore`, and similar project-wide files.
- Do not leave ad hoc logs, benchmark outputs, downloaded archives, or one-off
  scripts at the root.
- If a task produces a temporary file, put it under `logs/`, `downloads/`,
  `build/`, or a benchmark-local ignored directory immediately.
- When a new durable category seems necessary, update this file and `.gitignore`
  in the same change.

## Git Hygiene

- Run `git status --short` before and after edits.
- Avoid staging unrelated user changes.
- Keep `.gitignore` ahead of generated output. Add ignore rules before running
  tools that produce large local artifacts.
- Prefer committing small, durable Markdown/source changes over raw logs or
  downloaded/generated payloads.
