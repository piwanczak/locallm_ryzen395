# Phase 02 Agent Benchmark Report

Date: 2026-06-21

## Runners

| Runner | Purpose | Status |
| --- | --- | --- |
| OpenCode WSL-compatible runner | Tests a real coding-agent CLI against the WSL server | Measured failure mode under Qwen3 Coder 30B Q2 |
| Controlled edit-agent runner | Small safe harness for local edit tasks with allowlisted replacements and verifier execution | Passed `js-window`; passed protected `browser-style` with browser verification |
| Docker-controlled edit-agent runner | Runs the controlled edit-agent harness inside Docker against the WSL server | Passed `js-window`; passed protected `browser-style` with Linux verifier commands |
| Pi Docker runner | Container-compatible Pi/OpenAI-compatible setup | Base and browser images now build; Pi reaches the local endpoint but does not execute local llama.cpp tool-call text |

## OpenCode Findings

Artifacts:

- `../results/20260621-214423-opencode/js-window-grade.json`
- `../results/20260621-220659-opencode/runs.jsonl`

Findings:

- At `4096` context, OpenCode repeatedly exceeded the llama.cpp slot.
- At `8192` context, an earlier run edited `src/windowCounter.mjs` correctly and passed the verifier, but OpenCode did not terminate cleanly.
- The hardened runner now returns after timeout, writes stdout/stderr/proxy artifacts, grades the fixture, and cleans up helper processes.
- A short `8192` timeout run showed repeated `ContextOverflowError` and no useful tool calls.

## Controlled Edit-Agent Results

Artifacts:

- `../results/20260621-221417-controlled-js-window-lineendings/js-window-result.json`
- `../results/20260621-221442-controlled-browser-style/browser-style-result.json`
- `../results/20260621-221537-controlled-browser-style-hinted/browser-style-result.json`
- `../results/20260621-222232-controlled-browser-style-protected/browser-style-result.json`
- `../results/20260621-222232-controlled-browser-style-protected/browser-verification.json`

| Task | Result | First Content | Wall Time | Notes |
| --- | --- | ---: | ---: | --- |
| `js-window` | PASS | `1137.9 ms` | `5825 ms` | One allowlisted replacement, verifier passed |
| `browser-style` | FAIL | `2305.9 ms` first attempt | `7741.1 ms` first attempt | Model fixed case-insensitive matching but inverted `hidden` semantics |
| `browser-style` with DOM hint | FAIL | `2503.4 ms` first attempt | `8235.6 ms` first attempt | Model still changed empty-state behavior incorrectly |
| `browser-style` with protected invariant | PASS | `2125.2 ms` | `3730.1 ms` | Harness rejected risky behavior by preserving `empty.hidden = visible !== 0`; Node verifier passed |

## Decision

Use the controlled edit-agent runner as the current default local workflow for small code edits and simple frontend edits when task invariants are explicit and verifier-backed. Treat the unprotected `browser-style` runs as an explicit qualitative failure mode for Qwen3 Coder 30B Q2: the model repeatedly misunderstood DOM `hidden` semantics unless the harness protected the known-good invariant.
