# Optimization Summary 29 - OpenCode Agent Benchmark Final

Created: 2026-06-20 19:47 Europe/Warsaw

## Executive conclusion

At approximately 65k context, both local OpenCode profiles can complete a simple agentic JavaScript coding task, but neither is a comfortable practical default under the requested speed gates. Qwen is the 65k winner because it had lower TTFT and shorter wall time than Gemma, but it still falls below the desired decode-speed gate for iterative agent work.

Recommended default OpenCode profile:

| Field | Value |
| --- | --- |
| Model | `qwen/qwen3-coder-30b` |
| Context | `32768` |
| Parallel | `1` |
| Eval batch size | `2048` |
| Physical batch size | `512` |
| Flash attention | `true` |
| Experts | `4` |
| KV cache offload | `true` |

Keep the existing fast throughput profile separate:

| Field | Value |
| --- | --- |
| Model | `qwen/qwen3-coder-30b` |
| Context | `8192` or current known-good short-context throughput setting |
| Parallel | `4` |
| Purpose | normal fast local use |

Do not proceed to 128k for OpenCode agent use on this hardware. The 65k gate already fails practical speed criteria, and the prior Qwen 128k LM Studio ladder showed `25.3 min` TTFT and `13.89 tok/s` decode.

## Benchmark harness

Created a dedicated disposable benchmark root:

`benchmarks/opencode-agent-benchmark`

The harness includes:

- fixture generator and reset scripts.
- isolated OpenCode config.
- LM Studio timing proxy.
- static local web server.
- prompt/context builder with critical facts near beginning, middle, and end.
- manifest writer and post-run grader.
- profile load/restore script.

Fixture templates created:

| Fixture | Purpose | Verification |
| --- | --- | --- |
| `python-ledger` | Python coding bug | `python tools/test_ledger.py` |
| `java-slug` | Java source task | `node tools/test-java.mjs`; uses `javac` if available |
| `js-window` | JavaScript coding bug | `node tools/test.mjs` |
| `web-retrieval` | local docs retrieval | `node tools/test.mjs` |
| `browser-style` | local UI behavior via DOM harness | `node tools/test.mjs` |

The initial self-check confirmed all seeded fixtures fail before repair. A JDK was not available in PATH, so the Java task uses deterministic source checks unless a JDK is later installed.

## Sandbox design

This is an application-level disposable sandbox, not a VM/kernel boundary.

Controls used:

- OpenCode runs with `--dir` set to a copied fixture workspace under `fixtures/work/<run-id>/<task>`.
- `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, XDG config/data/cache/state, `TEMP`, and `TMP` are redirected under `benchmarks/opencode-agent-benchmark`.
- OpenCode permissions set `external_directory = deny`.
- `websearch` and `question` are denied.
- destructive shell patterns, package installs, git commit, and git push are denied.
- model traffic goes through a local proxy that forwards only to `http://127.0.0.1:1234`.
- a canary file outside the fixture remained unchanged: SHA256 `8C2ADF1016E3322F9B0B79AAE295D6FAD53F150578B76F461E27EE8AACE84EF9`.

OpenCode bootstrapped `@ai-sdk/openai-compatible` under the isolated `.opencode-empty/node_modules` path for the configured LM Studio provider. This was not model-driven and did not use global/user OpenCode config.

## 65k gate results

Both 65k profiles were loaded with:

- context `65536`
- parallel `1`
- eval batch `2048`
- physical batch `512`
- flash attention `true`
- KV offload `true`
- Qwen `num_experts=4`

Task run: `js-window`.

| Profile | Prompt size | First-step input tokens | First TTFT / first byte | Wall time | Grade |
| --- | ---: | ---: | ---: | ---: | --- |
| Gemma `google/gemma-4-e4b` 65k | `213,440` chars / proxy `57,686` token estimate | `52,373` | first byte `311.7 s`; parsed TTFT `331.9 s` | `399.0 s` | pass |
| Qwen `qwen/qwen3-coder-30b` 65k | `243,486` chars / proxy `65,807` token estimate | `58,742` | `283.8 s` | `363.1 s` | pass |

Quality notes:

- Gemma passed after first making a syntactically invalid edit and then self-correcting.
- Qwen made the correct edit immediately, but wasted several tool calls using Bash-style `&&` in PowerShell before recovering.
- Both preserved unrelated files and modified only `src/windowCounter.mjs`.

Speed notes:

- Gemma crossed the example hard TTFT threshold of 5 minutes.
- Qwen stayed just below 5 minutes on the first request, but still missed the preferred under-2-minute target.
- Estimated first-step decode for both is below the `>=30 tok/s` practical gate, around the mid-20 tok/s range when derived from OpenCode token events and proxy timing windows.

## Decision Rules Applied

1. Both Gemma and Qwen were tested first at the ~65k target.
2. Both completed the calibration coding task, but both failed practical speed gates.
3. Qwen is the 65k runner winner by latency and fewer edit mistakes.
4. Because 65k does not satisfy speed gates, 128k was not tested.
5. The recommended default is the smaller Qwen `32768` context profile, supported by the prior long-context ladder: 2/2 retrieval pass, TTFT about `87.9-94.6 s`, decode about `35.06-36.08 tok/s`.

## Final Recommendation

Use Qwen for OpenCode agentic coding, but do not make 65k the default.

Recommended OpenCode model string:

`lmstudio/qwen/qwen3-coder-30b`

Recommended LM Studio load profile for agentic long-context work:

| Setting | Value |
| --- | --- |
| model | `qwen/qwen3-coder-30b` |
| context_length | `32768` |
| parallel | `1` |
| eval_batch_size | `2048` |
| physical_batch_size | `512` |
| flash_attention | `true` |
| num_experts | `4` |
| offload_kv_cache_to_gpu | `true` |

Use 65k only for occasional large-context jobs where a roughly 5-minute first turn is acceptable. Avoid 128k for OpenCode agent use on this hardware.

## Final State

Restored LM Studio state after benchmark:

| Model | Context | Parallel | Status |
| --- | ---: | ---: | --- |
| `qwen/qwen3-coder-30b` | `65082` | `4` | idle |
| `google/gemma-4-e4b` | `8192` | `4` | idle, TTL `60m / 1h` |

## Artifacts

| Artifact | Path |
| --- | --- |
| Benchmark root | `benchmarks/opencode-agent-benchmark` |
| Sandbox design | `benchmarks/opencode-agent-benchmark/docs/sandbox-boundary.md` |
| Config | `benchmarks/opencode-agent-benchmark/opencode-benchmark.config.json` |
| Runner | `benchmarks/opencode-agent-benchmark/scripts/run-opencode-benchmark.ps1` |
| Gemma result | `benchmarks/opencode-agent-benchmark/results/20260620-193153` |
| Qwen result | `benchmarks/opencode-agent-benchmark/results/20260620-194002` |
| Qwen proxy timings | `benchmarks/opencode-agent-benchmark/results/20260620-194002/proxy-events.jsonl` |
| Gemma proxy timings | `benchmarks/opencode-agent-benchmark/results/20260620-193153/proxy-events.jsonl` |

## Sources Checked

- OpenCode config docs: https://opencode.ai/docs/config/
- OpenCode providers docs, including LM Studio custom provider: https://opencode.ai/docs/providers/
- OpenCode permissions docs: https://opencode.ai/docs/permissions
- Local OpenCode CLI help and `debug config`
- Local LM Studio `lms ps`, `lms load --help`, and REST load behavior
- Existing report 28 long-context ladder in this repository
