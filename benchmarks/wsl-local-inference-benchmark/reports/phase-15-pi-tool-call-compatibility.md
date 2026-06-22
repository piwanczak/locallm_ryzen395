# Phase 15 Pi Tool-Call Compatibility Report

Date: 2026-06-22

Update: Phase 16 supersedes this report for the tested small tasks. The failure below is still accurate for the old endpoint configuration, but Pi works when llama.cpp runs with `--jinja` and Pi receives the local Qwen tool-call format reminder.

## Scope

This phase closes the Pi-specific ambiguity left after Docker was installed and enabled for WSL. The question is no longer whether Docker can run. It can. The question is whether Pi can execute tools against the current local llama.cpp OpenAI-compatible Qwen endpoint.

## Evidence Checked

| Evidence | Result |
| --- | --- |
| Pi package version in `local/pi-agent:base` | `0.79.9` |
| Prior real Pi edit attempt | `../results/20260621-233951-pi-docker-q4-agent-edit-compat/pi-docker-q4-agent-edit-summary.json` |
| Pi Docker session volume | `pi-docker-agent-runner_pi-agent-sessions` |
| Session files inspected | Three failed edit attempts, each with five JSONL events |
| Pi custom provider docs | Tool calls must be emitted as provider stream events and parsed `toolCall` blocks |
| Pi model compatibility docs | Compatibility flags adjust request fields such as roles, token field names, streaming usage, and strict tool schema fields |

## Session Log Finding

Each Pi session recorded the same structure:

- Session started in `/workspace`.
- Model selected: `local-openai/qwen/qwen3-coder-30b-q4`.
- Thinking was disabled.
- User asked Pi to create `pi_docker_result.txt`.
- Assistant response was recorded as a plain `text` content block containing Qwen/llama.cpp function-tag text for `write`.

There was no assistant `toolCall` content block and no `toolResult` message. Pi therefore had nothing executable to dispatch, and the mounted workspace did not receive `pi_docker_result.txt`.

## Provider Contract

Pi's custom provider interface expects structured tool-call events:

| Event | Meaning |
| --- | --- |
| `toolcall_start` | A provider has started a tool call block |
| `toolcall_delta` | A provider is streaming tool-call JSON |
| `toolcall_end` | A provider has completed a parsed `toolCall` block |

This is a provider responsibility. Pi does not infer executable tools from arbitrary assistant text in the session transcript.

## Compatibility Flag Check

The current Pi Docker wrapper already applies the relevant local OpenAI compatibility flags:

- `supportsStore = false`
- `supportsDeveloperRole = false`
- `supportsReasoningEffort = false`
- `supportsUsageInStreaming = false`
- `maxTokensField = "max_tokens"`
- `supportsStrictMode = false`

Those flags fix request compatibility with llama.cpp-style OpenAI endpoints. They do not translate model output text into executable Pi tool calls.

## Decision

Pi Docker is now classified as:

> Build-validated and endpoint-connected, but tool-call incompatible with the current local llama.cpp/Qwen endpoint.

That is a bounded failure. Docker, WSL networking, the Pi image, the mounted model config, and the local model endpoint all work. The missing piece is a structured tool-call adapter.

Do not promote Pi as the default local editing agent for this setup. Use one of the proven workflows instead:

1. Host/WSL controlled workflow: `scripts/run-recommended-q4-workflow.ps1`
2. Docker-controlled workflow: `scripts/run-docker-controlled-q4-workflow.ps1 -Build`

## Promotion Path

Pi can be revisited if one of these becomes true:

1. The local endpoint returns structured executable tool calls that Pi recognizes.
2. A Pi custom provider/adapter parses Qwen/llama.cpp function-tag text and emits Pi `toolCall` events.
3. Pi adds native support for this Qwen/llama.cpp function-tag format.

Until then, rerunning the same Pi edit benchmark is expected to fail in the same way.
