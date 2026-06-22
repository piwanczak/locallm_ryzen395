# WSL2 Setup And Benchmark Runbook

Created: 2026-06-21

This runbook is intentionally split into approval gates. The benchmark goal allows read-only inventory now, but distro/package/runtime installation needs explicit approval.

All durable benchmark outputs should be written under this Windows workspace. WSL commands run from `/mnt/c/Users/<you>/Documents/locallm_ryzen395-public`, so reports, notes, logs, and results migrate directly into the shared Windows folder instead of staying inside the Linux filesystem.

## Source Checks

Primary sources checked on 2026-06-21:

- Microsoft WSL install docs: https://learn.microsoft.com/en-us/windows/wsl/install
- Microsoft WSL GPU acceleration docs: https://learn.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl
- AMD ROCm on Ryzen WSL guide: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/wsl/howto_wsl.html
- AMD Ryzen llama.cpp prebuilt-binaries guide: https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/advanced/advancedryz/linux/llm/llamacpp.html
- AMD ROCDXG repository and compatibility matrix: https://github.com/ROCm/librocdxg/

Key implications for this machine:

- WSL itself is present and defaults to WSL2. At initial preflight no distro was installed; `Ubuntu-24.04` is now installed.
- Microsoft documents `wsl --install -d <Distro>` and `wsl.exe --list --online` for selecting a distro.
- AMD's Ryzen WSL guide says Ubuntu `24.04` and `22.04` are supported WSL distros for this path.
- AMD documents ROCDXG as the WSL ROCm bridge through `/dev/dxg`.
- AMD's ROCDXG compatibility table includes `AMD Ryzen AI Max+ 395` in the ROCm `7.2.x` row.
- AMD documents validated Linux llama.cpp binaries for Ubuntu 24.04 with `gfx110X`, `gfx115X`, and `gfx120X` support.

## Approval Gate 1 - Install Distro

Recommended first distro: Ubuntu 24.04.

Reason:

- It is listed by AMD's WSL Ryzen guide.
- AMD's validated llama.cpp binary instructions are written for Ubuntu 24.04.
- It avoids starting from an older base while still being a stable LTS target.

Command after approval:

```powershell
wsl.exe --install -d Ubuntu-24.04
```

Guarded benchmark wrapper after approval:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\prepare-wsl-distro.ps1 `
  -Distro Ubuntu-24.04 `
  -Install `
  -ConfirmInstall `
  -NoLaunch `
  -LinuxUser root `
  -RunLinuxPreflight
```

Without `-Install -ConfirmInstall`, the wrapper records read-only WSL state only.

If the distro name is not present locally, first inspect available names:

```powershell
wsl.exe --list --online
```

If the install hangs at download, Microsoft documents this alternate form:

```powershell
wsl.exe --install --web-download -d Ubuntu-24.04
```

After install:

```powershell
wsl.exe -l -v
wsl.exe --distribution Ubuntu-24.04 -- uname -a
```

## Approval Gate 2 - Read-Only Linux Preflight

Run this before installing ROCm, Vulkan tools, llama.cpp, Ollama, or anything else:

```powershell
wsl.exe --distribution Ubuntu-24.04 -- bash -lc "cd /mnt/c/Users/<you>/Documents/locallm_ryzen395-public && bash benchmarks/wsl-local-inference-benchmark/scripts/wsl-preflight.sh benchmarks/wsl-local-inference-benchmark/results/wsl-linux-preflight"
```

For an uninitialized `--no-launch` distro, run the preflight as root first:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\prepare-wsl-distro.ps1 `
  -Distro Ubuntu-24.04 `
  -LinuxUser root `
  -RunLinuxPreflight
```

Expected useful checks:

- `/dev/dxg` for WSL GPU virtualization.
- `/usr/lib/wsl/lib/libdxcore.so` for DXCore.
- any existing `/dev/dri` or `/dev/kfd`.
- existing `vulkaninfo`, `rocminfo`, `hipconfig`, `llama-server`, `ollama`, `node`, and build tools.

## Approval Gate 3 - Minimal Runtime Install

Choose one path at a time. Do not mix ROCm, Vulkan, Ollama, and source builds in one step.

Before runtime-specific installs, install only baseline Linux tools:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/locallm_ryzen395-public && CONFIRM_WSL_BASE_TOOLS_INSTALL=1 bash benchmarks/wsl-local-inference-benchmark/scripts/setup-wsl-base-tools.sh"
```

Recommended order:

| Order | Candidate | Why |
| ---: | --- | --- |
| 1 | AMD validated llama.cpp ROCm binary | Directly tests AMD's current WSL Ryzen/ROCm claim for this class of APU |
| 2 | llama.cpp Vulkan binary or local build | Closest analogue to the current Windows Vulkan winner |
| 3 | Ollama | Useful alternative host only if its backend is clear and measurable |
| 4 | source-built llama.cpp | Use only if binaries fail or lack required flags |

For ROCm, the install path likely needs ROCDXG and ROCm user-space packages. Follow AMD's current WSL Ryzen guide rather than old roc4wsl notes.

Use the prebuilt ROCDXG release asset before falling back to a source build. The guarded script registers AMD's ROCm `7.2.4` Ubuntu Noble repository, installs ROCm userspace and `rocdxg-roct_1.2.0_amd64.deb`, and deliberately does not install `amdgpu-dkms` on WSL:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/locallm_ryzen395-public && CONFIRM_WSL_ROCDXG_INSTALL=1 bash benchmarks/wsl-local-inference-benchmark/scripts/setup-wsl-rocdxg.sh"
```

For llama.cpp, prefer a binary or build that exposes:

- `llama-server`
- `llama-bench`
- `--ctx-size`
- `--parallel`
- `--batch-size`
- `--ubatch-size`
- `--flash-attn`
- `--cache-type-k`
- `--cache-type-v`
- `--cache-prompt`
- `--cache-reuse`

AMD's validated Ubuntu 24.04 ROCm llama.cpp package for `gfx110X`, `gfx115X`, and `gfx120X` can be installed with:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/locallm_ryzen395-public && CONFIRM_WSL_LLAMA_DOWNLOAD=1 bash benchmarks/wsl-local-inference-benchmark/scripts/setup-wsl-llamacpp-amd.sh"
```

The downloaded AMD package needs its extracted directory on `LD_LIBRARY_PATH`; use the checked-in launcher instead of invoking `llama-server` directly:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/locallm_ryzen395-public && PORT=8080 CTX_SIZE=8192 PARALLEL=1 bash benchmarks/wsl-local-inference-benchmark/scripts/start-wsl-llama-server-amd.sh"
```

Stop it with:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/locallm_ryzen395-public && bash benchmarks/wsl-local-inference-benchmark/scripts/stop-wsl-llama-server-amd.sh"
```

## Runtime Smoke Command Shape

Once a server is listening locally from WSL, measure it from Windows:

```powershell
node .\benchmarks\wsl-local-inference-benchmark\scripts\run-openai-compatible-calibration.mjs `
  --base-url http://127.0.0.1:8080/v1 `
  --model qwen/qwen3-coder-30b `
  --max-tokens 256 `
  --concurrency 1 `
  --output .\benchmarks\wsl-local-inference-benchmark\results\calibration-qwen-single.json
```

Then test aggregate behavior:

```powershell
node .\benchmarks\wsl-local-inference-benchmark\scripts\run-openai-compatible-calibration.mjs `
  --base-url http://127.0.0.1:8080/v1 `
  --model qwen/qwen3-coder-30b `
  --max-tokens 256 `
  --concurrency 4 `
  --output .\benchmarks\wsl-local-inference-benchmark\results\calibration-qwen-4way.json
```

## Multi-Model Matrix Shape

Once the WSL ROCm llama.cpp runtime works, run already-downloaded local GGUFs through the repeatable matrix wrapper:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\run-wsl-model-matrix.ps1 `
  -Models gemma-4-e4b-q4,qwen25-coder-15b-q4 `
  -ContextSize 8192
```

The wrapper starts one WSL llama.cpp server per model, runs OpenAI-compatible calibration, optionally runs the controlled `js-window` edit-agent task, stops the server, and writes results under `benchmarks\wsl-local-inference-benchmark\results`.

## Recommended Q4 Workflow

Run the current default local workflow end to end:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-recommended-q4-workflow.ps1
```

This wrapper runs Qwen3 Coder 30B Q4 through single-request calibration, controlled `js-window`, controlled protected `browser-style`, and 4-way throughput calibration. It writes a top-level `recommended-q4-workflow-summary.json` that links the generated matrix artifacts.

## WSL Memory-Cap Sweep Shape

The memory sweep is intentionally guarded because it edits `%USERPROFILE%\.wslconfig` and runs `wsl.exe --shutdown` between caps.

Dry-run only:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\run-wsl-memory-cap-sweep.ps1
```

Actual sweep after approval:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\run-wsl-memory-cap-sweep.ps1 `
  -Apply `
  -ConfirmWslShutdown `
  -ConfirmWslConfigWrite `
  -MemoryCaps 65GB,48GB,32GB `
  -Model qwen3-coder-30b-q4
```

The script backs up the previous `.wslconfig` into the sweep result directory, runs Qwen3 Coder Q4 controlled `js-window` and protected `browser-style`, runs 4-way throughput calibration, restores the previous `.wslconfig`, and shuts WSL down once more so the restored config applies on next launch.

Observed on 2026-06-22: `32GB` passed the current host/WSL Qwen3 Coder Q4 controlled workflow and 4-way throughput. Use `32GB` if reclaiming Windows RAM matters for this workflow; use `48GB` for extra headroom before Docker-heavy, browser-container, long-context, or multi-agent runs.

For the Pi-specific memory sweep:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-memory-cap-sweep.ps1 `
  -MemoryCaps DEFAULT,48GB,32GB `
  -Apply `
  -ConfirmWslShutdown `
  -ConfirmWslConfigWrite
```

Observed on 2026-06-22: the Pi Docker file/edit/browser workflow passed at `DEFAULT`, `48GB`, and `32GB`. This proves `32GB` for the current Pi proof workflow, but not yet for long soak, challenge suite, endpoint comparisons, or larger contexts.

## Pi Reliability And Comparison Shapes

Run the repeated Pi reliability soak:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-reliability-soak.ps1 `
  -Iterations 10 `
  -Tasks file-create,js-edit,browser-style
```

Run the small Pi coding challenge suite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-challenge-suite.ps1 `
  -Tasks single-function,multi-file,canary-preserve,browser-form,failing-command-recovery
```

Run the runner comparison:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-runner-comparison.ps1
```

Run the Pi endpoint comparison:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-endpoint-comparison.ps1 `
  -Variants q4-ctx8192,q4-ctx4096,q2-ctx8192 `
  -Tasks file-create,js-edit,browser-style
```

Regenerate the local dashboard:

```powershell
node .\benchmarks\wsl-local-inference-benchmark\scripts\generate-local-inference-dashboard.mjs
```

Observed on 2026-06-22: Pi passed the 10-run soak, the five-task challenge suite, the runner comparison, and endpoint comparison. Use Qwen3 Coder 30B Q4 at 8k context with `LLAMA_JINJA=1` as the promoted endpoint. Use host/WSL controlled runner for the default measurement harness; use Pi when validating Dockerized agentic tool execution.

## 16k Context Comparison Shape

Run the controlled WSL ROCm 8k vs 16k comparison:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-16k-controlled-context-comparison.ps1 `
  -Contexts 8192,16384 `
  -Models qwen3-coder-30b-q4 `
  -Tasks js-window,browser-style
```

Run Pi at 16k:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-jinja-q4-toolcall-workflow.ps1 `
  -ContextSize 16384 `
  -Tasks file-create,js-edit,browser-style
```

Run the Pi 16k challenge suite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-challenge-suite.ps1 `
  -ContextSize 16384 `
  -Tasks single-function,multi-file,canary-preserve,browser-form,failing-command-recovery
```

Run Docker-controlled at 16k:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-docker-controlled-q4-workflow.ps1 `
  -ContextSize 16384 `
  -Tasks js-window,browser-style
```

Run OpenCode thin-prompt at 16k:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-16k-opencode-wsl-workflow.ps1 `
  -ContextSize 16384 `
  -Tasks js-window,browser-style `
  -TimeoutMinutes 8 `
  -OutputLimit 2048
```

Run Windows LM Studio controlled 16k comparison:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-windows-lmstudio-16k-controlled.ps1 `
  -ContextSize 16384 `
  -Tasks js-window,browser-style
```

Observed on 2026-06-22: `16k` is realistic for the controlled WSL ROCm Qwen3 Coder Q4 lane, Pi Jinja tool-call workflow, Pi five-task challenge suite, Docker-controlled runner, OpenCode thin-prompt two-task run, and Windows LM Studio controlled run. Windows LM Studio was faster on controlled first-content timings; WSL ROCm remains the proven Pi/Jinja tool-call endpoint. Qwen2.5 Coder 1.5B Q4/Q8 were fast but failed controlled verifier-backed tasks.

## Docker/Pi Runner Shape

Docker Desktop is now installed and WSL-enabled on this machine. Validate runtime state with:

```powershell
docker version
wsl.exe -d Ubuntu-24.04 -- bash -lc "docker version && docker compose version"
```

Build and probe the base Pi container:

```powershell
.\benchmarks\pi-docker-agent-runner\scripts\run-pi-docker.ps1 `
  -Workspace .\benchmarks\pi-docker-agent-runner\fixtures\help-probe `
  -BaseUrl http://host.docker.internal:8080/v1 `
  -Model qwen/qwen3-coder-30b-q4 `
  -Build `
  --help
```

Build and probe the browser-capable container:

```powershell
.\benchmarks\pi-docker-agent-runner\scripts\run-pi-docker.ps1 `
  -Workspace .\benchmarks\pi-docker-agent-runner\fixtures\help-probe `
  -BaseUrl http://host.docker.internal:8080/v1 `
  -Model qwen/qwen3-coder-30b-q4 `
  -Browser `
  -Build `
  --help
```

For a real Pi tool-call validation, start the WSL llama.cpp endpoint with Qwen3 Coder Q4 and `LLAMA_JINJA=1`, then run the Pi workflow wrapper:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/locallm_ryzen395-public/benchmarks/wsl-local-inference-benchmark && MODEL_PATH=/mnt/c/Users/<you>/.lmstudio/models/lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-GGUF/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf MODEL_ALIAS=qwen/qwen3-coder-30b-q4 PORT=8091 CTX_SIZE=8192 PARALLEL=1 LLAMA_JINJA=1 bash scripts/start-wsl-llama-server-amd.sh"
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-jinja-q4-toolcall-workflow.ps1 `
  -UseExistingServer `
  -Tasks file-create,js-edit,browser-style
```

To let the wrapper start and stop the server itself, omit `-UseExistingServer`. Phase 16 shows this path passes raw non-stream and stream endpoint tool-call probes, Pi file creation, Pi JS edit, and Pi browser-style verification.

## Docker-Controlled Benchmark Shape

Use this when the benchmark runner itself should execute inside Docker while the model server remains WSL ROCm llama.cpp:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-docker-controlled-q4-workflow.ps1 `
  -Build
```

The wrapper builds `local/controlled-edit-agent:node24` if needed, starts Qwen3 Coder Q4 through the WSL ROCm launcher, runs `js-window` and protected `browser-style` from inside Docker, captures JSON/stdout/stderr under `results/`, and stops the WSL server.

## OpenCode Calibration Shape

Only after runtime smoke passes:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\run-opencode-wsl-compatible-benchmark.ps1 `
  -BaseUrl http://127.0.0.1:8080 `
  -Model qwen/qwen3-coder-30b `
  -Tasks js-window `
  -ContextLimit 8192 `
  -OutputLimit 512 `
  -PromptSourceMode thin `
  -PromptPaddingMode none `
  -TimeoutMinutes 8
```

Observed on `2026-06-21`: `4096` context is too small for OpenCode because later turns exceeded the server slot. `8192` context allowed the model to edit `src/windowCounter.mjs` correctly and pass `node tools/test.mjs`, but OpenCode kept looping and had to be stopped. Do not promote the profile to the fuller suite until the runner captures partial stdout/stderr on timeout and the model/tool loop is bounded.

To validate config generation without contacting a model endpoint:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\run-opencode-wsl-compatible-benchmark.ps1 `
  -BaseUrl http://127.0.0.1:8080 `
  -Model qwen/qwen3-coder-30b `
  -Tasks js-window `
  -ContextLimit 16384 `
  -DryRun
```

This runner:

- uses the existing disposable OpenCode fixture workspace,
- writes WSL result artifacts under `benchmarks/wsl-local-inference-benchmark`,
- does not load or restore LM Studio profiles,
- keeps OpenCode config/data/cache/temp isolated under the WSL benchmark root,
- denies external directories, web search, user questions, package installs, destructive shell patterns, git commit, and git push,
- records proxy timings, OpenCode steps/tool calls, grades, manifests, and canary checks.

## Gemma 4 E4B Windows LM Studio Shape

The requested Gemma 4 12B model was not installed during Phase 23. The local Gemma candidate is `google/gemma-4-e4b`.

WSL ROCm gate for the installed Gemma model:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-wsl-model-matrix.ps1 `
  -Models gemma-4-e4b-q4 `
  -ContextSize 16384 `
  -AgentTasks js-window,browser-style `
  -Port 8110
```

Observed on 2026-06-22: this fails in AMD llama.cpp build `8407` with `unknown model architecture: 'gemma4'`. Treat that as a WSL runtime support limit, not a model-quality result.

Windows LM Studio controlled ladder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-windows-lmstudio-controlled-context-ladder.ps1 `
  -Model google/gemma-4-e4b `
  -Contexts 16384,32768,49152,65536 `
  -Tasks js-window,browser-style `
  -StopOnFailure
```

The same wrapper can test the advertised maximum context:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-windows-lmstudio-controlled-context-ladder.ps1 `
  -Model google/gemma-4-e4b `
  -Contexts 131072 `
  -Tasks js-window,browser-style `
  -StopOnFailure
```

Observed on 2026-06-22: `65k` passed both controlled tasks; `131k` loaded and passed `js-window` but failed protected `browser-style` under the 2-attempt gate.

OpenCode 65k filled-prompt probe:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\opencode-agent-benchmark\scripts\run-opencode-benchmark.ps1 `
  -Profiles gemma-65k `
  -Tasks js-window,browser-style `
  -TimeoutMinutes 25 `
  -PromptSourceMode thin `
  -PromptPaddingMode neutral
```

Observed on 2026-06-22: `browser-style` passed with a roughly `51k` token neutral-padded prompt, while `js-window` stopped without tool calls and failed.

Raw LM Studio tool-call probe:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\opencode-agent-benchmark\scripts\load-lmstudio-profile.ps1 `
  -Profile gemma-16k

node .\benchmarks\wsl-local-inference-benchmark\scripts\probe-openai-tool-calls.mjs `
  --base-url http://127.0.0.1:1234/v1 `
  --model google/gemma-4-e4b `
  --output .\benchmarks\wsl-local-inference-benchmark\results\gemma-toolcall-nonstream.json

node .\benchmarks\wsl-local-inference-benchmark\scripts\probe-openai-tool-calls.mjs `
  --base-url http://127.0.0.1:1234/v1 `
  --model google/gemma-4-e4b `
  --stream `
  --output .\benchmarks\wsl-local-inference-benchmark\results\gemma-toolcall-stream.json
```

Restore LM Studio after probes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\opencode-agent-benchmark\scripts\load-lmstudio-profile.ps1 `
  -Profile restore-initial `
  -InitialStateJson <captured-initial-lms-state.json>
```

## Promotion Rules

Promote a WSL profile to fuller OpenCode suite only if:

- server smoke succeeds,
- first byte and first content are measurable,
- decode estimate is near or above `30 tok/s`,
- `js-window` passes,
- no severe OpenCode shell/tool loop occurs,
- canary remains unchanged,
- modified files stay inside the disposable fixture.

Reject or quarantine a profile if:

- it needs more than 5 minutes TTFT on the first practical agent request,
- it crashes the server or WSL VM,
- it requires broad host permission changes,
- it is slower than the Windows Vulkan baseline and does not expose a unique feature worth keeping.
