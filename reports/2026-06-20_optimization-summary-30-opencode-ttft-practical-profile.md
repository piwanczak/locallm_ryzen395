# Optimization Summary 30 - OpenCode TTFT Practical Profile

Created: 2026-06-20 20:55 Europe/Warsaw

## Executive conclusion

No tested OpenCode + LM Studio profile fully satisfies all gates: fast first TTFT, `>=30 tok/s` decode, correctness, sandbox safety, and repeatability across the fuller task suite.

Best practical recommendation:

| Priority | Recommendation |
| --- | --- |
| Fast small/simple OpenCode tasks | `qwen/qwen3-coder-30b`, loaded at `32768`, prompt target scale `0.60` |
| Cleaner tool behavior / runner-up | `google/gemma-4-e4b`, loaded at `32768`, prompt target scale `0.78` |
| Avoid as practical defaults | `48k`, `65k`, and `128k+` OpenCode agent profiles |

Qwen 32k short is the speed winner: `58.9 s` first TTFT and `30.2 tok/s` first-step decode on `js-window`. It passed the calibration task, but repeated bad PowerShell command attempts and then failed the first fuller-suite task (`python-ledger`).

Gemma 32k is the behavior runner-up: cleaner tool use and `3/5` fuller-suite tasks passed, but first TTFT was usually `~121-167 s`, slightly above the preferred two-minute target, and it failed `python-ledger` and `java-slug`.

## What changed after report 29

- Added benchmark-only 32k, 48k, and 65k profile names for Qwen and Gemma.
- Kept daily/known-good LM Studio profiles separate.
- Kept baseline LM Studio settings: `parallel=1`, `eval_batch_size=2048`, `physical_batch_size=512`, flash attention, KV offload, and Qwen `num_experts=4`.
- Added prompt target scaling instead of always building near-65k prompts.
- Reduced attachment chunks to `32,000` chars to avoid single-attachment truncation.
- Added a Windows PowerShell prompt rule after repeated `&&` failures.
- Recorded prompt metadata, OpenCode step token counts, tool calls, and canary checks in `runs.jsonl`.

## Calibration results

| Profile | Scale | Prompt est. | Proxy first prompt est. | Actual first input | First TTFT | Decode | Wall | Steps | Grade |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `qwen-32k` | `0.60` | `19,818` | `23,134` | `24,528` | `58.9 s` | `30.2 tok/s` | `109.7 s` | `8` | pass |
| `gemma-32k` | `0.78` | `25,742` | `29,106` | `29,142` | `120.9 s` | `15.6 tok/s` | `133.4 s` | `3` | pass |
| `qwen-48k` | `0.78` | `38,508` | `42,216` | `39,828` | `137.5 s` | `18.2 tok/s` | `175.4 s` | `5` | fail |
| `qwen-65k` | `0.78` | `51,276` | n/a | n/a | `>5 min no first byte` | n/a | stopped | n/a | rejected |
| `qwen-65k` report 29 | old | n/a | `65,807` | `58,742` | `283.8 s` | `11.8 tok/s` | `363.1 s` | `8` | pass |
| `gemma-65k` report 29 | old | n/a | `57,686` | `52,373` | `331.9 s` | `5.4 tok/s` | `399.0 s` | `5` | pass |

Rejected attempts:

- `qwen-32k` with prompt target equal to context was rejected by LM Studio: `n_keep: 35214 >= n_ctx: 32768`.
- `qwen-32k`, scale `0.84`, reached first TTFT `95.5 s` but entered repeated tool-recovery loops and grew prompt history near/past the context envelope.
- `qwen-32k`, scale `0.78`, reached first TTFT `77.4 s` but still looped through repeated short tool/model calls.
- `qwen-48k`, scale `0.78`, missed preferred TTFT and failed to edit the file.
- `qwen-65k`, scale `0.78`, crossed the hard `>5 min` no-first-byte line and was stopped.

## OpenCode resend behavior

OpenCode resends the long prompt plus growing history after each tool call. There was no cache read/write reported by OpenCode token accounting.

Examples:

| Run | First input | Last input | Steps | Interpretation |
| --- | ---: | ---: | ---: | --- |
| Qwen 32k short `js-window` | `24,528` | `26,800` | `8` | History grew but stayed inside 32k due short prompt. |
| Gemma 32k `js-window` | `29,142` | `29,665` | `3` | Cleaner workflow with modest growth. |
| Qwen 48k `js-window` | `39,828` | `40,806` | `5` | Long context resent; failed before useful edit. |
| Gemma 32k `python-ledger` full suite | `29,240` | `31,535` | `3` | Hit total `32768` length on final step. |

## Fuller suite

Qwen 32k short was promoted because it passed the calibration speed gate. It failed the first fuller task, so the run was stopped.

| Profile | Task | Result | First TTFT | First input | Steps | Files modified | Verification |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `qwen-32k`, scale `0.60` | `python-ledger` | fail | `58.9 s` | `24,609` | `7` | `src/ledger.py` | expected `254.11`, got `254.46` |

Gemma 32k was promoted as the cleaner runner-up. It passed 3 of 5 tasks but still failed the suite.

| Task | Result | First TTFT | First input | Steps | Files modified |
| --- | --- | ---: | ---: | ---: | --- |
| `python-ledger` | fail | `166.9 s` | `29,240` | `3` | `src/ledger.py`, `src/__pycache__/...` |
| `java-slug` | fail | first byte `108.8 s` | `29,350` | `3` | `src/main/java/example/Slug.java` |
| `js-window` | pass | `129.1 s` | `29,142` | `3` | `src/windowCounter.mjs` |
| `web-retrieval` | pass | `164.5 s` | `29,643` | `6` | `answer.json` |
| `browser-style` | pass | `154.1 s` | `29,536` | `3` | `app.js` |

## Safety and preservation

- OpenCode ran only under `benchmarks/opencode-agent-benchmark/fixtures/work/...`.
- OpenCode config/data/cache/temp stayed under the benchmark root.
- `external_directory`, `websearch`, user questions, destructive shell patterns, package installs, git commit, and git push remained denied by config.
- Static web access was localhost-only for `web-retrieval`.
- Completed task records reported the canary unchanged.
- Final canary SHA256: `8C2ADF1016E3322F9B0B79AAE295D6FAD53F150578B76F461E27EE8AACE84EF9`.

## Final LM Studio state

Restored state after tests:

| Model | Context | Parallel | Status |
| --- | ---: | ---: | --- |
| `qwen/qwen3-coder-30b` | `65082` | `4` | idle |
| `google/gemma-4-e4b` | `8192` | `4` | idle |

## Recommendation

Use `qwen-32k` with prompt scale `0.60` only when the task is small and speed matters more than autonomous reliability. It is the only tested profile that met the preferred TTFT and decode gate on calibration.

Use `gemma-32k` with prompt scale `0.78` when cleaner tool behavior matters, but treat it as a runner-up: it missed the preferred TTFT target and only passed `3/5` fuller-suite tasks.

Do not make 48k or 65k the default OpenCode agent profile on this hardware. 48k missed the speed gate and failed correctness; 65k did not produce first byte within the hard practical window after prompt trimming.

Do not test 128k for OpenCode agent use. The optimized 65k run already failed the hard practical gate.

## Next steps

1. Add a Windows-specific system/prompt profile for OpenCode tool use, especially command working-directory behavior.
2. Add a smaller `~20k actual input` profile as the real daily OpenCode default.
3. Tighten or simplify `python-ledger` prompt/context before using it as a full-suite gate; both models failed it despite editing the right file.
4. Investigate whether OpenCode can use shorter per-step context, prompt caching, or reduced attachment replay after tool calls.

## Artifacts

| Artifact | Path |
| --- | --- |
| Harness root | `benchmarks/opencode-agent-benchmark` |
| Qwen 32k short calibration | `benchmarks/opencode-agent-benchmark/results/20260620-201327` |
| Gemma 32k calibration | `benchmarks/opencode-agent-benchmark/results/20260620-200956` |
| Qwen 48k calibration | `benchmarks/opencode-agent-benchmark/results/20260620-201654` |
| Qwen 65k stopped calibration | `benchmarks/opencode-agent-benchmark/results/20260620-202038` |
| Qwen fuller suite | `benchmarks/opencode-agent-benchmark/results/20260620-202505` |
| Gemma fuller suite | `benchmarks/opencode-agent-benchmark/results/20260620-202932` |
| Notes | `notes/2026-06-20_20-55-06_opencode-agent-ttft-rerun-results.md` |
