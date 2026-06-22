# Optimization Summary 31 - OpenCode Thin Prompt TTFT Sweep

Created: 2026-06-20 22:38 Europe/Warsaw

## Executive Conclusion

Thin, source-on-demand prompting is the biggest practical TTFT win so far. Removing full fixture source attachments dropped Qwen's `js-window` first TTFT from the earlier best `58.9 s` at about `24.5k` actual input tokens to `12.6 s` at about `8.7k` actual input tokens.

The reliability result is more mixed:

| Role | Profile | Recommendation |
| --- | --- | --- |
| Fastest simple-task profile | Qwen 16k, thin prompt, no padding | Use only for small supervised tasks. It is fast, but still has poor Windows shell behavior. |
| Cleaner calibration profile | Gemma 16k, thin prompt, no padding | Best next fuller-suite candidate. It was slower than Qwen on first byte but much cleaner with tool use. |
| Rejected for default | Qwen 16k fuller suite | Failed the first fuller task after a long `python-ledger` loop. |
| Rejected knob | Physical batch `256` | Slower first TTFT and severe wall-time/tool churn. |
| Unavailable through REST | KV quantization and speculative MTP fields | LM Studio REST rejected the probed keys. |

The current best practical next profile is **Gemma 16k thin/no-padding** for correctness/tool behavior investigation, and **Qwen 16k thin/no-padding** only as a speed-first profile for simple tasks.

## Harness Changes

- Added prompt construction modes:
  - `--source-mode full|thin`
  - `--padding-mode distractor|neutral|none`
- Added exact prompt token target support through `-PromptTokenTarget`.
- Added benchmark-only `8k`, `16k`, and `24k` profile support.
- Added batch-size parameters to the runner.
- Added optional experimental KV/speculative load fields for controlled probing.
- Added `probe-lmstudio-load-options.ps1` to save state, probe one setting at a time, and restore.
- Added stronger PowerShell verifier guidance to the prompt.
- Added a benchmark-only `*&&*` bash deny rule, though OpenCode did not consistently apply it before command execution.

## Calibration Results

| Run | Model | Context | Prompt mode | Prompt est. | Actual first input | First TTFT / byte | Decode est. | Wall | Steps | Bad `&&` calls | Grade |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| `20260620-211759` | Qwen | `16k` | thin, none, pre-tweak | `628` | `8,528` | `12.3 s` | `35.68` | `73.5 s` | `13` | `7` | pass |
| `20260620-212034` | Qwen | `16k` | thin, none, stronger prompt | `747` | `8,668` | `12.7 s` | `35.68` | `71.4 s` | `10` | `3` | pass |
| `20260620-212311` | Qwen | `16k` | thin, none, prompt plus deny rule | `767` | `8,683` | `12.6 s` | `22.78` | `54.2 s` | `10` | `4` | pass |
| `20260620-212534` | Qwen | `16k` | thin, neutral 8k | `8,132` | `14,495` | byte `26.6 s` | n/a | `68.7 s` | `10` | `2` | pass |
| `20260620-212749` | Qwen | `24k` | thin, neutral 12k | `12,054` | `17,725` | `36.6 s` | `6.51` | `85.0 s` | `9` | `1` | pass |
| `20260620-213026` | Qwen | `32k` | thin, neutral 16k | `16,071` | `20,870` | `46.7 s` | `17.46` | `124.5 s` | `14` | `3` | pass |
| `20260620-223543` | Gemma | `16k` | thin, none | `768` | `8,217` | byte `15.6 s` | n/a | `50.8 s` | `4` | `0` | pass |

Interpretation:

- Qwen thin/no-padding is now comfortably below the two-minute TTFT target on calibration.
- The measured input ladder stayed practical through about `20.9k` actual first input tokens.
- Qwen still resends growing context after tool calls and reports no OpenCode cache reads/writes.
- Gemma handled the Windows shell correctly, using `workdir` and the plain verifier command.

## Batch Sweep

All rows used Qwen 24k with thin neutral 12k prompt target.

| Eval batch | Physical batch | Actual first input | First TTFT | Wall | Steps | Grade | Decision |
| ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| `2048` | `512` | `17,725` | `36.6 s` | `85.0 s` | `9` | pass | Keep baseline |
| `1024` | `512` | `17,725` | `35.6 s` | `105.6 s` | `14` | pass | No meaningful TTFT win |
| `2048` | `256` | `17,725` | `40.1 s` | `311.1 s` | `13` | pass | Reject |

The baseline `2048/512` setting remains best overall. Lowering eval batch gave only a tiny first-TTFT change and worse overall behavior. Lowering physical batch was clearly worse.

## KV And Speculative Probes

Probe artifact: `benchmarks/opencode-agent-benchmark/results/20260620-211655-load-option-probe/load-option-probe.json`.

| Candidate | Result |
| --- | --- |
| `llama_k_cache_quantization_type` / `llama_v_cache_quantization_type` | Rejected: unrecognized keys |
| `llamaKCacheQuantizationType` / `llamaVCacheQuantizationType` | Rejected: unrecognized keys |
| `speculative_draft_mtp` | Rejected: unrecognized key |
| `speculativeDraftMtp` | Rejected: unrecognized key |

The current LM Studio REST load endpoint does not expose these settings for the OpenCode benchmark path. Direct llama.cpp remains the route for KV quantization or speculative decoding experiments.

## Fuller-Suite Promotion

Qwen 16k thin/no-padding was promoted because it was the speed winner on calibration.

Result:

- Run: `benchmarks/opencode-agent-benchmark/results/20260620-214315`
- It remained on `python-ledger` for about 50 minutes and was manually stopped.
- The runner did not emit a normal `task_run` record because OpenCode never returned.
- Manual post-timeout grade failed with the benchmark Python path:
  - `invoice-level rounding: expected 254.11, got 254.46`
- Modified files:
  - `src/ledger.py`
  - `src/__pycache__/ledger.cpython-312.pyc`
- Canary SHA256 remained unchanged.

This rejects Qwen 16k thin/no-padding as an autonomous fuller-suite profile despite excellent calibration TTFT.

## Safety And Final State

- OpenCode ran under disposable fixtures in `benchmarks/opencode-agent-benchmark/fixtures/work`.
- OpenCode config/data/cache/state/temp stayed under the benchmark root.
- Live web search, external directories, package installs, destructive shell patterns, git commit, and git push remained denied.
- The canary hash remained unchanged: `8C2ADF1016E3322F9B0B79AAE295D6FAD53F150578B76F461E27EE8AACE84EF9`.
- After cleanup, no benchmark OpenCode/timing-proxy processes remained.
- LM Studio was restored to:

| Model | Context | Parallel | Status |
| --- | ---: | ---: | --- |
| `qwen/qwen3-coder-30b` | `65082` | `4` | idle |
| `google/gemma-4-e4b` | `8192` | `4` | idle |

## Recommendation

Use thin source-on-demand prompts as the default direction. Do not attach full fixture source for normal small-to-medium coding tasks unless the task truly requires offline context.

For the next benchmark step:

1. Promote **Gemma 16k thin/no-padding** to a fuller suite. It has the best observed tool behavior in this pass.
2. Keep **Qwen 16k thin/no-padding** as a speed-only calibration profile, not as the autonomous default.
3. Keep Qwen measured input bands around `8k-18k` actual first input for practical use. The `20.9k` band still passed but took longer and had more tool churn.
4. Keep LM Studio batch baseline at `eval_batch_size=2048`, `physical_batch_size=512`.
5. Treat KV quantization and speculative decoding as direct llama.cpp experiments, not current LM Studio REST profile knobs.

## Artifacts

| Artifact | Path |
| --- | --- |
| Thin prompt harness | `benchmarks/opencode-agent-benchmark/scripts/build-prompt.mjs` |
| Benchmark runner | `benchmarks/opencode-agent-benchmark/scripts/run-opencode-benchmark.ps1` |
| Load option probe | `benchmarks/opencode-agent-benchmark/scripts/probe-lmstudio-load-options.ps1` |
| Qwen 16k no-padding best calibration | `benchmarks/opencode-agent-benchmark/results/20260620-212311` |
| Qwen 24k 12k-band baseline | `benchmarks/opencode-agent-benchmark/results/20260620-212749` |
| Qwen 32k 16k-band calibration | `benchmarks/opencode-agent-benchmark/results/20260620-213026` |
| Batch sweep eval 1024 | `benchmarks/opencode-agent-benchmark/results/20260620-213343` |
| Batch sweep physical 256 | `benchmarks/opencode-agent-benchmark/results/20260620-213635` |
| Timed-out Qwen fuller suite | `benchmarks/opencode-agent-benchmark/results/20260620-214315` |
| Gemma 16k calibration | `benchmarks/opencode-agent-benchmark/results/20260620-223543` |
| Run note | `notes/2026-06-20_22-38-09_opencode-agent-thin-prompt-ttft-sweep.md` |
