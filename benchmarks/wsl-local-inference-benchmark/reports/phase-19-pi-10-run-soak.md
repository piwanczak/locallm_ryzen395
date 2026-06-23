# Phase 19 Pi 10-Run Reliability Soak

Date: 2026-06-22

## Scope

This phase expands the Pi reliability evidence from a 2-run smoke to a 10-iteration soak. Each iteration runs the full validated Pi Jinja workflow against one shared WSL ROCm llama.cpp server.

## Command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-reliability-soak.ps1 `
  -Iterations 10 `
  -Tasks file-create,js-edit,browser-style
```

## Result

Canonical artifact:

- `results/20260622-113256-pi-reliability-soak/pi-reliability-soak-summary.json`

Summary:

| Metric | Value |
| --- | ---: |
| Iterations requested | 10 |
| Iterations passed | 10 |
| Iterations failed | 0 |
| Min iteration duration | `47.968s` |
| Max iteration duration | `65.706s` |
| Average iteration duration | `55.845s` |

Every iteration ran all three tasks:

- `file-create`
- `js-edit`
- `browser-style`

The soak summary links each child workflow summary, and each child workflow includes:

- raw non-stream endpoint tool-call probe,
- raw stream endpoint tool-call probe,
- Pi task verifier artifacts,
- exported Pi session logs.

## Interpretation

This is the first meaningful reliability signal:

- 10 of 10 full workflow iterations passed.
- 30 of 30 task executions passed across file creation, JS edit, and browser-style verification.
- No task-count mismatch occurred.
- No failure class was recorded.

This supports Pi as viable for the tested small local coding tasks under the current endpoint:

- WSL ROCm llama.cpp,
- Qwen3 Coder 30B Q4,
- `--jinja`,
- Pi Docker runner,
- local Qwen tool-call format reminder.

## Cleanup

Post-run checks:

- `%USERPROFILE%\.wslconfig`: absent
- leftover `llama-server`: none
- leftover Docker containers: none

## Remaining Limits

This does not yet prove:

- Pi versus controlled-runner superiority,
- alternative endpoint behavior,
- long-context reliability,
- larger frontend app reliability,
- memory-capped 10-run soak.

It does, however, satisfy the first practical 10-run reliability target for the validated Pi workflow.
