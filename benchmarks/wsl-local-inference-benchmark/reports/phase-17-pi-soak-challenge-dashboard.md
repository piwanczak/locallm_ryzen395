# Phase 17 Pi Soak, Challenge Suite, And Dashboard

Date: 2026-06-22

## Scope

This phase starts the reliability goal after the Phase 16 Pi recovery. It adds the next layer of automation and runs bounded validation. It does not claim the full goal is complete.

## New Automation

| Script | Purpose |
| --- | --- |
| `scripts/run-pi-reliability-soak.ps1` | Repeats the validated Pi workflow N times, records per-iteration pass/fail, task status, duration, summary links, and failure classification |
| `scripts/run-pi-challenge-suite.ps1` | Runs disposable small coding-agent tasks with per-task verifier output and exported Pi session logs |
| `scripts/generate-local-inference-dashboard.mjs` | Builds a local dashboard from result summaries and reports |

Dashboard outputs:

- `reports/local-inference-dashboard-data.json`
- `reports/local-inference-dashboard.md`
- `reports/local-inference-dashboard.html`

The dashboard currently indexes 55 result summaries and 36 report files.

## Soak Evidence

Corrected soak run:

- `results/20260622-110028-pi-reliability-soak/pi-reliability-soak-summary.json`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-reliability-soak.ps1 `
  -UseExistingServer `
  -Iterations 2 `
  -Tasks file-create,js-edit,browser-style
```

Result:

| Iteration | Duration | Result | Tasks |
| ---: | ---: | --- | --- |
| 1 | 47.852s | pass | `file-create`, `js-edit`, `browser-style` |
| 2 | 50.582s | pass | `file-create`, `js-edit`, `browser-style` |

The soak wrapper exports or links the underlying workflow summaries. The corrected run points to:

- `results/20260622-110029-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json`
- `results/20260622-110117-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json`

Each underlying workflow includes raw endpoint probes, verifier outputs, and exported Pi session logs.

## Wrapper Bug Found And Fixed

The first soak attempt started the server and executed a workflow, but the wrapper passed child workflow tasks incorrectly. Only `file-create` ran.

Fix:

- Pass `-Tasks` to the child workflow as a comma-joined string.
- Mark any iteration failed if the child workflow task count differs from the requested task count.
- Fix strict-mode handling for single-line workflow output.

This makes the soak summary stricter: a partial workflow can no longer be counted as a full pass.

## Challenge Suite Evidence

Challenge run:

- `results/20260622-110232-pi-challenge-suite/pi-challenge-suite-summary.json`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-challenge-suite.ps1 `
  -UseExistingServer `
  -Tasks single-function,multi-file,canary-preserve,browser-form,failing-command-recovery
```

Result:

| Task | Result | Evidence requirement |
| --- | --- | --- |
| `single-function` | pass | `node test.mjs`, `SINGLE_FUNCTION_OK` |
| `multi-file` | pass | verifier passed and session referenced both `src/settings.mjs` and `src/renderGreeting.mjs` |
| `canary-preserve` | pass | verifier passed and `canary.txt` remained unchanged |
| `browser-form` | pass | browser verifier output `BROWSER_FORM_OK` |
| `failing-command-recovery` | pass | verifier passed and session contained `EXPECTED_BAD_COMMAND_FAILURE` |

This is the first evidence that Pi handles more than the original proof fixtures.

## Current Interpretation

The setup is now stronger than a one-off proof:

- 2 of 2 full soak iterations passed against an already-running Jinja server.
- 5 of 5 small coding challenge tasks passed.
- Browser verification remains operational inside the Pi browser image.
- Session logs continue to migrate from Docker volumes into Windows result directories.

This is still not enough to declare Pi a daily-driver recommendation. The objective asks for a broader 10-30 run soak, memory-cap evidence, runner comparison, and endpoint comparison.

## Remaining Work

Not yet done:

- Pi memory-cap sweep at current/default, 48GB, and 32GB.
- Longer 10-30 run reliability soak.
- Comparison against Docker-controlled and host/WSL controlled runners.
- Alternative endpoint comparison.
- Final recommendation on whether Pi should be promoted as the daily driver.
