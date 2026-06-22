# Phase 21 16k Controlled And Pi Context

Date: 2026-06-22

## Scope

This phase tests whether `16k` context is realistic for the current WSL ROCm Qwen3 Coder Q4 stack and the Pi Docker harness.

It covers:

- WSL ROCm controlled runner at `8192` vs `16384`.
- Pi Docker Jinja tool-call workflow at `16384`.
- Pi five-task challenge suite at `16384`.
- Docker-controlled runner at `16384`.

## Controlled WSL 8k vs 16k

Canonical result:

- `../results/20260622-133115-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-16k-controlled-context-comparison.ps1 `
  -Contexts 8192,16384 `
  -Models qwen3-coder-30b-q4 `
  -Tasks js-window,browser-style
```

Result:

| Context | Result | Calibration first content | Decode estimate | `js-window` first content | `browser-style` first content |
| ---: | --- | ---: | ---: | ---: | ---: |
| `8192` | pass | `426.2 ms` | `39.54 tok/s` | `1117.5 ms` | `2423.4 ms` |
| `16384` | pass | `433.2 ms` | `39.65 tok/s` | `1126.0 ms` | `2394.9 ms` |

Interpretation:

- `16k` is viable for the controlled WSL ROCm Qwen3 Coder Q4 edit/browser lane.
- For these short controlled tasks, `16k` did not materially slow first-content timing versus `8k`.
- This is the strongest evidence so far that `16k` is a realistic local agent context target on the WSL ROCm stack.

## Pi 16k Tool-Call Workflow

Canonical result:

- `../results/20260622-133820-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-jinja-q4-toolcall-workflow.ps1 `
  -ContextSize 16384 `
  -Tasks file-create,js-edit,browser-style
```

Result:

| Task | Result | Evidence |
| --- | --- | --- |
| raw non-stream probe | pass | exit `0` |
| raw stream probe | pass | exit `0` |
| `file-create` | pass | Pi exit `0`, result file exact |
| `js-edit` | pass | Pi exit `0`, verifier exit `0` |
| `browser-style` | pass | Pi exit `0`, before verifier failed as expected, after verifier exit `0` |

Session log audit:

| Task | `toolCall` count | `toolResult` count |
| --- | ---: | ---: |
| `file-create` | 2 | 1 |
| `js-edit` | 10 | 5 |
| `browser-style` | 12 | 6 |

Interpretation:

- Pi at `16k` is not only reachable; it executes real tools and exports session logs into the Windows result directory.
- The same Jinja endpoint contract from Phase 16 still works at `16k`.

## Pi 16k Challenge Suite

Canonical result:

- `../results/20260622-134255-pi-challenge-suite/pi-challenge-suite-summary.json`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-challenge-suite.ps1 `
  -ContextSize 16384 `
  -Tasks single-function,multi-file,canary-preserve,browser-form,failing-command-recovery
```

Result:

| Task | Result | Extra evidence |
| --- | --- | --- |
| `single-function` | pass | verifier exit `0` |
| `multi-file` | pass | verifier exit `0`, multi-file reads observed |
| `canary-preserve` | pass | verifier exit `0`, canary preserved |
| `browser-form` | pass | browser verifier exit `0` |
| `failing-command-recovery` | pass | verifier exit `0`, expected failing command observed |

Interpretation:

- Pi passed the broader small-task suite at `16k`.
- This is stronger than the minimum Pi 16k gate because it covers multi-file reading, scoped edits, browser verification, and recovery from a known bad command.

## Docker-Controlled 16k

Canonical result:

- `../results/20260622-134859-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-docker-controlled-q4-workflow.ps1 `
  -ContextSize 16384 `
  -Port 8102 `
  -Tasks js-window,browser-style
```

Result:

| Task | Result | First content | Wall time | Verifier |
| --- | --- | ---: | ---: | --- |
| `js-window` | pass | `1172.1 ms` | `6849.5 ms` | exit `0` |
| `browser-style` | pass | `1777.4 ms` | `3784.0 ms` | exit `0` |

Interpretation:

- Docker-controlled remains a clean, fast Linux-container benchmark lane at `16k`.
- Use it when the runner should execute inside Docker but Pi-specific behavior is not under test.

## Phase 21 Conclusion

`16k` is realistic for the controlled WSL ROCm Qwen3 Coder Q4 lane and for Pi's Dockerized tool-call workflow on the current short/small task suite.

Promotion guidance:

- Use `16k` as the practical target for local coding-agent comparisons.
- Keep Qwen3 Coder 30B Q4 as the quality default.
- Keep Docker-controlled as the fastest containerized measurement lane.
- Keep Pi for executable Dockerized agentic tool-call validation.

Remaining limits:

- Larger frontend applications were not tested.
- Long-running reliability soak at `16k` was not run.
- Memory cap at `16k` was not swept.
