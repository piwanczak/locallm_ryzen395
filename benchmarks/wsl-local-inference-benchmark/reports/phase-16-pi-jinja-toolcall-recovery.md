# Phase 16 Pi Jinja Tool-Call Recovery

Date: 2026-06-22

## Scope

This phase revisits the Phase 15 Pi failure with the corrected llama.cpp serving mode. The target was not only endpoint reachability. The target was Pi executing real tools against a local model endpoint and leaving all evidence in the Windows project folder.

## Final Decision

Pi now works locally with executable tool calling for the tested small coding-agent tasks.

The promoted path is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-jinja-q4-toolcall-workflow.ps1 `
  -UseExistingServer `
  -Tasks file-create,js-edit,browser-style
```

When starting the server through the workflow or manually, the important endpoint change is `LLAMA_JINJA=1`, which adds `--jinja` to llama.cpp.

## What Changed

The ROCm llama.cpp launcher now supports:

- `LLAMA_JINJA=1`
- `LLAMA_CHAT_TEMPLATE`
- `LLAMA_CHAT_TEMPLATE_FILE`
- `LLAMA_CHAT_TEMPLATE_KWARGS`

The Pi Docker runner now supports:

- `-NoTty` for non-interactive Compose runs.
- stdout-friendly Compose status handling.
- safer capture of Docker exit codes.

The endpoint probe script now supports both non-streaming and streaming tool-call probes.

The new wrapper `scripts/run-pi-jinja-q4-toolcall-workflow.ps1` runs:

- raw non-stream tool-call probe,
- raw stream tool-call probe,
- Pi file creation task,
- Pi JS edit task,
- Pi browser-style frontend task,
- Docker-volume session export into the Windows result directory.

## Endpoint Evidence

Canonical run:

- `results/20260622-102758-pi-jinja-q4-toolcall-workflow`

Raw probe results:

| Probe | Exit | Structured tool calls | Detail |
| --- | ---: | --- | --- |
| `endpoint-tool-call-probe-nonstream.json` | `0` | yes | `finishReason=tool_calls`, tool `write` |
| `endpoint-tool-call-probe-stream.json` | `0` | yes | 12 streamed tool-call delta chunks |

The non-stream `/props` capture reports:

- chat template present,
- `chat_template_tool_use` not separately present,
- `supports_tools=true`,
- `supports_tool_calls=true`,
- `supports_parallel_tool_calls=true`.

Interpretation: with `--jinja`, this llama.cpp/Qwen3 Coder endpoint can emit structured OpenAI tool calls. Phase 15's failure was not caused by Docker or Pi image reachability.

## Pi Task Evidence

Workflow summary:

- `results/20260622-102758-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json`
- summary size: 9573 bytes
- `passed=true`
- llama.cpp start exit: `0`
- llama.cpp stop exit: `0`

| Task | Pi exit | Verifier | Session proof |
| --- | ---: | --- | --- |
| `file-create` | `0` | `pi_docker_result.txt` contains `PI_DOCKER_OK` | assistant `toolCall` `write`, successful `toolResult` |
| `js-edit` | `0` | `JS_EDIT_OK` | `read`, failing `bash`, `write`, passing `bash` |
| `browser-style` | `0` | `BROWSER_STYLE_OK` | `read`/`bash`, `write`, passing browser verifier |

Each session log was copied from the Docker volume into the matching Windows result directory as `pi-session.jsonl`.

## Browser Fix

The first browser-style proof was partially valid but had a verifier bug. The Pi browser image had Playwright installed globally, while `verify.mjs` used a bare ESM import:

```js
import { chromium } from "playwright";
```

Node did not resolve that global package from the mounted workspace. The verified fixture now uses:

```js
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { chromium } = require("/usr/local/lib/node_modules/playwright");
```

After that correction, Pi edited `app.js`, ran `node verify.mjs`, and received `BROWSER_STYLE_OK`.

## Why Tool Calling Failed Before

Phase 15 observed assistant text that looked like a Qwen function call, but Pi did not execute it. That was accurate for the old endpoint configuration.

The corrected finding is narrower:

- Without `--jinja`, the endpoint produced text that Pi treated as ordinary assistant content.
- With `--jinja`, raw endpoint probes produce structured OpenAI `tool_calls`.
- Pi still needed an appended local reminder to emit a complete Qwen tool block including the opening `<tool_call>` tag.
- Once both conditions were present, Pi recorded real `toolCall` and `toolResult` events.

No Pi adapter is currently required for the tested small tasks.

## Repeatable Command Shape

Start an existing server manually:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/'LocalInference - dzienniczek'/benchmarks/wsl-local-inference-benchmark && MODEL_PATH=/mnt/c/Users/<you>/.lmstudio/models/lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-GGUF/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf MODEL_ALIAS=qwen/qwen3-coder-30b-q4 PORT=8091 CTX_SIZE=8192 PARALLEL=1 LLAMA_JINJA=1 bash scripts/start-wsl-llama-server-amd.sh"
```

Run the full Pi validation against it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-jinja-q4-toolcall-workflow.ps1 `
  -UseExistingServer `
  -Tasks file-create,js-edit,browser-style
```

Or let the wrapper start and stop its own server by omitting `-UseExistingServer`.

## Status

Promoted:

- WSL ROCm llama.cpp Q4 endpoint with `--jinja`.
- Pi Docker runner with appended Qwen tool-call format reminder.
- `run-pi-jinja-q4-toolcall-workflow.ps1` for repeatable validation.

Kept as baseline:

- Docker-controlled non-Pi runner for simpler controlled edit/browser benchmarking.

Rejected for now:

- Building a Pi adapter. It is unnecessary for this validated path.
