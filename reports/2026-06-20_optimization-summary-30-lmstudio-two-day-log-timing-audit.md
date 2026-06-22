# Optimization Summary 30 - LM Studio Two-Day Log Timing Audit

Created: 2026-06-20 19:58 Europe/Warsaw

## Executive conclusion

LM Studio did log enough timing data to compare prefill and decode rates over the last two days, but it did not log anything close to `3,000 tok/s` prefill in the searched server logs.

The strongest logged prefill found was `852.36 tok/s` on a roughly 3k-token prompt. The latest Qwen 65k OpenCode run logged `207.51 tok/s` prefill for the first large request and then decoded around `23.5-24.2 tok/s` on later turns. That matches the example shape for decode near `25 tok/s`, but not the example `3,000 tok/s` prefill.

## Scope

Searched LM Studio server logs for the two-day window covering `2026-06-19` and `2026-06-20`.

| Log | Size | Last write |
| --- | ---: | --- |
| `%USERPROFILE%\.lmstudio\server-logs\2026-06\2026-06-19.1.log` | `2,058,119` bytes | `2026-06-19 23:45` |
| `%USERPROFILE%\.lmstudio\server-logs\2026-06\2026-06-20.1.log` | `2,497,430` bytes | `2026-06-20 19:50` |

The parser counted complete llama.cpp timing records where a `prompt eval time` row could be paired with an `eval time` row. Progress-only `n_decoded` rows were ignored because they are intermediate status, not final request timings.

| Metric | Value |
| --- | ---: |
| `slot print_timing` rows inspected | `3,840` |
| Complete timing records extracted | `503` |
| Days covered | `2` |

## Two-day summary

Decode medians below use only completions with at least `80` decoded tokens, so tiny two-token replies do not distort the useful generation-speed picture.

| Date | Complete records | Prefill median | Prefill max | Decode median, >=80 tokens | Decode max, >=80 tokens |
| --- | ---: | ---: | ---: | ---: | ---: |
| `2026-06-19` | `257` | `78.23 tok/s` | `488.88 tok/s` | `31.82 tok/s` | `86.05 tok/s` |
| `2026-06-20` | `246` | `91.61 tok/s` | `852.36 tok/s` | `30.32 tok/s` | `89.91 tok/s` |

## Prompt-size buckets

| Prompt tokens | Records | Prefill median | Prefill max | Decode median, >=80 tokens | Decode max, >=80 tokens |
| ---: | ---: | ---: | ---: | ---: | ---: |
| `<100` | `449` | `79.18 tok/s` | `349.95 tok/s` | `30.92 tok/s` | `89.91 tok/s` |
| `100-999` | `38` | `235.95 tok/s` | `847.16 tok/s` | `31.72 tok/s` | `80.06 tok/s` |
| `1k-10k` | `6` | `584.36 tok/s` | `852.36 tok/s` | `70.56 tok/s` | `73.37 tok/s` |
| `10k-40k` | `4` | `332.92 tok/s` | `357.94 tok/s` | `33.61 tok/s` | `36.08 tok/s` |
| `40k-80k` | `4` | `168.40 tok/s` | `207.51 tok/s` | `23.66 tok/s` | `25.73 tok/s` |
| `80k+` | `2` | `40.38 tok/s` | `85.22 tok/s` | `9.71 tok/s` | `13.89 tok/s` |

## Highest logged prefill

Rows are restricted to prompts with at least `100` prompt tokens.

| Log line | Context | Parallel | Prompt tokens | Prefill | Decode tokens | Decode |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `2026-06-20.1.log:14252` | `8192` | `4` | `3,044` | `852.36 tok/s` | `80` | `70.56 tok/s` |
| `2026-06-20.1.log:7763` | `8192` | `4` | `357` | `847.16 tok/s` | `499` | `80.06 tok/s` |
| `2026-06-20.1.log:14763` | `8192` | `4` | `1,016` | `778.51 tok/s` | `120` | `73.37 tok/s` |
| `2026-06-20.1.log:16741` | `8192` | `4` | `7,508` | `647.99 tok/s` | `7` | `55.53 tok/s` |
| `2026-06-20.1.log:17647` | `8192` | `4` | `7,874` | `584.36 tok/s` | `7` | `55.02 tok/s` |
| `2026-06-20.1.log:7891` | `8192` | `4` | `503` | `571.72 tok/s` | `200` | `70.09 tok/s` |
| `2026-06-20.1.log:23269` | `8192` | `4` | `527` | `569.76 tok/s` | `394` | `35.73 tok/s` |
| `2026-06-19.1.log:1342` | `8192` | `1` | `296` | `488.88 tok/s` | `19` | `46.48 tok/s` |

No searched row reached `1,000 tok/s`, let alone `3,000 tok/s`.

## Highest meaningful decode

Rows are restricted to completions with at least `80` decoded tokens.

| Log line | Context | Parallel | Prompt tokens | Prefill | Decode tokens | Decode |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `2026-06-20.1.log:12524` | `8192` | `4` | `33` | `316.96 tok/s` | `160` | `89.91 tok/s` |
| `2026-06-20.1.log:13794` | `8192` | `4` | `60` | `260.59 tok/s` | `160` | `86.62 tok/s` |
| `2026-06-20.1.log:8357` | `8192` | `4` | `59` | `198.65 tok/s` | `160` | `86.49 tok/s` |
| `2026-06-19.1.log:28775` | `8192` | `1` | `28` | `241.47 tok/s` | `86` | `86.05 tok/s` |
| `2026-06-20.1.log:13421` | `8192` | `4` | `62` | `237.65 tok/s` | `160` | `86.01 tok/s` |
| `2026-06-20.1.log:13317` | `8192` | `4` | `31` | `349.95 tok/s` | `320` | `85.76 tok/s` |
| `2026-06-19.1.log:28713` | `8192` | `1` | `17` | `192.02 tok/s` | `180` | `85.73 tok/s` |
| `2026-06-20.1.log:7763` | `8192` | `4` | `357` | `847.16 tok/s` | `499` | `80.06 tok/s` |

The best short-context decode rates are around `80-90 tok/s`. This is consistent with the earlier fast-profile findings, but it does not hold at 65k+ context.

## Latest 65k Qwen/OpenCode sequence

These rows are from the latest `2026-06-20` Qwen 65k OpenCode benchmark window. They show the first large turn and then the smaller follow-up turns.

| Log line | Context | Prompt tokens | Prefill | Decode tokens | Decode |
| --- | ---: | ---: | ---: | ---: | ---: |
| `2026-06-20.1.log:46339` | `65536` | `58,742` | `207.51 tok/s` | `372` | `24.17 tok/s` |
| `2026-06-20.1.log:46755` | `65536` | `18` | `46.13 tok/s` | `114` | `24.24 tok/s` |
| `2026-06-20.1.log:47190` | `65536` | `131` | `99.92 tok/s` | `103` | `24.16 tok/s` |
| `2026-06-20.1.log:47644` | `65536` | `114` | `91.50 tok/s` | `129` | `23.96 tok/s` |
| `2026-06-20.1.log:48117` | `65536` | `114` | `93.96 tok/s` | `119` | `24.02 tok/s` |
| `2026-06-20.1.log:48609` | `65536` | `114` | `91.41 tok/s` | `136` | `23.71 tok/s` |
| `2026-06-20.1.log:49120` | `65536` | `432` | `100.98 tok/s` | `147` | `23.66 tok/s` |
| `2026-06-20.1.log:49651` | `65536` | `19` | `46.23 tok/s` | `218` | `23.50 tok/s` |

This is the clearest direct answer to the original comparison request:

| Metric | Logged value |
| --- | ---: |
| First large-turn prefill | `207.51 tok/s` |
| Follow-up decode band | `23.50-24.24 tok/s` |
| Example match? | Decode yes; prefill no |

## Long-context rows

| Log line | Context | Prompt tokens | Prefill | Decode tokens | Decode |
| --- | ---: | ---: | ---: | ---: | ---: |
| `2026-06-20.1.log:14366` | `32768` | `31,210` | `356.82 tok/s` | `240` | `36.08 tok/s` |
| `2026-06-20.1.log:14433` | `32768` | `31,164` | `332.92 tok/s` | `240` | `35.06 tok/s` |
| `2026-06-20.1.log:43953` | `65536` | `52,373` | `168.40 tok/s` | `668` | `25.73 tok/s` |
| `2026-06-20.1.log:46339` | `65536` | `58,742` | `207.51 tok/s` | `372` | `24.17 tok/s` |
| `2026-06-20.1.log:15049` | `65536` | `63,945` | `185.44 tok/s` | `240` | `23.37 tok/s` |
| `2026-06-20.1.log:14925` | `65536` | `63,988` | `167.12 tok/s` | `240` | `23.66 tok/s` |
| `2026-06-20.1.log:15311` | `131072` | `129,538` | `85.22 tok/s` | `240` | `13.89 tok/s` |
| `2026-06-20.1.log:15665` | `196608` | `195,050` | `40.38 tok/s` | `240` | `9.71 tok/s` |

The long-context shape is consistent across the saved benchmark JSONL and the raw LM Studio log: as prompt size grows from 32k to 196k, both prefill and decode collapse.

## Context-level summary

| Loaded context | Records | Prefill median | Prefill max | Decode median, >=80 tokens | Decode max, >=80 tokens |
| ---: | ---: | ---: | ---: | ---: | ---: |
| `2048` | `5` | `123.44 tok/s` | `124.65 tok/s` | `32.56 tok/s` | `32.56 tok/s` |
| `4096` | `10` | `96.67 tok/s` | `133.78 tok/s` | `34.24 tok/s` | `69.58 tok/s` |
| `8192` | `463` | `86.70 tok/s` | `852.36 tok/s` | `31.35 tok/s` | `89.91 tok/s` |
| `32768` | `2` | `332.92 tok/s` | `356.82 tok/s` | `35.06 tok/s` | `36.08 tok/s` |
| `65536` | `18` | `93.96 tok/s` | `357.94 tok/s` | `24.17 tok/s` | `34.24 tok/s` |
| `131072` | `1` | `85.22 tok/s` | `85.22 tok/s` | `13.89 tok/s` | `13.89 tok/s` |
| `196608` | `1` | `40.38 tok/s` | `40.38 tok/s` | `9.71 tok/s` | `9.71 tok/s` |

The `32768` row has only two complete long-prompt records, but those two line up with the prior long-context ladder. The `8192` context bucket contains many short or incremental requests, so its median is not a single workload benchmark.

## Interpretation

The raw LM Studio logs support three practical conclusions:

1. `3,000 tok/s` prefill is not present in the two-day server logs. The maximum observed prefill is `852.36 tok/s`.
2. Around 65k context, Qwen decode is consistently near `24-26 tok/s`, with the latest OpenCode/Qwen sequence clustered around `23.5-24.2 tok/s`.
3. The practical long-context recommendation remains unchanged: `32768` context is the highest useful long-context profile found so far, while 65k is experimental and 128k+ is too slow for interactive use on this stack.

## Artifacts

| Artifact | Path |
| --- | --- |
| Two-day source log 1 | `%USERPROFILE%\.lmstudio\server-logs\2026-06\2026-06-19.1.log` |
| Two-day source log 2 | `%USERPROFILE%\.lmstudio\server-logs\2026-06\2026-06-20.1.log` |
| Prior long-context result JSONL | `logs/long-context/long-context-results-20260620.jsonl` |
| Latest Qwen OpenCode proxy timings | `benchmarks/opencode-agent-benchmark/results/20260620-194002/proxy-events.jsonl` |
| Prior OpenCode benchmark report | `reports/2026-06-20_optimization-summary-29-opencode-agent-benchmark-final.md` |
| Prior long-context final report | `reports/2026-06-20_optimization-summary-28-long-context-final-report.md` |

## Notes

The context and parallel values are inferred from nearby LM Studio `LlamaV4::load config` and `new slot, n_ctx` log lines. Some rows may reflect prompt-cache reuse or incremental conversation turns; the report therefore separates first large-prompt rows from smaller follow-up rows.
