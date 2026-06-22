# Local Inference Dashboard

Generated: 2026-06-22T13:27:11.293Z

## Abridged Project State

Current promoted local coding stack: Qwen3 Coder 30B Q4 is viable at 16k for controlled WSL ROCm work, Pi Docker tool-call validation, Docker-controlled tasks, OpenCode thin-prompt tasks, and Windows LM Studio controlled tasks. Gemma 4 E4B is an experimental Windows LM Studio high-context lane through 65k, not a replacement for the Qwen default.

Updated through: 2026-06-22

## Current Recommendation

| Layer | Recommendation | Links |
| --- | --- | --- |
| Endpoint | WSL ROCm llama.cpp with Qwen3 Coder 30B Q4, CTX_SIZE=16384 when context is useful, PARALLEL=1, LLAMA_JINJA=1 for Pi/tool-call work. Keep 8k as the lower-overhead baseline. Use Windows LM Studio Gemma 4 E4B only for experimental 65k high-context checks or LM Studio tool-call probes. | [Phase 21 16k controlled/Pi](phase-21-16k-controlled-pi-context.md), [Phase 22 16k OpenCode/Windows](phase-22-16k-opencode-windows-models.md), [Phase 23 Gemma E4B](phase-23-gemma4-e4b-context-comparison.md), [Phase 20 final recommendation](phase-20-runner-endpoint-final-recommendation.md), [Phase 16 Pi recovery](phase-16-pi-jinja-toolcall-recovery.md) |
| Runner | Use the host/WSL controlled runner as the default benchmark harness; use Docker-controlled for Linux isolation; use Pi when validating Dockerized agentic tool execution; use OpenCode for slower full-agent realism checks. | [Phase 03 recommendation](phase-03-recommendation.md), [Runner comparison summary](../results/20260622-121739-runner-comparison/runner-comparison-summary.json) |
| Memory | 32GB WSL RAM is sufficient for the measured short-context host/WSL and Pi file/edit/browser workflows; 48GB is the practical headroom setting. The 16k runs were not repeated under 32GB yet. | [Pi memory sweep](phase-18-pi-memory-cap-sweep.md), [32GB controlled sweep](phase-14-memory-cap-32gb.md) |

## Experiment Milestones

| Area | What Was Learned | Links |
| --- | --- | --- |
| Windows LM Studio tuning | The Windows path established a fast Qwen3 Coder throughput profile and a separate practical 32k long-context profile. Very large contexts can load, but interactive use breaks down from prompt prefill latency. | [Vulkan 2.23 experts](../../../reports/2026-06-19_optimization-summary-12-vulkan-223-experts.md), [Long-context final](../../../reports/2026-06-20_optimization-summary-28-long-context-final-report.md) |
| Long context limit | 32k is the practical local long-context target. 65k is occasional and slow. 128k+ and 196k+ are not interactive on this hardware; 196k took about 80.5 minutes before generation and decoded at 9.71 tok/s. | [Long-context ladder](../../../reports/2026-06-20_optimization-summary-28-long-context-final-report.md) |
| OpenCode behavior | Thin source-on-demand prompts were the major TTFT win: Qwen 16k thin/no-padding reached about 12.6s first TTFT on calibration. Autonomous reliability stayed mixed, so OpenCode was not promoted as the main local daily driver. | [OpenCode final](../../../reports/2026-06-20_optimization-summary-29-opencode-agent-benchmark-final.md), [OpenCode TTFT profile](../../../reports/2026-06-20_optimization-summary-30-opencode-ttft-practical-profile.md), [Thin prompt sweep](../../../reports/2026-06-20_optimization-summary-31-opencode-thin-prompt-ttft-sweep.md) |
| WSL2 ROCm runtime | Ubuntu 24.04 WSL2 plus AMD ROCDXG/ROCm and AMD's validated llama.cpp binary became the winning Linux path. ROCm works; WSL Vulkan currently reports llvmpipe CPU rather than the AMD GPU. | [WSL ROCm runtime](phase-01-wsl-rocm-runtime.md), [WSL runbook](../setup-runbook.md), [WSL setup report](../../../reports/2026-06-21_optimization-summary-33-wsl-opencode-runner-and-setup-runbook.md) |
| Controlled coding benchmarks | Qwen3 Coder 30B Q4 passed controlled JS edit and protected browser-style frontend tasks with browser verification. Docker-controlled also passed, making it the preferred Linux-container measurement lane. | [Phase 03 recommendation](phase-03-recommendation.md), [Docker-controlled agent](phase-13-docker-controlled-agent.md) |
| Pi tool calling | The Pi failure was endpoint format, not basic Docker reachability. llama.cpp needed --jinja for structured OpenAI tool calls, and Pi needed the local Qwen tool-call reminder. With both, Pi executed real toolCall/toolResult events. | [Tool-call compatibility](phase-15-pi-tool-call-compatibility.md), [Pi Jinja recovery](phase-16-pi-jinja-toolcall-recovery.md) |
| Pi reliability | Pi passed a 10-run file/edit/browser soak, a five-task challenge suite, DEFAULT/48GB/32GB memory caps, runner comparison, and Q4/Q2 endpoint comparison. It is viable for small local tasks, but operationally heavier than controlled runners. | [Challenge suite and dashboard](phase-17-pi-soak-challenge-dashboard.md), [10-run soak](phase-19-pi-10-run-soak.md), [Final recommendation](phase-20-runner-endpoint-final-recommendation.md) |
| 16k context reality check | 16k is realistic for this project. Qwen3 Coder 30B Q4 passed controlled WSL 8k vs 16k comparison, Pi Jinja file/edit/browser, Pi five-task challenge suite, Docker-controlled, OpenCode thin-prompt js-window and browser-style, and Windows LM Studio controlled tasks. Windows LM Studio was faster on controlled first-content timings; OpenCode passed but remained slow and tool-heavy. | [Phase 21 16k controlled/Pi](phase-21-16k-controlled-pi-context.md), [Phase 22 16k OpenCode/Windows](phase-22-16k-opencode-windows-models.md), [16k WSL controlled summary](../results/20260622-133115-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json), [16k OpenCode summary](../results/20260622-140434-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json), [Windows LM Studio 16k summary](../results/20260622-142238-windows-lmstudio-16k-controlled/windows-lmstudio-16k-controlled-summary.json) |
| Gemma E4B context check | True Gemma 4 12B was not installed. The installed Gemma 4 E4B passed Windows LM Studio controlled tasks through 65k, loaded at 131k but failed protected browser-style, failed WSL ROCm load because AMD llama.cpp build 8407 does not recognize gemma4, passed raw LM Studio tool-call probes, and passed a simple Pi file-create task through LM Studio. It remains experimental. | [Phase 23 Gemma E4B](phase-23-gemma4-e4b-context-comparison.md), [65k controlled summary](../results/20260622-145556-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json), [65k OpenCode summary](../results/20260622-150244-gemma-65k-opencode-lmstudio/gemma-65k-opencode-lmstudio-summary.json), [Pi through LM Studio summary](../results/20260622-152232-gemma-lmstudio-pi-file-create/gemma-lmstudio-pi-file-create-summary.json) |

## Canonical Artifacts

- [Promoted Pi workflow](../results/20260622-102758-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json)
- [Pi challenge suite](../results/20260622-110232-pi-challenge-suite/pi-challenge-suite-summary.json)
- [Pi memory sweep](../results/20260622-111737-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json)
- [Pi 10-run soak](../results/20260622-113256-pi-reliability-soak/pi-reliability-soak-summary.json)
- [Runner comparison](../results/20260622-121739-runner-comparison/runner-comparison-summary.json)
- [Endpoint comparison](../results/20260622-120346-pi-endpoint-comparison/pi-endpoint-comparison-summary.json)
- [16k controlled WSL comparison](../results/20260622-133115-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json)
- [16k Pi challenge suite](../results/20260622-134255-pi-challenge-suite/pi-challenge-suite-summary.json)
- [16k OpenCode workflow](../results/20260622-140434-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json)
- [16k Windows LM Studio controlled](../results/20260622-142238-windows-lmstudio-16k-controlled/windows-lmstudio-16k-controlled-summary.json)
- [Gemma E4B 65k controlled](../results/20260622-145556-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json)
- [Gemma E4B 65k OpenCode](../results/20260622-150244-gemma-65k-opencode-lmstudio/gemma-65k-opencode-lmstudio-summary.json)
- [Gemma E4B LM Studio Pi file-create](../results/20260622-152232-gemma-lmstudio-pi-file-create/gemma-lmstudio-pi-file-create-summary.json)

## Remaining Limits

- Gemma 4 12B is not installed locally; Phase 23 tested Gemma 4 E4B only.
- Gemma E4B 65k OpenCode is mixed: browser-style passed, but js-window stopped without tool calls.
- Gemma E4B 131k loads in Windows LM Studio, but protected browser-style failed under the controlled 2-attempt gate.
- Gemma E4B cannot currently use the promoted WSL ROCm llama.cpp lane because the AMD build does not recognize gemma4.
- Large frontend applications and larger multi-file product work remain untested under Pi and OpenCode.
- The 16k lanes have not been repeated as a 10-run reliability soak.
- The 16k lanes have not been repeated under the 32GB WSL memory cap.
- LM Studio and Ollama were not re-promoted for executable tool-call work because the WSL ROCm llama.cpp Jinja endpoint already passed that gate.
- OpenCode passed two 16k tasks, but browser-style took over six minutes and 20 steps; it is not the fast default harness.
- Qwen2.5 Coder 1.5B Q4/Q8 are fast but failed verifier-backed controlled tasks.

## Raw Result Index

| Kind | Result | Status | Model | Tasks | Summary |
| --- | --- | --- | --- | --- | --- |
| summary | results | unknown |  |  | ../results/pi-docker-dry-run-summary.json |
| summary | results | unknown |  |  | ../results/summary-rankings.json |
| pi-lmstudio | 20260622-152232-gemma-lmstudio-pi-file-create | unknown |  |  | ../results/20260622-152232-gemma-lmstudio-pi-file-create/gemma-lmstudio-pi-file-create-summary.json |
| toolcall-probe | 20260622-151739-gemma-lmstudio-toolcall-probe | unknown |  |  | ../results/20260622-151739-gemma-lmstudio-toolcall-probe/gemma-lmstudio-toolcall-probe-summary.json |
| opencode-gemma | 20260622-150244-gemma-65k-opencode-lmstudio | unknown |  |  | ../results/20260622-150244-gemma-65k-opencode-lmstudio/gemma-65k-opencode-lmstudio-summary.json |
| model-matrix | 20260622-145214-model-matrix | unknown |  |  | ../results/20260622-145214-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-141906-model-matrix | unknown |  |  | ../results/20260622-141906-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-141609-model-matrix | unknown |  |  | ../results/20260622-141609-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-133426-model-matrix | unknown |  |  | ../results/20260622-133426-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-133115-model-matrix | unknown |  |  | ../results/20260622-133115-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-122449-model-matrix | unknown |  |  | ../results/20260622-122449-model-matrix/model-matrix-summary.json |
| recommended-q4 | 20260622-122448-recommended-q4-workflow | unknown |  |  | ../results/20260622-122448-recommended-q4-workflow/recommended-q4-workflow-summary.json |
| model-matrix | 20260622-115630-model-matrix | unknown |  |  | ../results/20260622-115630-model-matrix/model-matrix-summary.json |
| recommended-q4 | 20260622-115629-recommended-q4-workflow | unknown |  |  | ../results/20260622-115629-recommended-q4-workflow/recommended-q4-workflow-summary.json |
| summary | 20260622-075144-pi-docker-q4-jinja-toolcall-edit-print | unknown |  |  | ../results/20260622-075144-pi-docker-q4-jinja-toolcall-edit-print/pi-docker-q4-jinja-toolcall-edit-summary.json |
| summary | 20260622-074929-pi-docker-q4-jinja-toolcall-edit | unknown |  |  | ../results/20260622-074929-pi-docker-q4-jinja-toolcall-edit/pi-docker-q4-jinja-toolcall-edit-summary.json |
| summary | 20260622-022600-pi-tool-call-compatibility | unknown |  |  | ../results/20260622-022600-pi-tool-call-compatibility/pi-tool-call-compatibility-summary.json |
| model-matrix | 20260622-001426-model-matrix | unknown |  |  | ../results/20260622-001426-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-001204-model-matrix | unknown |  |  | ../results/20260622-001204-model-matrix/model-matrix-summary.json |
| memory-cap | 20260622-001155-memory-cap-sweep | unknown |  |  | ../results/20260622-001155-memory-cap-sweep/memory-cap-sweep-summary.json |
| model-matrix | 20260622-000817-model-matrix | unknown |  |  | ../results/20260622-000817-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-000540-model-matrix | unknown |  |  | ../results/20260622-000540-model-matrix/model-matrix-summary.json |
| memory-cap | 20260622-000529-memory-cap-sweep | unknown |  |  | ../results/20260622-000529-memory-cap-sweep/memory-cap-sweep-summary.json |
| model-matrix | 20260621-234713-model-matrix | unknown |  |  | ../results/20260621-234713-model-matrix/model-matrix-summary.json |
| recommended-q4 | 20260621-234449-recommended-q4-workflow | unknown |  |  | ../results/20260621-234449-recommended-q4-workflow/recommended-q4-workflow-summary.json |
| model-matrix | 20260621-234449-model-matrix | unknown |  |  | ../results/20260621-234449-model-matrix/model-matrix-summary.json |
| summary | 20260621-234235-pi-docker-browser-validation | unknown |  |  | ../results/20260621-234235-pi-docker-browser-validation/pi-docker-browser-validation-summary.json |
| summary | 20260621-233951-pi-docker-q4-agent-edit-compat | unknown |  |  | ../results/20260621-233951-pi-docker-q4-agent-edit-compat/pi-docker-q4-agent-edit-summary.json |
| summary | 20260621-233541-pi-docker-q4-agent-edit | unknown |  |  | ../results/20260621-233541-pi-docker-q4-agent-edit/pi-docker-q4-agent-edit-summary.json |
| summary | 20260621-232722-pi-docker-model-config-validation | unknown |  |  | ../results/20260621-232722-pi-docker-model-config-validation/pi-docker-model-config-summary.json |
| summary | 20260621-232653-pi-docker-model-config-validation | unknown |  |  | ../results/20260621-232653-pi-docker-model-config-validation/pi-docker-model-config-summary.json |
| summary | 20260621-232549-pi-docker-base-validation | unknown |  |  | ../results/20260621-232549-pi-docker-base-validation/pi-docker-base-validation-summary.json |
| recommended-q4 | 20260621-231223-recommended-q4-workflow | unknown |  |  | ../results/20260621-231223-recommended-q4-workflow/recommended-q4-workflow-summary.json |
| recommended-q4 | 20260621-231111-recommended-q4-workflow | unknown |  |  | ../results/20260621-231111-recommended-q4-workflow/recommended-q4-workflow-summary.json |
| memory-cap | 20260621-230003-memory-cap-sweep | unknown |  |  | ../results/20260621-230003-memory-cap-sweep/memory-cap-sweep-summary.json |
| memory-cap | 20260621-225919-memory-cap-sweep | unknown |  |  | ../results/20260621-225919-memory-cap-sweep/memory-cap-sweep-summary.json |
| model-matrix | 20260621-225403-model-matrix | unknown |  |  | ../results/20260621-225403-model-matrix/model-matrix-summary.json |
| model-matrix | 20260621-224242-model-matrix | unknown |  |  | ../results/20260621-224242-model-matrix/model-matrix-summary.json |
| model-matrix | 20260621-224107-model-matrix | unknown |  |  | ../results/20260621-224107-model-matrix/model-matrix-summary.json |
| model-matrix | 20260621-223758-model-matrix | unknown |  |  | ../results/20260621-223758-model-matrix/model-matrix-summary.json |
| model-matrix | 20260621-223702-model-matrix | unknown |  |  | ../results/20260621-223702-model-matrix/model-matrix-summary.json |
| model-matrix | 20260621-223616-model-matrix | unknown |  |  | ../results/20260621-223616-model-matrix/model-matrix-summary.json |
| lmstudio-context-ladder | 20260622-145758-windows-lmstudio-controlled-context-ladder | fail | google/gemma-4-e4b | js-window, browser-style | ../results/20260622-145758-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| lmstudio-context-ladder | 20260622-145556-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-e4b | js-window, browser-style | ../results/20260622-145556-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| lmstudio-context-ladder | 20260622-145415-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-e4b | js-window, browser-style | ../results/20260622-145415-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| summary | 20260622-142238-windows-lmstudio-16k-controlled | pass | qwen/qwen3-coder-30b | js-window, browser-style | ../results/20260622-142238-windows-lmstudio-16k-controlled/windows-lmstudio-16k-controlled-summary.json |
| summary | 20260622-142227-windows-lmstudio-16k-controlled | fail | qwen/qwen3-coder-30b | js-window, browser-style | ../results/20260622-142227-windows-lmstudio-16k-controlled/windows-lmstudio-16k-controlled-summary.json |
| summary | 20260622-141906-16k-controlled-context-comparison | fail |  | js-window, browser-style | ../results/20260622-141906-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json |
| summary | 20260622-141854-16k-controlled-context-comparison | fail |  | js-window, browser-style | ../results/20260622-141854-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json |
| summary | 20260622-141608-16k-controlled-context-comparison | pass |  | js-window, browser-style | ../results/20260622-141608-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json |
| summary | 20260622-140434-16k-opencode-wsl-workflow | pass | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-140434-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json |
| summary | 20260622-140419-16k-opencode-wsl-workflow | fail | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-140419-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json |
| summary | 20260622-135835-16k-opencode-wsl-workflow | fail | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-135835-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json |
| summary | 20260622-135824-16k-opencode-wsl-workflow | fail | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-135824-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json |
| summary | 20260622-135455-16k-opencode-wsl-workflow | fail | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-135455-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json |
| summary | 20260622-135434-16k-opencode-wsl-workflow | fail | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-135434-16k-opencode-wsl-workflow/16k-opencode-wsl-workflow-summary.json |
| docker-controlled | 20260622-134859-docker-controlled-q4-workflow | pass | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-134859-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json |
| pi-challenge-suite | 20260622-134255-pi-challenge-suite | pass | qwen/qwen3-coder-30b-q4 | single-function:pass, multi-file:pass, canary-preserve:pass, browser-form:pass, failing-command-recovery:pass | ../results/20260622-134255-pi-challenge-suite/pi-challenge-suite-summary.json |
| pi-workflow | 20260622-133820-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-133820-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| summary | 20260622-133115-16k-controlled-context-comparison | pass |  | js-window, browser-style | ../results/20260622-133115-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json |
| summary | 20260622-133058-16k-controlled-context-comparison | fail |  | js-window, browser-style | ../results/20260622-133058-16k-controlled-context-comparison/16k-controlled-context-comparison-summary.json |
| docker-controlled | 20260622-122142-docker-controlled-q4-workflow | pass | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-122142-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json |
| pi-workflow | 20260622-121739-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-121739-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| runner-comparison | 20260622-121739-runner-comparison | pass | qwen/qwen3-coder-30b-q4 | pi-docker:pass, docker-controlled:pass, host-controlled:pass | ../results/20260622-121739-runner-comparison/runner-comparison-summary.json |
| pi-workflow | 20260622-121126-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q2 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-121126-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-120739-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-120739-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-120346-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-120346-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| endpoint-comparison | 20260622-120346-pi-endpoint-comparison | pass |  | file-create, js-edit, browser-style | ../results/20260622-120346-pi-endpoint-comparison/pi-endpoint-comparison-summary.json |
| endpoint-comparison | 20260622-120329-pi-endpoint-comparison | unknown |  | file-create, js-edit, browser-style | ../results/20260622-120329-pi-endpoint-comparison/pi-endpoint-comparison-summary.json |
| runner-comparison | 20260622-120054-runner-comparison | fail | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-120054-runner-comparison/runner-comparison-summary.json |
| docker-controlled | 20260622-115324-docker-controlled-q4-workflow | pass | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260622-115324-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json |
| pi-workflow | 20260622-114930-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-114930-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| runner-comparison | 20260622-114916-runner-comparison | fail | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-114916-runner-comparison/runner-comparison-summary.json |
| pi-workflow | 20260622-114404-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-114404-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-114313-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-114313-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-114217-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-114217-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-114114-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-114114-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-114011-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-114011-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-113919-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-113919-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-113829-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-113829-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-113741-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-113741-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-113652-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-113652-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-113546-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-113546-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-soak | 20260622-113256-pi-reliability-soak | pass | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-113256-pi-reliability-soak/pi-reliability-soak-summary.json |
| pi-workflow | 20260622-112516-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-112516-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-112130-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-112130-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-111746-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-111746-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| memory-cap | 20260622-111737-pi-memory-cap-sweep | pass | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-111737-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json |
| memory-cap | 20260622-111714-pi-memory-cap-sweep | fail | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-111714-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json |
| pi-workflow | 20260622-111125-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-111125-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| memory-cap | 20260622-111116-pi-memory-cap-sweep | fail | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-111116-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json |
| memory-cap | 20260622-111054-pi-memory-cap-sweep | fail | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-111054-pi-memory-cap-sweep/pi-memory-cap-sweep-summary.json |
| pi-challenge-suite | 20260622-110232-pi-challenge-suite | pass | qwen/qwen3-coder-30b-q4 | single-function:pass, multi-file:pass, canary-preserve:pass, browser-form:pass, failing-command-recovery:pass | ../results/20260622-110232-pi-challenge-suite/pi-challenge-suite-summary.json |
| pi-workflow | 20260622-110117-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-110117-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-110029-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-110029-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-soak | 20260622-110028-pi-reliability-soak | pass | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-110028-pi-reliability-soak/pi-reliability-soak-summary.json |
| pi-workflow | 20260622-105938-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass | ../results/20260622-105938-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-105930-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass | ../results/20260622-105930-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-soak | 20260622-105929-pi-reliability-soak | pass | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-105929-pi-reliability-soak/pi-reliability-soak-summary.json |
| pi-workflow | 20260622-105838-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass | ../results/20260622-105838-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-soak | 20260622-105522-pi-reliability-soak | fail | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-105522-pi-reliability-soak/pi-reliability-soak-summary.json |
| pi-challenge-suite | 20260622-105502-pi-challenge-suite | fail | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-105502-pi-challenge-suite/pi-challenge-suite-summary.json |
| pi-soak | 20260622-105115-pi-reliability-soak | fail | qwen/qwen3-coder-30b-q4 | file-create, js-edit, browser-style | ../results/20260622-105115-pi-reliability-soak/pi-reliability-soak-summary.json |
| pi-workflow | 20260622-102758-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-102758-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-102338-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass, js-edit:pass, browser-style:pass | ../results/20260622-102338-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-102308-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 | file-create:pass | ../results/20260622-102308-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| runner-comparison | 20260622-114930-runner-comparison | pass | qwen/qwen3-coder-30b-q4 | pi-docker:pass, docker-controlled:pass, host-controlled:pass | ../results/20260622-114930-runner-comparison/runner-comparison-summary.json |
| pi-workflow | 20260622-084538-pi-jinja-q4-toolcall-workflow | unknown | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-084538-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-082839-pi-jinja-q4-toolcall-workflow | unknown | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-082839-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-082611-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-082611-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-082602-pi-jinja-q4-toolcall-workflow | unknown | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-082602-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-082508-pi-jinja-q4-toolcall-workflow | pass | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-082508-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| pi-workflow | 20260622-082442-pi-jinja-q4-toolcall-workflow | unknown | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-082442-pi-jinja-q4-toolcall-workflow/pi-jinja-q4-toolcall-workflow-summary.json |
| validation | 20260622-081921-pi-docker-q4-jinja-toolcall-browser-style-clean | pass | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-081921-pi-docker-q4-jinja-toolcall-browser-style-clean/pi-docker-q4-jinja-toolcall-browser-style-summary.json |
| validation | 20260622-080439-pi-docker-q4-jinja-toolcall-js-edit | pass | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-080439-pi-docker-q4-jinja-toolcall-js-edit/pi-docker-q4-jinja-toolcall-js-edit-summary.json |
| validation | 20260622-075618-pi-docker-q4-jinja-toolcall-edit-prompted | pass | qwen/qwen3-coder-30b-q4 |  | ../results/20260622-075618-pi-docker-q4-jinja-toolcall-edit-prompted/pi-docker-q4-jinja-toolcall-edit-summary.json |
| docker-controlled | 20260621-235639-docker-controlled-q4-workflow | pass | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260621-235639-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json |
| docker-controlled | 20260621-235618-docker-controlled-q4-workflow | unknown | qwen/qwen3-coder-30b-q4 | js-window, browser-style | ../results/20260621-235618-docker-controlled-q4-workflow/docker-controlled-q4-workflow-summary.json |

## Rendered Benchmark Reports

- local-inference-dashboard.md
- phase-00-preflight.md
- phase-01-wsl-rocm-runtime.md
- phase-02-agent-benchmarks.md
- phase-03-recommendation.md
- phase-04-browser-verification.md
- phase-05-research-candidates.md
- phase-06-docker-pi-runner.md
- phase-07-rankings-failure-modes.md
- phase-08-multi-model-matrix.md
- phase-09-completion-audit.md
- phase-10-pi-docker-dry-run.md
- phase-11-docker-pi-validation.md
- phase-12-recommended-q4-workflow.md
- phase-13-docker-controlled-agent.md
- phase-14-memory-cap-32gb.md
- phase-15-pi-tool-call-compatibility.md
- phase-16-pi-jinja-toolcall-recovery.md
- phase-17-pi-soak-challenge-dashboard.md
- phase-18-pi-memory-cap-sweep.md
- phase-19-pi-10-run-soak.md
- phase-20-runner-endpoint-final-recommendation.md
- phase-21-16k-controlled-pi-context.md
- phase-22-16k-opencode-windows-models.md
- phase-23-gemma4-e4b-context-comparison.md
