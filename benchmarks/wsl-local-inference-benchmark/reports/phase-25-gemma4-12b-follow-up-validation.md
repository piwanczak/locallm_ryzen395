# Phase 25 - Gemma 4 12B Follow-Up Validation

Date: 2026-06-22

## Scope

This phase executes the Phase 24 follow-up items for `google/gemma-4-12b`:

- extend the Pi-through-LM-Studio proof from file-create to JS edit and protected browser-style;
- repeat a short controlled reliability sweep with `reasoning_effort=none`;
- recheck whether the WSL ROCm llama.cpp lane can load `gemma4`;
- assess the filled `131k` OpenCode follow-up as an interactive run vs guarded overnight run;
- keep durable reports and dashboard artifacts under the Windows workspace.

## Bottom Line

Gemma 4 12B is now stronger as a Windows LM Studio experimental high-context lane:

- Pi through LM Studio passed `js-edit` and protected `browser-style` with `reasoning_effort=none`.
- The recovered controlled reliability sweep passed `18/18` task cells across `3` iterations, `3` contexts, and `2` tasks.
- WSL ROCm remains blocked by the installed AMD llama.cpp build `8407 (312cf0332)`, which still exits on `unknown model architecture: 'gemma4'`.
- A filled `131k` OpenCode run was not started in this interactive pass. The prior filled `65k` Gemma 12B OpenCode run took about `702 s` per task and about `656 s` to first byte on the first filled request, so `131k` belongs in a guarded overnight run.

Keep Qwen3 Coder 30B Q4 as the default local coding stack. Use Gemma 4 12B only when the request path can force `reasoning_effort=none`, and treat it as a Windows LM Studio lane until WSL llama.cpp gains `gemma4` support.

## Pi Through LM Studio

Command shape:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-lmstudio-gemma12-workflow.ps1 `
  -Tasks js-edit,browser-style `
  -ReasoningEffort none `
  -TaskTimeoutSeconds 900
```

Evidence:

- summary: `results/20260622-185347-gemma12-pi-lmstudio-workflow/gemma12-pi-lmstudio-workflow-summary.json`
- proxy events: `results/20260622-185347-gemma12-pi-lmstudio-workflow/proxy-events.jsonl`

| Task | Pi runner | Verifier | Pi elapsed | Result |
| --- | --- | --- | ---: | --- |
| `js-edit` | exit `0`, not timed out | exit `0`, `JS_EDIT_OK` | `21940 ms` | pass |
| `browser-style` | exit `0`, not timed out | before exit `1`, after exit `0`, `BROWSER_STYLE_OK` | `68320 ms` | pass |

The timing proxy injected `reasoning_effort=none`; the proxy recorded `35` Gemma 12B events with that setting. LM Studio was restored after the run.

This supersedes the Phase 24 Pi caveat for small tasks: Gemma 4 12B through LM Studio is now proven for file-create, JS edit, and protected browser-style. It is not yet proven for the Pi challenge suite or soak runs.

## Controlled Reliability Sweep

The first reliability wrapper attempt launched a child ladder run that completed successfully, but the parent wrapper stayed alive and did not emit its own summary. The wrapper has been patched to redirect child output directly to files instead of reading async pipes. To avoid hiding the issue, the final sweep summary was recovered from three completed child ladder summaries.

Evidence:

- recovered sweep summary: `results/20260622-185709-gemma12-controlled-reliability-sweep/gemma12-controlled-reliability-sweep-summary.json`
- source run 1: `results/20260622-185709-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json`
- source run 2: `results/20260622-195835-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json`
- source run 3: `results/20260622-200029-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json`

Aggregate:

- run count: `3`
- contexts: `16384`, `65536`, `262144`
- tasks: `js-window`, `browser-style`
- task cells: `18`
- passed task cells: `18`
- failed task cells: `0`
- reasoning effort: `none`

| Context | Task | Runs | Passes | Avg first content | Avg wall time |
| ---: | --- | ---: | ---: | ---: | ---: |
| `16384` | `js-window` | `3` | `3` | `2353.7 ms` | `7503.1 ms` |
| `16384` | `browser-style` | `3` | `3` | `4632.9 ms` | `7960.4 ms` |
| `65536` | `js-window` | `3` | `3` | `2378.2 ms` | `7534.2 ms` |
| `65536` | `browser-style` | `3` | `3` | `4616.4 ms` | `7930.2 ms` |
| `262144` | `js-window` | `3` | `3` | `2376.0 ms` | `7567.8 ms` |
| `262144` | `browser-style` | `3` | `3` | `4672.2 ms` | `8526.2 ms` |

This proves repeatability for small controlled prompts at the advertised context setting. It still does not prove filled `262k` prompt reasoning.

## WSL ROCm Recheck

The installed WSL ROCm runtime is unchanged:

```text
version: 8407 (312cf0332)
built with GNU 13.3.0 for Linux
```

The runtime sees the WSL GPU aperture:

```text
AMD Radeon(TM) 8060S Graphics, gfx1151, VRAM: 67226 MiB
```

The recheck command wrote:

- summary: `results/20260622-200545-model-matrix/model-matrix-summary.json`
- log: `logs/20260622-200545-model-matrix/gemma-4-12b-q4/llama-server.log`

The failure is still a runtime support limit, not an agent-quality result:

```text
llama_model_load: error loading model: error loading model architecture: unknown model architecture: 'gemma4'
```

The loader reads the GGUF metadata and sees `general.architecture = gemma4`, then exits before serving. Next WSL work should replace or rebuild llama.cpp with `gemma4` architecture support before repeating agent tests.

## OpenCode 131k Assessment

The prior filled `65k` OpenCode run remains the largest real filled-prompt proof for Gemma 4 12B:

- summary: `results/20260622-171740-gemma12-65k-opencode-lmstudio/gemma12-65k-opencode-lmstudio-summary.json`
- `js-window`: `51367` prompt-token estimate, `701986.5 ms`, pass
- `browser-style`: `51286` prompt-token estimate, `703161.3 ms`, pass
- proxy first request: `656239 ms` first byte, `656589.2 ms` elapsed

The `131k` target would use about `102k` prompt tokens at the current `0.78` target scale. Based on the 65k run, that is not an interactive validation. Use this guarded overnight command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\opencode-agent-benchmark\scripts\run-opencode-benchmark.ps1 `
  -Profiles gemma12-131k `
  -Tasks js-window,browser-style `
  -TimeoutMinutes 90 `
  -PromptSourceMode thin `
  -PromptPaddingMode neutral `
  -ReasoningEffort none
```

Run only with outlet power, no other long benchmark running, and after confirming LM Studio can be restored on completion.

## Decision

Gemma 4 12B status after this phase:

| Lane | Status | Practical reading |
| --- | --- | --- |
| Windows LM Studio controlled | pass through `262k`, repeated `3x` for `16k`, `65k`, `262k` | strong small-prompt evidence when `reasoning_effort=none` |
| Windows LM Studio OpenCode | pass at filled `65k` | correct but slow; use as realism check, not daily loop |
| Pi through LM Studio | pass for file-create, JS edit, protected browser-style | viable for small Dockerized agent tasks, not yet soaked |
| WSL ROCm llama.cpp | fail to load `gemma4` | blocked until runtime update |
| Filled `131k` OpenCode | deferred | overnight-only |

Qwen3 Coder 30B Q4 remains the promoted default because it has broader WSL ROCm, Pi, Docker-controlled, memory-cap, challenge, and soak evidence.

## Follow-Up

- Replace or rebuild WSL llama.cpp with `gemma4` support, then rerun `gemma-4-12b-q4` through `run-wsl-model-matrix.ps1`.
- Run the guarded `gemma12-131k` OpenCode command overnight if a filled-context proof is still needed.
- If Gemma 12B remains interesting for Pi, run a short Pi challenge suite through LM Studio before considering any promotion.
- Re-run the patched reliability wrapper once to validate the wrapper itself, not just the child ladder evidence.
