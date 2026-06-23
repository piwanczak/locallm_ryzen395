# WSL2 Local Inference Benchmark

This benchmark lane compares WSL2 local-inference hosts against the Windows results already recorded in this journal project.

The Windows baseline remains authoritative in:

- `reports/2026-06-19_optimization-summary-11-b9728-hip-rocm-retest.md`
- `reports/2026-06-19_optimization-summary-12-vulkan-223-experts.md`
- `reports/2026-06-20_optimization-summary-28-long-context-final-report.md`
- `reports/2026-06-20_optimization-summary-29-opencode-agent-benchmark-final.md`
- `reports/2026-06-20_optimization-summary-30-opencode-ttft-practical-profile.md`
- `reports/2026-06-20_optimization-summary-31-opencode-thin-prompt-ttft-sweep.md`

New WSL2 outputs should stay under this directory:

- `results/` for JSON and Markdown run records.
- `logs/` for command output and server logs.
- `scripts/` for no-install preflight and calibration helpers.

Setup and run sequencing is in:

- `setup-runbook.md`

Phase reports are kept as Markdown source plus rendered HTML:

- `reports/phase-00-preflight.md` / `reports/phase-00-preflight.html`
- `reports/phase-01-wsl-rocm-runtime.md` / `reports/phase-01-wsl-rocm-runtime.html`
- `reports/phase-02-agent-benchmarks.md` / `reports/phase-02-agent-benchmarks.html`
- `reports/phase-03-recommendation.md` / `reports/phase-03-recommendation.html`
- `reports/phase-04-browser-verification.md` / `reports/phase-04-browser-verification.html`
- `reports/phase-05-research-candidates.md` / `reports/phase-05-research-candidates.html`
- `reports/phase-06-docker-pi-runner.md` / `reports/phase-06-docker-pi-runner.html`
- `reports/phase-07-rankings-failure-modes.md` / `reports/phase-07-rankings-failure-modes.html`
- `reports/phase-08-multi-model-matrix.md` / `reports/phase-08-multi-model-matrix.html`
- `reports/phase-09-completion-audit.md` / `reports/phase-09-completion-audit.html`
- `reports/phase-10-pi-docker-dry-run.md` / `reports/phase-10-pi-docker-dry-run.html`
- `reports/phase-11-docker-pi-validation.md` / `reports/phase-11-docker-pi-validation.html`
- `reports/phase-12-recommended-q4-workflow.md` / `reports/phase-12-recommended-q4-workflow.html`
- `reports/phase-13-docker-controlled-agent.md` / `reports/phase-13-docker-controlled-agent.html`
- `reports/phase-14-memory-cap-32gb.md` / `reports/phase-14-memory-cap-32gb.html`
- `reports/phase-15-pi-tool-call-compatibility.md` / `reports/phase-15-pi-tool-call-compatibility.html`
- `reports/phase-16-pi-jinja-toolcall-recovery.md` / `reports/phase-16-pi-jinja-toolcall-recovery.html`
- `reports/phase-17-pi-soak-challenge-dashboard.md` / `reports/phase-17-pi-soak-challenge-dashboard.html`
- `reports/phase-18-pi-memory-cap-sweep.md` / `reports/phase-18-pi-memory-cap-sweep.html`
- `reports/phase-19-pi-10-run-soak.md` / `reports/phase-19-pi-10-run-soak.html`
- `reports/phase-20-runner-endpoint-final-recommendation.md` / `reports/phase-20-runner-endpoint-final-recommendation.html`
- `reports/phase-21-16k-controlled-pi-context.md` / `reports/phase-21-16k-controlled-pi-context.html`
- `reports/phase-22-16k-opencode-windows-models.md` / `reports/phase-22-16k-opencode-windows-models.html`
- `reports/phase-23-gemma4-e4b-context-comparison.md` / `reports/phase-23-gemma4-e4b-context-comparison.html`
- `reports/phase-24-gemma4-12b-context-comparison.md` / `reports/phase-24-gemma4-12b-context-comparison.html`
- `reports/phase-25-gemma4-12b-follow-up-validation.md` / `reports/phase-25-gemma4-12b-follow-up-validation.html`
- `reports/local-inference-dashboard.md` / `reports/local-inference-dashboard.html`

## Current Finding

As of `2026-06-21 22:02 Europe/Warsaw`, Ubuntu 24.04 is installed as a WSL2 distro, ROCm/ROCDXG works, and AMD's validated ROCm llama.cpp binary can serve the local Qwen3 Coder GGUF through an OpenAI-compatible endpoint.

Current status:

- WSL default distro: `Ubuntu-24.04`, version `2`
- WSL memory: about `60 GiB` RAM plus `16 GiB` swap visible to Linux
- ROCm GPU pool reported by HIP smoke: `70491842560` bytes for `AMD Radeon(TM) 8060S Graphics`
- `/dev/dxg`: present
- ROCm/ROCDXG: installed and HIP kernel smoke passed
- ROCm agent: `gfx1151`
- Vulkan: installed, but currently reports only Mesa `llvmpipe` CPU, not the AMD GPU
- llama.cpp ROCm runtime: installed under `runtimes/amd-llamacpp-rocm/current`
- OpenAI-compatible smoke: passed for Qwen3 Coder 30B Q2
- OpenCode `js-window`: code fix passed at `8192` context, but the OpenCode process did not terminate cleanly
- Controlled edit-agent `js-window`: passed with one allowlisted replacement and verifier execution
- Controlled edit-agent `browser-style`: passed after adding a protected invariant for the known-good `element.hidden` empty-state line
- Browser verification: passed for the protected `browser-style` fixture using the in-app browser and local static server
- Multi-model matrix: Qwen3 Coder 30B Q4 passed `js-window` and protected `browser-style` with browser verification; Q4 4-way calibration reached `96.27 tok/s`; Qwen2.5-Coder 1.5B Q4/Q8 were fast but failed `js-window`; Gemma E4B Q4 did not load in this AMD llama.cpp build because the model architecture was `gemma4`
- Docker Desktop: installed and WSL-enabled; Windows and WSL Docker Engine `29.5.3`, Compose `v5.1.4`
- Pi Docker runner: base image and browser image build and run `pi --help`; model config mounts after BOM-free JSON fix; with llama.cpp `--jinja` and the local Qwen tool-call format reminder, Pi executes real `toolCall`/`toolResult` events against the WSL ROCm Q4 endpoint; 10-run Pi soak passed `10/10` full iterations across file-create, JS edit, and browser-style tasks
- Recommended Q4 workflow: `scripts/run-recommended-q4-workflow.ps1` completed; single calibration `60.28 tok/s`, `js-window` passed, protected `browser-style` passed, 4-way aggregate `91.97 tok/s`
- Docker-controlled Q4 workflow: `scripts/run-docker-controlled-q4-workflow.ps1 -Build` completed; `js-window` and protected `browser-style` passed inside Docker with Linux verifier commands
- WSL memory cap: current host/WSL Q4 workflow passed at `32GB`; Pi Docker file/edit/browser workflow also passed at `DEFAULT`, `48GB`, and `32GB`; `65GB` is not required for these measured short-context workflows
- Runner comparison: Pi Docker, Docker-controlled, and host-controlled runners all passed the Phase 20 comparison; controlled runners remain simpler for default benchmarking while Pi remains useful for Dockerized agentic tool-call validation
- Endpoint comparison: Qwen3 Coder 30B Q4 at 8k, Q4 at 4k, and Q2 at 8k all passed the Pi file/edit/browser workflow; Q4 at 8k remains the promoted endpoint because it has the strongest accumulated reliability evidence
- 16k context: Qwen3 Coder 30B Q4 passed controlled WSL ROCm `8192` vs `16384` comparison, Pi Jinja file/edit/browser, Pi five-task challenge suite, Docker-controlled, and OpenCode thin-prompt `js-window` plus `browser-style`; Windows LM Studio also passed the controlled `16k` comparison and was faster on first-content timings
- Smaller-model 16k check: Qwen2.5 Coder 1.5B Q4/Q8 were very fast but failed both controlled verifier-backed tasks; do not promote them as coding-agent defaults
- Gemma 4 E4B check: the earlier fallback `google/gemma-4-e4b` passed Windows LM Studio controlled tasks through `65k`, loaded at `131k` but failed protected `browser-style`, failed WSL ROCm load because AMD llama.cpp build `8407` does not recognize `gemma4`, passed LM Studio raw tool-call probes, and passed a simple Pi file-create task through LM Studio. This lane is superseded by the actual 12B check.
- Gemma 4 12B check: `google/gemma-4-12b` is installed. WSL ROCm still fails to load `gemma4` on AMD llama.cpp build `8407`, but Windows LM Studio passes controlled verifier-backed `js-window` and protected `browser-style` through the advertised `262k` context when requests include `reasoning_effort=none`. A three-run controlled reliability sweep passed `18/18` task cells across `16k`, `65k`, and `262k`. OpenCode passed a real neutral-padded `65k` lane for `js-window` and `browser-style`, but each task took about 11.7 minutes. Raw LM Studio tool calls passed. Pi through LM Studio now passes file-create, JS edit, and protected browser-style. Keep Qwen3 Coder 30B Q4 as default; use Gemma 4 12B as an experimental Windows LM Studio high-context lane.

Memory caveat: with no `.wslconfig`, WSL reports about `60 GiB` inside Linux on this machine. Guarded `32GB` cap sweeps passed the current Qwen3 Coder 30B Q4 short-context controlled workflow and Pi file/edit/browser workflow, so `65GB` is not required for those measured lanes. The `16k` runs were not repeated under `32GB`; long-context, larger frontend, simultaneous-agent, and long-soak-at-32GB runs still need separate cap-specific evidence.

Key result artifacts:

- `results/20260621-212450-calibration-qwen3-coder-30b-q2-wsl-rocm-single.json`
- `results/20260621-212503-calibration-qwen3-coder-30b-q2-wsl-rocm-4way.json`
- `results/20260621-214423-opencode/js-window-grade.json`
- `notes/2026-06-21_22-02-00_wsl-rocm-llamacpp-opencode-smoke.md`

## Comparison Targets

Use the same model families and benchmark shapes whenever possible:

| Area | Windows Baseline | WSL2 Target |
| --- | --- | --- |
| Short runtime throughput | LM Studio Vulkan `2.22.0`, Qwen Q4_K_M, 4 experts, 8k context | llama.cpp/llama-server Vulkan and ROCm/HIP where available |
| ROCm comparison | LM Studio ROCm beta `2.23.0`: `51.73 tok/s` single, `109.64 tok/s` 4-way aggregate | Native Linux ROCm/HIP if WSL exposes a supported GPU stack |
| Vulkan comparison | Best Windows path stayed Vulkan `2.22.0`; earlier restored checks reached `69.62 tok/s` single and `130.18 tok/s` 4-way aggregate; later throughput profile recorded `167.62 tok/s` aggregate | Native Linux Vulkan if WSL exposes `/dev/dxg` plus a working Vulkan ICD |
| Long context | Windows LM Studio Vulkan: 32k practical, 65k+ too slow for agent use | Direct llama.cpp KV/cache flags if WSL runtime supports them |
| OpenCode agent | Windows thin prompt: Qwen 16k `12.6 s` first TTFT but poor tool behavior; Gemma 16k `15.6 s` first byte with clean tool use | Same `js-window` calibration first, fuller suite only after runtime gates pass |

## Gates

Candidate WSL profiles should be promoted only if they meet these gates:

- Runtime smoke test reaches first content without server errors or GPU resets.
- `js-window` OpenCode calibration is attempted for every viable candidate.
- Preferred first long-context TTFT is under 2 minutes.
- Hard fail is above 5 minutes unless correctness is exceptional and no better profile exists.
- Decode target remains `>= 30 tok/s` where measurable.
- Fuller OpenCode suite runs only after the runtime and calibration gates pass.
- Canary and manifest checks stay unchanged outside the disposable fixture workspace.

## Suggested Order

1. Run `scripts/collect-host-preflight.ps1` from Windows.
2. Install or select a WSL2 distro only after approval.
3. Run `scripts/wsl-preflight.sh` inside the distro.
4. Start one WSL OpenAI-compatible server at a time on a known port.
5. Run `scripts/run-openai-compatible-calibration.mjs` against that port.
6. If it passes, wire the OpenCode benchmark timing proxy to the WSL server and run `js-window`.
7. Promote only passing candidates to the fuller suite.

The WSL/OpenAI-compatible OpenCode runner is:

```powershell
.\scripts\run-opencode-wsl-compatible-benchmark.ps1 -BaseUrl http://127.0.0.1:8080 -Model qwen/qwen3-coder-30b -Tasks js-window
```

The current recommended local edit workflow is the controlled runner:

```powershell
node .\scripts\run-controlled-edit-agent.mjs `
  --base-url http://127.0.0.1:8080/v1 `
  --model qwen/qwen3-coder-30b `
  --task js-window `
  --max-attempts 2
```

The one-command recommended Q4 workflow wrapper is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-recommended-q4-workflow.ps1
```

The Docker/Pi runner can be built and probed with:

```powershell
.\benchmarks\pi-docker-agent-runner\scripts\run-pi-docker.ps1 `
  -Workspace .\benchmarks\pi-docker-agent-runner\fixtures\help-probe `
  -BaseUrl http://host.docker.internal:8080/v1 `
  -Model qwen/qwen3-coder-30b-q4 `
  -Build `
  --help
```

The current Pi validation workflow is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-pi-jinja-q4-toolcall-workflow.ps1 `
  -UseExistingServer `
  -Tasks file-create,js-edit,browser-style
```

Phase 16 supersedes the Phase 15 caveat for the tested small tasks: the endpoint must run with `--jinja`, and Pi still needs the appended local Qwen tool-call format reminder.

The Docker-controlled benchmark runner can be run with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-docker-controlled-q4-workflow.ps1 `
  -Build
```

This is currently the proven Docker path for local edit and protected frontend benchmark tasks.

Render Markdown phase reports to HTML with:

```powershell
node .\scripts\render-markdown-reports.mjs
```

For the current ROCm launcher, start and stop from Windows with:

```powershell
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/'LocalInference - dzienniczek' && PORT=8080 CTX_SIZE=8192 PARALLEL=1 bash benchmarks/wsl-local-inference-benchmark/scripts/start-wsl-llama-server-amd.sh"
wsl.exe --distribution Ubuntu-24.04 --user root -- bash -lc "cd /mnt/c/Users/<you>/Documents/'LocalInference - dzienniczek' && bash benchmarks/wsl-local-inference-benchmark/scripts/stop-wsl-llama-server-amd.sh"
```
