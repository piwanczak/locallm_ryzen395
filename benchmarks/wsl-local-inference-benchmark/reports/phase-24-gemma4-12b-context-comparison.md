# Phase 24 - Gemma 4 12B Context Comparison

Date: 2026-06-22

## Scope

This phase repeats the Gemma comparison against the actual installed Gemma 4 12B model:

- LM Studio id: `google/gemma-4-12b`
- Display: `Gemma 4 12B Instruct Q4_K_M [GGUF]`
- GGUF: `%USERPROFILE%\.lmstudio\models\lmstudio-community\gemma-4-12B-it-GGUF\gemma-4-12B-it-Q4_K_M.gguf`
- Architecture: `gemma4`
- Downloaded size: about `7.56 GB`
- GGUF advertised context: `262144`

## Bottom Line

Gemma 4 12B is substantially more viable than the earlier E4B fallback, but only after forcing LM Studio/OpenAI-compatible requests to use `reasoning_effort=none`.

With default reasoning behavior, even a 16k protected browser task exhausted `2048` and `4096` output tokens as hidden reasoning and emitted no parseable content. A short probe showed that request field `reasoning_effort: "none"` drops reasoning tokens to zero. After adding that control to the harness, Gemma 4 12B passed Windows LM Studio controlled tasks through the advertised `262k` context and passed a real OpenCode `65k` neutral-padded agent lane.

Do not replace Qwen3 Coder 30B Q4 as the default stack yet. Qwen still has broader accumulated evidence in WSL ROCm, Pi, Docker-controlled, memory sweeps, and challenge/soak runs. Use Gemma 4 12B as a Windows LM Studio high-context lane when the endpoint can inject `reasoning_effort=none`.

## Runtime Gate Results

| Lane | Result | Evidence |
| --- | --- | --- |
| WSL ROCm AMD llama.cpp | Fail to load | `unknown model architecture: 'gemma4'` in `results/20260622-153616-model-matrix/model-matrix-summary.json` |
| Windows LM Studio default reasoning | Fail for browser-style | no visible output; `reasoning_tokens` consumed nearly all output budget in `results/20260622-153648-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json` and `results/20260622-170012-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json` |
| Reasoning control probe | Pass | `reasoning_effort=none` produced visible JSON with zero reasoning tokens in `results/20260622-170855-gemma12-thinking-control-probe/gemma12-thinking-control-probe-summary.json` |
| Windows LM Studio 16k/32k/48k/65k | Pass | `results/20260622-171211-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json` |
| Windows LM Studio 131k/262k | Pass | `results/20260622-171416-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json` |
| OpenCode 65k neutral-padded | Pass | `results/20260622-171740-gemma12-65k-opencode-lmstudio/gemma12-65k-opencode-lmstudio-summary.json` |
| LM Studio raw tool calls | Pass | non-stream and stream probes passed in `results/20260622-174238-gemma12-lmstudio-toolcall-probe/gemma12-lmstudio-toolcall-probe-summary.json` |
| Pi through LM Studio | Pass for file-create | `results/20260622-174543-gemma12-pi-lmstudio-file-create/gemma12-pi-lmstudio-file-create-summary.json` |

## Controlled Context Ladder

These controlled tasks use small prompts. They prove loadability, generation quality on the fixture, verifier-backed edit correctness, and endpoint configuration. They do not prove that the model reasoned over a filled 262k prompt.

All passing rows used `reasoning_effort=none`.

| Context | Calibration | `js-window` | `browser-style` | Verdict |
| --- | --- | --- | --- | --- |
| `16k` | first byte about `512 ms`, zero reasoning tokens | pass | pass | pass |
| `32k` | first byte about `530 ms`, zero reasoning tokens | pass | pass | pass |
| `48k` | first byte about `533 ms`, zero reasoning tokens | pass | pass | pass |
| `65k` | first byte about `529 ms`, zero reasoning tokens | pass | pass | pass |
| `131k` | first byte about `516 ms`, zero reasoning tokens | pass | pass | pass |
| `262k` | first byte about `525 ms`, zero reasoning tokens | pass | pass | pass |

The earlier failure mode is configuration-specific: default LM Studio reasoning parsed nearly all tokens as reasoning and returned no content. The model became reliable on the same benchmark only after the OpenAI-compatible request included `reasoning_effort=none`.

## OpenCode 65k Filled Prompt

This was the real long-prompt agent run for this phase:

- profile: `gemma12-65k`
- context target: `65536`
- prompt source mode: `thin`
- prompt padding: `neutral`
- prompt token target: about `51118`
- endpoint: LM Studio through timing proxy
- proxy injection: `reasoning_effort=none`

| Task | Prompt estimate | Steps | Tool calls | Wall time | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `js-window` | `51367` tokens | `5` | `4` | `701986.5 ms` | pass |
| `browser-style` | `51286` tokens | `5` | `4` | `703161.3 ms` | pass |

The first filled-prompt request took about `656589 ms` before completion and about `656239 ms` before first byte. Subsequent tool-call steps were much faster. This makes Gemma 4 12B usable for occasional high-context OpenCode checks, but not interactive in the same way as the smaller controlled prompts.

## Tool Calling And Pi

Raw LM Studio structured tool calls passed with `reasoning_effort=none`:

- non-streaming: `finishReason=tool_calls`, structured tool call present
- streaming: structured tool-call deltas present

Pi also passed a simple file-create task through LM Studio with a timing proxy injecting `reasoning_effort=none`. The output file contained exactly `PI_GEMMA12_OK`.

This is separate from the promoted WSL ROCm Pi/Jinja lane. The WSL route cannot currently load Gemma 4 12B because AMD's llama.cpp build `8407` does not recognize `gemma4`.

## Comparison Against Current Set

| Candidate | Best supported context from this project | Agent reliability | Tool/Pi status | Recommendation |
| --- | --- | --- | --- | --- |
| Qwen3 Coder 30B Q4 | `16k` proven across controlled, Docker, Pi, OpenCode, and Windows LM Studio; prior Windows work supports practical `32k` | strongest accumulated evidence | WSL ROCm `--jinja` Pi workflow passes file/edit/browser, challenge suite, and soak | keep as default |
| Gemma 4 12B Q4 | Windows LM Studio controlled pass through `262k`; real OpenCode pass at filled `65k` | good after `reasoning_effort=none`, but still much less soak evidence than Qwen | raw LM Studio tool calls pass; Pi file-create through LM Studio passes; WSL ROCm blocked | experimental Windows LM Studio high-context lane |
| Gemma 4 E4B Q4 | Windows LM Studio controlled pass through `65k`; `131k` partial | mixed at filled `65k` OpenCode and partial at `131k` controlled | raw LM Studio tool calls pass; Pi file-create through LM Studio passes | superseded by actual 12B for this lane |
| Qwen2.5 Coder 1.5B Q4/Q8 | fast but failed verifier-backed controlled tasks | insufficient | not promoted | do not use as coding-agent default |

## Decision

Use Gemma 4 12B for Windows LM Studio high-context experiments when all request paths can set `reasoning_effort=none`. The current realistic split is:

- `262k`: proven for LM Studio load plus small verifier-backed controlled tasks, not filled-context reasoning.
- `65k`: proven for a real OpenCode neutral-padded agent run, but slow at first filled-prompt prefill.
- WSL ROCm: blocked until a llama.cpp build supports `gemma4`.
- Pi: viable through LM Studio for a simple file-create proof, not yet promoted for the full file/edit/browser suite.

Keep Qwen3 Coder 30B Q4 as the promoted local coding stack.

## Follow-Up

- Repeat the Pi LM Studio lane on JS edit and browser-style, not only file-create.
- Add a short reliability sweep for Gemma 4 12B controlled tasks with `reasoning_effort=none`.
- Retest WSL after updating llama.cpp to a build that recognizes `gemma4`.
- Try a filled `131k` prompt only as an overnight run; the 65k OpenCode first request already took about 11 minutes.
