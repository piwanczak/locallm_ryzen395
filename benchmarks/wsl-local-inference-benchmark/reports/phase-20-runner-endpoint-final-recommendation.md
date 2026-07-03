# Phase 20 Runner Comparison, Endpoint Comparison, And Final Recommendation

Date: 2026-06-22

## Scope

This phase closes the selected follow-up goal:

- Pi reliability soak.
- Pi WSL memory-cap sweep.
- Small coding challenge suite.
- Local inference dashboard.
- Runner comparison.
- Endpoint comparison.

It builds on Phase 16, where Pi tool calling was recovered by serving Qwen3 Coder through llama.cpp with `--jinja` and keeping the Pi-side Qwen tool-call reminder.

## Canonical Prior Evidence

| Area | Canonical artifact | Result |
| --- | --- | --- |
| Pi Jinja recovery | `results/20260622-102758-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json` | pass |
| Challenge suite | `results/20260622-110232-pi-challenge-suite/pi-challenge-suite-summary.json` | 5 of 5 pass |
| Memory cap sweep | `results/20260622-111737-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json` | `DEFAULT`, `48GB`, `32GB` pass |
| 10-run soak | `results/20260622-113256-pi-reliability-soak/pi-reliability-soak-summary.json` | 10 of 10 pass |

The 10-run soak produced:

| Metric | Value |
| --- | ---: |
| Full workflow iterations | 10 |
| Passed iterations | 10 |
| Failed iterations | 0 |
| Task executions | 30 |
| Min iteration duration | `47.968s` |
| Average iteration duration | `55.845s` |
| Max iteration duration | `65.706s` |

The challenge suite passed:

- `single-function`
- `multi-file`
- `canary-preserve`
- `browser-form`
- `failing-command-recovery`

The memory cap sweep showed that the current short-context Pi Docker/browser workflow does not need the earlier approximately `65GB` WSL allocation. It passed at `32GB`, `48GB`, and default WSL memory.

## Runner Comparison

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-runner-comparison.ps1
```

Canonical result:

- `results/20260622-121739-runner-comparison/runner-comparison-summary.json`

Result:

| Runner | Result | Duration | Tasks | Evidence |
| --- | --- | ---: | --- | --- |
| `pi-docker` | pass | `242.480s` | `file-create`, `js-edit`, `browser-style` | Pi verifier files plus exported `pi-session.jsonl` logs |
| `docker-controlled` | pass | `186.255s` | `js-window`, `browser-style` | Docker verifier JSON and stdout/stderr |
| `host-controlled` | pass | `188.782s` | `js-window`, `browser-style` | Controlled runner verifier JSON |

Interpretation:

- Pi passed the broader file/edit/browser lane and exports session logs correctly.
- Docker-controlled and host-controlled runners remain simpler for repeatable measurements.
- Pi is slower in this comparison, and its fixtures are not byte-for-byte identical to the controlled runner fixtures.
- Pi should not replace the controlled runner as the default benchmark harness.
- Pi is useful as the Dockerized agentic lane when the question is specifically whether local model tool calls execute through Pi.

## Endpoint Comparison

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-endpoint-comparison.ps1 `
  -Variants q4-ctx8192,q4-ctx4096,q2-ctx8192 `
  -Tasks file-create,js-edit,browser-style
```

Canonical result:

- `results/20260622-120346-pi-endpoint-comparison/pi-endpoint-comparison-summary.json`

Result:

| Variant | Model | Context | Result | Duration | Tasks |
| --- | --- | ---: | --- | ---: | --- |
| `q4-ctx8192` | Qwen3 Coder 30B Q4 | 8192 | pass | `232.339s` | all 3 pass |
| `q4-ctx4096` | Qwen3 Coder 30B Q4 | 4096 | pass | `227.589s` | all 3 pass |
| `q2-ctx8192` | Qwen3 Coder 30B Q2 | 8192 | pass | `185.859s` | all 3 pass |

Each endpoint variant produced:

- raw non-stream endpoint tool-call probe exit code `0`,
- raw stream endpoint tool-call probe exit code `0`,
- Pi `file-create=true`,
- Pi `js-edit=true`,
- Pi `browser-style=true`,
- exported Pi session logs in the Windows result directory.

Promoted endpoint:

- `q4-ctx8192`

Reason:

- It is the baseline with the strongest prior evidence.
- It passed Phase 16 recovery, Phase 17 challenge/dashboard work, Phase 18 memory cap workflow, Phase 19 10-run soak, Phase 20 runner comparison, and the endpoint comparison.
- `q2-ctx8192` is faster in this small comparison but has less accumulated reliability evidence and lower expected coding quality.
- `q4-ctx4096` passed these short tasks, but `8192` remains the safer default for coding agents.

## Dashboard

Dashboard source and output:

- `reports/local-inference-dashboard-data.json`
- `reports/local-inference-dashboard.md`
- `reports/local-inference-dashboard.html`

The dashboard generator now recognizes:

- Pi challenge-suite summaries,
- runner-comparison summaries,
- endpoint-comparison summaries,
- endpoint comparison pass/fail derived from row-level results.

## Cleanup Audit

Post-run state:

- `%USERPROFILE%\.wslconfig`: absent, matching the pre-run state.
- Running Docker containers: none.
- WSL `llama-server`: none.

## Recommendation

Use this as the current local coding-agent stack:

| Purpose | Recommended path |
| --- | --- |
| Default endpoint | WSL ROCm llama.cpp, Qwen3 Coder 30B Q4, `CTX_SIZE=8192`, `LLAMA_JINJA=1` |
| Default benchmark harness | Host/WSL controlled runner |
| Docker-isolated controlled benchmark | Docker-controlled runner |
| Agentic Pi validation | Pi Docker runner with the local Qwen tool-call reminder |
| WSL memory cap for this measured short-context lane | `32GB` works; `48GB` is the pragmatic headroom setting |

Pi is viable for small local coding tasks on this machine under the promoted endpoint. It should be kept, but not treated as the only or best daily driver. The controlled runners are lower-friction for measurement and debugging; Pi is the higher-fidelity test for Dockerized agentic tool execution.

Remaining limits:

- Larger frontend applications were not tested.
- Long-context tasks were not tested under Pi.
- The 10-run soak was not repeated under a `32GB` memory cap.
- Endpoint comparison did not include LM Studio or Ollama because the current WSL ROCm llama.cpp path already passed the executable tool-call gate.
