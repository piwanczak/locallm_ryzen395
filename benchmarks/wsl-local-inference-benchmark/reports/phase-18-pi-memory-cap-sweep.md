# Phase 18 Pi Memory-Cap Sweep

Date: 2026-06-22

## Scope

This phase tests whether Pi Docker/browser work requires the current WSL default memory behavior, or whether smaller WSL caps are sufficient for the validated Pi Jinja workflow.

This is a Pi-specific memory result. It is separate from the earlier controlled-runner `32GB` result.

## Command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-memory-cap-sweep.ps1 `
  -MemoryCaps DEFAULT,48GB,32GB `
  -Apply `
  -ConfirmWslShutdown `
  -ConfirmWslConfigWrite
```

The script:

- backs up `%USERPROFILE%\.wslconfig`,
- applies each cap,
- runs `wsl.exe --shutdown`,
- probes Linux-visible memory,
- runs the full Pi Jinja workflow,
- restores the original `.wslconfig` state,
- shuts WSL down once more so restoration applies.

## Corrected Result

Canonical result:

- `results/20260622-111737-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json`

Final state:

- `passed=true`
- `restoredOriginalConfig=true`
- `finalWslShutdown=true`
- `%USERPROFILE%\.wslconfig` absent after restore, matching the pre-run state
- no leftover Docker containers
- no leftover `llama-server`

## Cap Results

| Cap | Linux-visible RAM | MemTotal | Workflow result | Workflow summary |
| --- | ---: | ---: | --- | --- |
| `DEFAULT` | about `60GiB` | `63594160 kB` | pass | `results/20260622-111746-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json` |
| `48GB` | about `47GiB` | `49325756 kB` | pass | `results/20260622-112130-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json` |
| `32GB` | about `31GiB` | `32861904 kB` | pass | `results/20260622-112516-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json` |

Each workflow ran:

- raw non-stream endpoint tool-call probe,
- raw stream endpoint tool-call probe,
- Pi `file-create`,
- Pi `js-edit`,
- Pi `browser-style`,
- Pi session export from Docker volume to Windows result directories.

All three caps had:

- workflow exit code `0`,
- llama.cpp start exit `0`,
- llama.cpp stop exit `0`,
- `file-create=true`,
- `js-edit=true`,
- `browser-style=true`.

## Superseded Run

Run `results/20260622-111116-pi-memory-cap-sweep` is superseded.

Cause:

- Before the parser fix, `DEFAULT,48GB,32GB` was treated as one combined cap string.
- PowerShell also expanded unquoted `48GB` and `32GB` into byte-count literals in that combined string.

Fix:

- The script now splits comma-separated cap lists.
- It normalizes byte-count arguments such as `51539607552` back to `48GB`.
- It writes `passed=false` and `superseded=true` to the bad summary.

## Interpretation

For the current Pi Jinja proof workflow, `65GB` or default ~60GiB WSL memory is not required.

`32GB` is sufficient for:

- Qwen3 Coder 30B Q4,
- WSL ROCm llama.cpp with `--jinja`,
- `CTX_SIZE=8192`,
- Pi Docker file creation,
- Pi Docker JS edit,
- Pi Docker browser-style verification.

Use `48GB` if extra headroom is desired for Docker Desktop, browser containers, challenge-suite work, longer soaks, endpoint comparisons, package installs, or larger contexts.

## Remaining Limits

This does not yet prove `32GB` for:

- the five-task Pi challenge suite,
- 10-30 run reliability soak,
- runner comparison,
- alternative endpoints,
- long-context tasks,
- simultaneous agents.
