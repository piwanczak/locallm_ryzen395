# Phase 23 - Gemma 4 E4B Context Comparison

Date: 2026-06-22

## Scope

The requested target was Gemma 4 12B. That model is not installed locally in this environment. The only local Gemma 4 model found was:

- LM Studio id: `google/gemma-4-e4b`
- Size label: `7.5B`
- GGUF: `%USERPROFILE%\.lmstudio\models\lmstudio-community\gemma-4-E4B-it-GGUF\gemma-4-E4B-it-Q4_K_M.gguf`
- Architecture: `gemma4`
- Reported max context: `131072`

This phase therefore tests the installed Gemma 4 E4B model as the nearest available Gemma candidate. The results below must not be treated as Gemma 4 12B results.

## Bottom Line

Gemma 4 E4B is useful as a Windows LM Studio high-context experiment, but it does not replace the promoted Qwen3 Coder 30B Q4 stack.

The clean practical Gemma E4B ceiling from this run is `65k` context in Windows LM Studio for verifier-backed controlled tasks. A `131k` load works and `js-window` passes, but protected `browser-style` fails under the same 2-attempt controlled gate. OpenCode at a real neutral-padded `65k` prompt is mixed: `browser-style` passes, while `js-window` stops without tool calls and fails. Pi can execute a simple file-create task through LM Studio Gemma tool calls, but the promoted WSL ROCm Pi/Jinja lane cannot load this `gemma4` GGUF with the current AMD llama.cpp build.

## Runtime Gate Results

| Lane | Result | Evidence |
| --- | --- | --- |
| WSL ROCm AMD llama.cpp | Fail to load | `unknown model architecture: 'gemma4'` in `../results/20260622-145214-model-matrix/model-matrix-summary.json` |
| Windows LM Studio 16k/32k | Pass | `../results/20260622-145415-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json` |
| Windows LM Studio 48k/65k | Pass | `../results/20260622-145556-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json` |
| Windows LM Studio 131k | Partial | `js-window` passed; `browser-style` failed in `../results/20260622-145758-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json` |
| OpenCode 65k neutral-padded | Mixed | `browser-style` passed; `js-window` failed in `../results/20260622-150244-gemma-65k-opencode-lmstudio/gemma-65k-opencode-lmstudio-summary.json` |
| LM Studio raw tool calls | Pass | non-stream and stream probes passed in `../results/20260622-151739-gemma-lmstudio-toolcall-probe/gemma-lmstudio-toolcall-probe-summary.json` |
| Pi through LM Studio | Pass for file-create | real Pi `write` tool call in `../results/20260622-152232-gemma-lmstudio-pi-file-create/gemma-lmstudio-pi-file-create-summary.json` |

## Controlled Context Ladder

These controlled tasks use small prompts. They test loadability, generation quality on the benchmark fixtures, and verifier-backed edit correctness. They do not prove the model can reason over the full context length.

| Context | Calibration | `js-window` | `browser-style` | Verdict |
| --- | --- | --- | --- | --- |
| `16k` | `51.93 tok/s`, first byte `336.7 ms` | pass, first content `782.7 ms` | pass, first content `22644.6 ms` | pass |
| `32k` | `51.92 tok/s`, first byte `289.4 ms` | pass, first content `750.5 ms` | pass, first content `22779.2 ms` | pass |
| `48k` | `51.21 tok/s`, first byte `281.4 ms` | pass, first content `770.2 ms` | pass, first content `28323.5 ms` | pass |
| `65k` | `50.74 tok/s`, first byte `280.8 ms` | pass, first content `723.3 ms` | pass, first content `27888.1 ms` | pass |
| `131k` | `51.19 tok/s`, first byte `304.0 ms` | pass, first content `783.7 ms` | fail after 2 attempts | partial |

The `131k` browser-style failure is not a load failure. The model generated the right conceptual fix, but attempt 1 returned malformed JSON and attempt 2 used an exact replacement that did not match the file. Under the same 2-attempt controlled gate used elsewhere, this is a reliability failure.

## OpenCode 65k Filled Prompt

This was a real long-prompt agent run, not only a large configured context. It used:

- profile: `gemma-65k`
- context target: `65536`
- prompt source mode: `thin`
- prompt padding: `neutral`
- prompt token target: `51118`

| Task | Prompt estimate | Steps | Tool calls | Wall time | Result |
| --- | --- | --- | --- | --- | --- |
| `js-window` | `51365` tokens | `1` | `0` | `297310.6 ms` | fail; stopped without edits |
| `browser-style` | `51284` tokens | `8` | `7` | `504804.9 ms` | pass |

This proves Gemma E4B can run a real 65k OpenCode task, but the behavior is not stable enough to promote. The first long-prompt OpenCode task spent about five minutes and then stopped without using tools.

## Tool Calling And Pi

LM Studio advertises this local model as trained for tool use. The raw OpenAI-compatible probe confirmed structured tool calls:

- non-streaming: `finishReason=tool_calls`, tool `write`
- streaming: structured `tool_call` deltas present

Pi through LM Studio also passed a real file-create probe:

- model: `local-openai/google/gemma-4-e4b`
- endpoint from container: `http://host.docker.internal:1234/v1`
- Pi session contained assistant `toolCall` `write`
- output file contained exactly `PI_DOCKER_OK`

This is a separate lane from the promoted WSL ROCm Pi/Jinja setup. The WSL Gemma path is blocked because the current AMD llama.cpp runtime cannot load `gemma4`.

## Comparison Against Current Set

| Candidate | Best supported context from this project | Agent reliability | Tool/Pi status | Recommendation |
| --- | --- | --- | --- | --- |
| Qwen3 Coder 30B Q4 | `16k` proven across controlled, Docker, Pi, OpenCode, and Windows LM Studio; prior Windows long-context work supports practical `32k` | strongest accumulated evidence | WSL ROCm `--jinja` Pi workflow passes file/edit/browser and challenge suite | keep as default |
| Qwen3 Coder 30B Q2 | useful fallback, passed Pi endpoint comparison | less accumulated evidence than Q4 | Pi workflow passed | fallback only |
| Qwen2.5 Coder 1.5B Q4/Q8 | fast but failed verifier-backed controlled tasks | insufficient | not promoted | do not use as coding-agent default |
| Gemma 4 E4B Q4 | Windows LM Studio controlled pass through `65k`; `131k` partial | mixed at filled `65k` OpenCode and partial at `131k` controlled | raw LM Studio tool calls pass; Pi file-create through LM Studio passes | experimental high-context Windows lane |

## Decision

Use Gemma 4 E4B when the experiment specifically needs Windows LM Studio high-context testing or LM Studio-native tool-call probing. Do not replace Qwen3 Coder 30B Q4 as the promoted local coding stack.

For practical context:

- Promote `65k` only as an experimental Gemma E4B context target.
- Treat `131k` as loadable but not reliable under the current controlled gate.
- Treat true Gemma 4 12B as untested until a 12B model is installed.

## Follow-Up

- Install a real Gemma 4 12B GGUF or LM Studio entry if that remains the intended target.
- Retest WSL after updating llama.cpp to a build that supports `gemma4`.
- If Pi-through-LM-Studio matters, extend the single file-create proof to JS edit and browser-style tasks.
- Run a 3-5 iteration Gemma E4B 65k OpenCode reliability sweep before using it for real frontend work.
