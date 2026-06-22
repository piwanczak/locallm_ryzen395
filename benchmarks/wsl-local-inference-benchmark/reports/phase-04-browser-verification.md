# Phase 04 Browser Verification Report

Date: 2026-06-21

## Scope

This phase verifies that a local frontend fixture modified by the controlled edit-agent runner behaves correctly in a real browser session, not only in the Node DOM harness.

## Fixtures

| Item | Qwen3 Coder Q2 Run | Qwen3 Coder Q4 Run |
| --- | --- |
| Task | `browser-style` | `browser-style` |
| Runner | `controlled-edit-agent` | `controlled-edit-agent` |
| Result directory | `../results/20260621-222232-controlled-browser-style-protected` | `../results/20260621-224242-model-matrix/qwen3-coder-30b-q4-browser-style` |
| Fixture directory | `benchmarks/opencode-agent-benchmark/fixtures/work/controlled-20260621-222232/browser-style` | `benchmarks/opencode-agent-benchmark/fixtures/work/controlled-20260621-224242-qwen3-coder-30b-q4-browser-style/browser-style` |
| Static server | `http://127.0.0.1:8766/` during verification | `http://127.0.0.1:8767/` during verification |

## Agent Result

Both runs passed after the harness protected the invariant `empty.hidden = visible !== 0;`.

| Metric | Qwen3 Coder Q2 | Qwen3 Coder Q4 |
| --- | ---: | ---: |
| First content | `2125.2 ms` | `1909.8 ms` |
| Wall time | `3730.1 ms` | `3555.6 ms` |
| Completion tokens | `84` | `65` |
| Verifier | `browser-style tests passed` | `browser-style tests passed` |

## Browser Checks

Artifacts:

- `../results/20260621-222232-controlled-browser-style-protected/browser-verification.json`
- `../results/20260621-224242-model-matrix/qwen3-coder-30b-q4-browser-style/browser-verification.json`

| Check | Result |
| --- | --- |
| Filter input is unique | PASS |
| `CORE` matches owner case-insensitively | PASS |
| `gemma` matches visible text case-insensitively | PASS |
| `missing` hides all runs and shows empty state | PASS |

Screenshot artifact:

- `../results/20260621-222232-controlled-browser-style-protected/browser-verification-final.png`
- `../results/20260621-224242-model-matrix/qwen3-coder-30b-q4-browser-style/browser-verification-final.png`

## Decision

The current default local workflow can handle a simple frontend behavior fix when the benchmark harness states and enforces task invariants, applies only allowlisted edits, and verifies with both a Node DOM harness and a browser session. Qwen3 Coder Q4 is the better quality-default model after matching the Q2 browser pass while also producing a direct minimal replacement. This is still narrower than a general autonomous browser-use coding agent.
