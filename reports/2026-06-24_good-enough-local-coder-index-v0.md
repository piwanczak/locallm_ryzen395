# Good Enough Local Coder Index v0

Created: 2026-06-24 23:20 Europe/Warsaw

## Executive Conclusion

The Good Enough Local Coder Index, abbreviated `GELCI`, is a local 0-100 score
for coding-agent runs on this PC. It is deliberately not a tokens/sec score.
Tokens/sec remains useful diagnostics, but the index scores whether the machine
and runner produce verified useful work without wasting time, context, setup
effort, or recovery effort.

The score punishes the things that made recent local runs painful:

- first useful token,
- wall time to verifier pass,
- bad tool calls,
- retries,
- context overhead,
- power-state invalidation,
- setup fragility,
- rollback complexity.

The practical rule is simple: a daily local coder should pass the verifier,
produce its first useful action quickly, avoid tool loops, avoid context bloat,
and leave the machine easy to restore.

## Score Contract

Start from `100` and subtract penalties. Then apply the result cap for the run
outcome:

| Outcome | Maximum Score |
| --- | ---: |
| Verifier pass | 100 |
| Verifier fail after a useful intended edit | 55 |
| Timeout or no verifier reached after useful progress | 40 |
| First useful token only, no durable edit | 25 |
| No useful token or host/runtime invalidated the result | 20 |

Formula:

```text
GELCI = min(outcome_cap, max(0, 100 - sum(penalties)))
```

If a host power/runtime state change invalidates comparability, mark the run as
`invalidated` and do not promote it. It can still receive a low diagnostic
score, but it should not be mixed into normal pass/fail averages.

## Penalty Weights

| Category | Max | Measurement | Penalty Bands |
| --- | ---: | --- | --- |
| First useful token | 15 | Time until first model output or tool call that materially advances the task | `0` at `<=60s`; `5` at `61-120s`; `10` at `121-240s`; `15` above `240s` or none |
| Wall time to verifier pass | 25 | Run start to first verifier pass | `0` at `<=2m`; `5` at `2-5m`; `10` at `5-10m`; `17` at `10-20m`; `25` above `20m` or no pass |
| Bad tool calls | 15 | Wrong cwd, invalid shell syntax, repeated no-op reads, denied actions, wrong-file edits, unsafe cleanup attempts | `3` per soft bad call; `5` per hard bad call; cap at `15` |
| Retries | 10 | Full attempts after the first attempt | `5` per retry; cap at `10` |
| Context overhead | 10 | Actual input/history replay compared with useful task payload or context occupancy | `0` clean; `3` mild replay; `6` heavy replay or near context limit; `10` overflow, truncation, or context-caused failure |
| Power-state invalidation | 10 | Wake, clock cap, service drift, unloaded model, or runtime state change during evidence collection | `0` clean; `4` suspected but recovered; `7` comparability degraded; `10` invalidated |
| Setup fragility | 8 | Manual work required before the run can be reproduced | `0` one command; `2` already-loaded endpoint; `4` manual profile/reload; `6` multi-service WSL/Docker path; `8` install, driver, or runtime mutation |
| Rollback complexity | 7 | Work required to restore workspace, services, models, configs, containers, WSL, or host settings | `0` none; `2` one service/model unload; `4` config/cache/service cleanup; `6` container or WSL cleanup; `7` driver, power, registry, or manual reversal |

## Interpretation Bands

| Score | Meaning |
| ---: | --- |
| `85-100` | Daily-driver local coder candidate |
| `75-84` | Good enough for routine use with monitoring |
| `60-74` | Situational runner; use when its strengths match the task |
| `40-59` | Diagnostic or fallback only |
| `<40` | Not useful for practical local coding on this machine |

## Required Milestone Evidence

Each milestone report should include enough evidence to recompute the score:

| Field | Required Detail |
| --- | --- |
| Task and verifier | Task name, verifier command, pass/fail/timeout |
| Runner stack | Runner, model, endpoint, context, important runtime settings |
| Timings | First useful token and wall time to verifier pass |
| Tool behavior | Bad tool calls, denied calls, wrong-shell or wrong-cwd loops |
| Attempts | Initial attempt plus retries |
| Context | First input tokens, max input tokens, context limit, context replay notes |
| Host state | Power mode, wake/reboot status, loaded model/service state |
| Setup and rollback | Manual setup, cleanup audit, restored state |

Suggested JSON shape for future summaries:

```json
{
  "task": "backend-api",
  "runner": "opencode",
  "model": "qwen3-coder:30b",
  "endpoint": "wsl-ollama",
  "contextLimit": 32768,
  "firstUsefulTokenMs": 58000,
  "verifierPassMs": 110000,
  "verifierStatus": "pass",
  "badToolCalls": {
    "soft": 0,
    "hard": 0
  },
  "retryCount": 0,
  "contextOverhead": {
    "firstInputTokens": 24528,
    "maxInputTokens": 26800,
    "usefulPromptTokensEstimate": 20000
  },
  "powerStateIssue": "none",
  "setupFragility": "manual-profile-reload",
  "rollbackComplexity": "model-unload",
  "gelci": 83
}
```

## Why This Beats Tokens/Sec Here

Recent evidence already shows why speed alone is misleading:

- A model can stream quickly while spending the whole budget on reasoning and
  never producing actionable final content.
- A runner can produce a fast first token and still lose the task through tool
  loops, wrong shell syntax, or verifier failure.
- A large-context profile can look capable but become unusable when every tool
  step resends long history.
- A post-wake or clock-capped state can make a result look like a model problem
  when the host state invalidated the run.

`GELCI` keeps those failures visible in the score instead of hiding them behind
raw decode speed.

## Smaller-Step Note Rule

For each smaller step, create a timestamped Markdown note in `notes/` with:

- the immediate objective,
- the stack or file changed,
- the evidence collected,
- any score-relevant observations,
- cleanup/restored-state notes,
- the next concrete step.

For each milestone, create a Markdown report in `reports/` and render the same
report to HTML.

## v0 Status

This milestone defines the score. It does not yet backfill old runs or change
the promoted model/runner guidance.

Next implementation milestones:

- add a calculator for benchmark summaries,
- backfill recent Qwen, Gemma, DeepSeek, and Kimi evidence,
- add `GELCI` columns to real-usage rollups,
- update dashboard guidance only if the index changes the practical
  recommendation.

## Artifacts

| Artifact | Path |
| --- | --- |
| Planning note | `notes/2026-06-24_23-20-26_good-enough-local-coder-index-planning.md` |
| Milestone report | `reports/2026-06-24_good-enough-local-coder-index-v0.md` |
| HTML report | `reports/2026-06-24_good-enough-local-coder-index-v0.html` |
| Root report renderer | `tools/render-root-report.mjs` |
