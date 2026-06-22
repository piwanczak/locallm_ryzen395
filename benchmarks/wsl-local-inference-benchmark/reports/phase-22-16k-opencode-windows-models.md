# Phase 22 16k OpenCode, Windows, And Model Comparison

Date: 2026-06-22

## Scope

This phase extends the `16k` question beyond the controlled WSL and Pi lanes:

- OpenCode thin-prompt workflow at `16k`.
- Qwen3 Coder Q2 as a speed fallback at `16k`.
- Qwen2.5 Coder 1.5B Q4/Q8 as smaller-model candidates at `16k`.
- Windows LM Studio Qwen3 Coder 30B at `16k`.

## OpenCode 16k

Canonical corrected result:

- `../results/20260622-140434-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json`
- underlying OpenCode JSONL: `../results/20260622-140721-opencode/runs.jsonl`
- proxy events: `../results/20260622-140721-opencode/proxy-events.jsonl`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-16k-opencode-wsl-workflow.ps1 `
  -ContextSize 16384 `
  -Port 8103 `
  -Tasks js-window,browser-style `
  -TimeoutMinutes 8 `
  -OutputLimit 2048
```

Result:

| Task | Result | Elapsed | First-step input tokens | Steps | Tool calls | Canary |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `js-window` | pass | `90777.3 ms` | `9841` | 6 | 5 | unchanged |
| `browser-style` | pass | `369086.8 ms` | `9853` | 20 | 18 | unchanged |

Interpretation:

- OpenCode at `16k` with thin/no-padding prompts can pass two verifier-backed tasks against WSL ROCm Qwen3 Coder Q4.
- It remains far slower and more tool-heavy than the controlled runners.
- Treat OpenCode as a realism benchmark rather than the default fast local harness.

Superseded OpenCode attempts:

- `../results/20260622-135455-16k-opencode-wsl-workflow` failed due task-list argument handling.
- `../results/20260622-135835-16k-opencode-wsl-workflow` produced a valid `js-window` pass, but the second task was mis-bound as `ProviderName`.
- Fixes:
  - `run-opencode-wsl-compatible-benchmark.ps1` now normalizes comma-separated task lists.
  - `run-16k-opencode-wsl-workflow.ps1` passes task lists as one comma-normalized argument.

## Qwen3 Coder Q2 16k

Canonical result:

- `../results/20260622-141608-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json`

Result:

| Model | Result | Calibration first content | Decode estimate | `js-window` first content | `browser-style` first content |
| --- | --- | ---: | ---: | ---: | ---: |
| Qwen3 Coder 30B Q4 | pass | `433.2 ms` | `39.65 tok/s` | `1126.0 ms` | `2394.9 ms` |
| Qwen3 Coder 30B Q2 | pass | `453.4 ms` | `44.64 tok/s` | `1331.6 ms` | `2109.8 ms` |

Interpretation:

- Q2 is viable for this narrow controlled `16k` lane.
- Q2 is not clearly better on first-content task latency.
- Keep Q4 as the quality default unless speed and memory pressure matter more than quality margin.

## Smaller Models At 16k

Canonical result:

- `../results/20260622-141906-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json`

Result:

| Model | Calibration first content | Decode estimate | `js-window` | `browser-style` |
| --- | ---: | ---: | --- | --- |
| Qwen2.5 Coder 1.5B Q4 | `123.3 ms` | `113.80 tok/s` | fail | fail |
| Qwen2.5 Coder 1.5B Q8 | `114.8 ms` | `85.80 tok/s` | fail | fail |

Interpretation:

- The 1.5B models are fast but not correct on the verifier-backed tasks.
- They should not be promoted for local coding-agent work despite strong latency.

## Windows LM Studio 16k

Canonical result:

- `../results/20260622-142238-windows-lmstudio-16k-controlled/windows-lmstudio-16k-controlled-summary.json`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-windows-lmstudio-16k-controlled.ps1 `
  -ContextSize 16384 `
  -Tasks js-window,browser-style
```

Result:

| Task | Result | First content | Wall time | Verifier |
| --- | --- | ---: | ---: | --- |
| calibration | pass | `310.0 ms` | n/a | n/a |
| `js-window` | pass | `820.5 ms` | `2997.6 ms` | exit `0` |
| `browser-style` | pass | `1343.8 ms` | `6383.5 ms` | exit `0` |

Cleanup:

- LM Studio server was already running before the run.
- No models were loaded before the run.
- The wrapper loaded Qwen3 Coder 30B at `16k`, ran the benchmark, then unloaded it.
- Post-run `lms ps`: no models loaded.

Interpretation:

- Windows LM Studio remains highly competitive for `16k` controlled tasks.
- It is faster than WSL ROCm on these two controlled first-content measurements.
- WSL ROCm remains necessary for the current Pi/Jinja executable tool-call lane.

## Phase 22 Conclusion

`16k` is realistic, but the right runner depends on the question:

| Purpose | Recommendation |
| --- | --- |
| Fast controlled Windows task | Windows LM Studio Qwen3 Coder 30B at `16k` |
| Linux/WSL controlled task | WSL ROCm Qwen3 Coder 30B Q4 at `16k` |
| Docker-isolated controlled task | Docker-controlled Q4 at `16k` |
| Dockerized agentic tool-call validation | Pi Q4 Jinja at `16k` |
| Realistic full agent behavior benchmark | OpenCode thin-prompt at `16k`, but expect much slower runs |
| Speed fallback | Qwen3 Coder 30B Q2, not smaller 1.5B models |

Do not promote Qwen2.5 Coder 1.5B Q4/Q8 despite their speed; they failed the verifier-backed tasks.

## Cleanup Audit

Post-run state:

- `%USERPROFILE%\.wslconfig`: absent.
- Running Docker containers: none.
- WSL `llama-server`: none.
- LM Studio loaded models: none.
