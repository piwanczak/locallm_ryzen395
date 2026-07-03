# Local Inference Dashboard

Generated: 2026-06-24T14:17:28.376Z

## Abridged Project State

Current promoted local coding stack: Qwen3 Coder 30B Q4 remains the default across WSL ROCm, Pi Docker, Docker-controlled, OpenCode, Windows LM Studio, and Ollama evidence. WSL Ollama is now GPU-fixed and performance-comparable to Windows Ollama after a real platform wake from the Modern Standby/iGPU clock-cap state: qwen3-coder:30b loads at 100% GPU, direct API throughput is within the 30% gate, OpenCode reaches the corrected Windows pass count of 3/4, and guarded Pi passes when the local Qwen/Ollama tool-call reminder is embedded in the prompt file. Windows Ollama remains the simpler endpoint; verified WSL ROCm llama.cpp remains the more controlled Linux GPU comparison lane. The nearest Ollama Gemma mappings can generate direct text, but Ollama rejects tool-use requests for those Gemma tags, so they are not currently viable for OpenCode/Pi agentic tool lanes. Gemma 4 12B remains an experimental Windows LM Studio high-context lane after controlled checks with reasoning_effort=none. Reliable small coding-agent work still needs stronger task completion and write-boundary controls.

Updated through: 2026-06-24

## Current Recommendation

| Layer | Recommendation | Links |
| --- | --- | --- |
| Endpoint | Default to Qwen3 Coder 30B Q4. For WSL ROCm llama.cpp use CTX_SIZE=16384 when context is useful, PARALLEL=1, and LLAMA_JINJA=1 for Pi/tool-call work. Windows Ollama is a viable OpenAI-compatible Qwen endpoint for direct API, OpenCode, and guarded Pi. WSL Ollama is also viable after the ROCm/ROCDXG fix and a verified platform wake: use OLLAMA_IGPU_ENABLE=1, OLLAMA_LLM_LIBRARY=rocm_v7_2, HSA_ENABLE_DXG_DETECTION=1, LD_PRELOAD for Ollama's libhsa-runtime64, 262k context when needed, flash attention, and the prompt-file Qwen/Ollama tool-call reminder for Pi. Keep verified WSL ROCm llama.cpp as the more controlled Linux GPU comparison. Keep Windows LM Studio Gemma 4 12B for experimental high-context checks only when every request path can set reasoning_effort=none. | [Phase 21 16k controlled/Pi](phase-21-16k-controlled-pi-context.md), [Phase 22 16k OpenCode/Windows](phase-22-16k-opencode-windows-models.md), [Phase 23 Gemma E4B](phase-23-gemma4-e4b-context-comparison.md), [Phase 24 Gemma 12B](phase-24-gemma4-12b-context-comparison.md), [Phase 25 Gemma 12B follow-up](phase-25-gemma4-12b-follow-up-validation.md), [Phase 20 final recommendation](phase-20-runner-endpoint-final-recommendation.md), [Phase 16 Pi recovery](phase-16-pi-jinja-toolcall-recovery.md), [Ollama comparison](../../real-usage-agent-benchmark/reports/2026-06-23-ollama-inference-server-comparison.md), [Ollama WSL ROCm correction](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-rocm-fair-correction.md), [WSL Ollama GPU fix](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-ollama-gpu-fix-benchmark.md), [WSL Ollama clock-cap diagnosis](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimization-clock-cap.md), [WSL Ollama optimized and Pi fixed](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimized-and-pi-fixed.md) |
| Runner | Use the host/WSL controlled runner as the default benchmark harness; use Docker-controlled for Linux isolation; use guarded Pi Docker when validating Dockerized agentic tool execution; use OpenCode for slower full-agent realism checks. Use the real-usage benchmark before promoting any stack as useful for practical backend/frontend coding work. In the corrected Ollama fairness pass, Qwen reached 3/4 OpenCode and 1/1 Pi on Windows Ollama, verified WSL ROCm llama.cpp, and now optimized WSL Ollama with the prompt-file tool-call reminder; backend-api remains unsolved. | [Phase 03 recommendation](phase-03-recommendation.md), [Runner comparison summary](../../../public-results/results-summary.md), [Real-usage rationale](../../real-usage-agent-benchmark/reports/real-usage-benchmark-rationale.md), [Real-usage execution](../../real-usage-agent-benchmark/reports/2026-06-22-real-usage-agent-execution.md), [Real-usage follow-up](../../real-usage-agent-benchmark/reports/2026-06-23-real-usage-followup-and-pi-guard.md), [Ollama real-usage comparison](../../real-usage-agent-benchmark/reports/2026-06-23-ollama-inference-server-comparison.md), [Ollama WSL ROCm correction](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-rocm-fair-correction.md), [WSL Ollama GPU fix](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-ollama-gpu-fix-benchmark.md), [WSL Ollama clock-cap diagnosis](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimization-clock-cap.md), [WSL Ollama optimized and Pi fixed](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimized-and-pi-fixed.md) |
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
| 16k context reality check | 16k is realistic for this project. Qwen3 Coder 30B Q4 passed controlled WSL 8k vs 16k comparison, Pi Jinja file/edit/browser, Pi five-task challenge suite, Docker-controlled, OpenCode thin-prompt js-window and browser-style, and Windows LM Studio controlled tasks. Windows LM Studio was faster on controlled first-content timings; OpenCode passed but remained slow and tool-heavy. | [Phase 21 16k controlled/Pi](phase-21-16k-controlled-pi-context.md), [Phase 22 16k OpenCode/Windows](phase-22-16k-opencode-windows-models.md), [16k WSL controlled summary](../../../public-results/results-summary.md), [16k OpenCode summary](../../../public-results/results-summary.md), [Windows LM Studio 16k summary](../../../public-results/results-summary.md) |
| Gemma E4B context check | The earlier fallback Gemma 4 E4B passed Windows LM Studio controlled tasks through 65k, loaded at 131k but failed protected browser-style, failed WSL ROCm load because AMD llama.cpp build 8407 does not recognize gemma4, passed raw LM Studio tool-call probes, and passed a simple Pi file-create task through LM Studio. It is superseded by the actual 12B check. | [Phase 23 Gemma E4B](phase-23-gemma4-e4b-context-comparison.md), [65k controlled summary](../../../public-results/results-summary.md), [65k OpenCode summary](../../../public-results/results-summary.md), [Pi through LM Studio summary](../../../public-results/results-summary.md) |
| Gemma 4 12B context check | The actual Gemma 4 12B model is installed. WSL ROCm still cannot load gemma4, but Windows LM Studio passed controlled js-window and protected browser-style through 262k when requests used reasoning_effort=none. A 3-run reliability sweep passed 18/18 task cells across 16k, 65k, and 262k. OpenCode passed real neutral-padded 65k js-window and browser-style tasks, but each took about 11.7 minutes. Raw tool calls passed, and Pi through LM Studio now passes file-create, JS edit, and protected browser-style. | [Phase 24 Gemma 12B](phase-24-gemma4-12b-context-comparison.md), [Phase 25 Gemma 12B follow-up](phase-25-gemma4-12b-follow-up-validation.md), [262k controlled summary](../../../public-results/results-summary.md), [Reliability sweep](../../../public-results/results-summary.md), [65k OpenCode summary](../../../public-results/results-summary.md), [Tool-call summary](../../../public-results/results-summary.md), [Pi through LM Studio file-create](../../../public-results/results-summary.md), [Pi JS/browser follow-up](../../../public-results/results-summary.md), [WSL recheck](../../../public-results/results-summary.md) |
| Real-usage benchmark | A runner-neutral seven-task suite now exists for backend API work, multi-file bugfixes, schema validation, CLI enhancement, frontend behavior, failing-command recovery, and canary-boundary checks. The follow-up corrected OpenCode prompting and added a Pi guarded-workspace mode. Official Qwen3 Coder 30B passed multi-file-cart and frontend-filter under corrected OpenCode, and passed multi-file-cart under guarded Pi with runner exit 0, verifier success, no allowlist violations, and canary unchanged. Backend-api remains unsolved and is still the best discriminator. | [Real-usage rationale](../../real-usage-agent-benchmark/reports/real-usage-benchmark-rationale.md), [Real-usage execution](../../real-usage-agent-benchmark/reports/2026-06-22-real-usage-agent-execution.md), [Real-usage follow-up](../../real-usage-agent-benchmark/reports/2026-06-23-real-usage-followup-and-pi-guard.md), [Follow-up rollup](../../real-usage-agent-benchmark/reports/2026-06-23-followup-rollup.md), [Self-test summary](../../../public-results/results-summary.md), [Direct API matrix](../../../public-results/results-summary.md), [OpenCode matrix](../../../public-results/results-summary.md), [Corrected OpenCode matrix](../../../public-results/results-summary.md), [Guarded Pi matrix](../../../public-results/results-summary.md) |
| Ollama inference server | Ollama 0.30.10 is installed on both Windows and WSL. Windows serves on 127.0.0.1:11434 and works as a Qwen endpoint for direct API, OpenCode, and guarded Pi. WSL Ollama serves localhost-only on 127.0.0.1:11435 and now loads Qwen on ROCm/GPU after forcing ROCDXG discovery and preloading Ollama's HSA runtime. The slow WSL Ollama pass was traced to Windows Modern Standby / iGPU clock cap, not Ollama alone: low-level llama-bench was about 11.37 tok/s while ADL showed GFXCLK around 609 MHz and 14 W. After a platform wake, low-level WSL ROCm generation recovered to 59.41 tok/s, and WSL Ollama direct API matched Windows within about 1-5% on task output TPS. WSL Ollama OpenCode reached 3/4 passes, matching corrected Windows pass behavior, with backend-api still failing. Baseline WSL Pi still failed on Qwen XML tool-call parsing, but the prompt-file local Qwen/Ollama tool-call reminder fixed it: WSL Pi passed in 215.4 s and Windows Pi with the same note passed in 235.1 s. Ollama Gemma mappings passed no agentic tool rows because the endpoint rejected tool-use requests for gemma3n:e4b and gemma3:12b. | [Ollama comparison](../../real-usage-agent-benchmark/reports/2026-06-23-ollama-inference-server-comparison.md), [Ollama WSL ROCm correction](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-rocm-fair-correction.md), [Corrected Ollama fairness rollup](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-fair-wsl-rocm-correction-rollup.md), [WSL Ollama GPU fix](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-ollama-gpu-fix-benchmark.md), [WSL Ollama GPU rollup](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-gpu-fixed-rollup.md), [WSL Ollama clock-cap diagnosis](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimization-clock-cap.md), [WSL Ollama optimized and Pi fixed](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimized-and-pi-fixed.md), [Ollama rollup](../../real-usage-agent-benchmark/reports/2026-06-23-ollama-rollup.md), [Windows direct matrix](../../../public-results/results-summary.md), [WSL direct matrix](../../../public-results/results-summary.md), [OpenCode matrix](../../../public-results/results-summary.md), [Windows Pi matrix](../../../public-results/results-summary.md), [WSL Pi matrix](../../../public-results/results-summary.md), [Corrected Windows OpenCode](../../../public-results/results-summary.md), [Corrected WSL ROCm OpenCode](../../../public-results/results-summary.md), [Optimized WSL Ollama direct matrix](../../../public-results/results-summary.md), [Optimized WSL Ollama OpenCode](../../../public-results/results-summary.md), [Optimized WSL Ollama Pi](../../../public-results/results-summary.md), [Windows Pi same reminder](../../../public-results/results-summary.md) |

## Canonical Artifacts

- [Promoted Pi workflow](../../../public-results/results-summary.md)
- [Pi challenge suite](../../../public-results/results-summary.md)
- [Pi memory sweep](../../../public-results/results-summary.md)
- [Pi 10-run soak](../../../public-results/results-summary.md)
- [Runner comparison](../../../public-results/results-summary.md)
- [Endpoint comparison](../../../public-results/results-summary.md)
- [16k controlled WSL comparison](../../../public-results/results-summary.md)
- [16k Pi challenge suite](../../../public-results/results-summary.md)
- [16k OpenCode workflow](../../../public-results/results-summary.md)
- [16k Windows LM Studio controlled](../../../public-results/results-summary.md)
- [Gemma E4B 65k controlled](../../../public-results/results-summary.md)
- [Gemma E4B 65k OpenCode](../../../public-results/results-summary.md)
- [Gemma E4B LM Studio Pi file-create](../../../public-results/results-summary.md)
- [Gemma 12B 262k controlled](../../../public-results/results-summary.md)
- [Gemma 12B 65k OpenCode](../../../public-results/results-summary.md)
- [Gemma 12B LM Studio tool calls](../../../public-results/results-summary.md)
- [Gemma 12B LM Studio Pi file-create](../../../public-results/results-summary.md)
- [Gemma 12B LM Studio Pi JS/browser](../../../public-results/results-summary.md)
- [Gemma 12B controlled reliability sweep](../../../public-results/results-summary.md)
- [Gemma 12B WSL ROCm recheck](../../../public-results/results-summary.md)
- [Real-usage execution report](../../real-usage-agent-benchmark/reports/2026-06-22-real-usage-agent-execution.md)
- [Real-usage follow-up report](../../real-usage-agent-benchmark/reports/2026-06-23-real-usage-followup-and-pi-guard.md)
- [Real-usage follow-up rollup](../../real-usage-agent-benchmark/reports/2026-06-23-followup-rollup.md)
- [Real-usage benchmark self-test](../../../public-results/results-summary.md)
- [Real-usage direct API matrix](../../../public-results/results-summary.md)
- [Real-usage OpenCode matrix](../../../public-results/results-summary.md)
- [Real-usage Pi matrix](../../../public-results/results-summary.md)
- [Corrected real-usage OpenCode matrix](../../../public-results/results-summary.md)
- [Guarded real-usage Pi matrix](../../../public-results/results-summary.md)
- [Ollama comparison report](../../real-usage-agent-benchmark/reports/2026-06-23-ollama-inference-server-comparison.md)
- [Ollama rollup](../../real-usage-agent-benchmark/reports/2026-06-23-ollama-rollup.md)
- [Ollama WSL ROCm correction](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-rocm-fair-correction.md)
- [Corrected Ollama fairness rollup](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-fair-wsl-rocm-correction-rollup.md)
- [WSL Ollama GPU fix report](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-ollama-gpu-fix-benchmark.md)
- [WSL Ollama GPU fixed rollup](../../real-usage-agent-benchmark/reports/2026-06-24-ollama-wsl-gpu-fixed-rollup.md)
- [WSL Ollama clock-cap diagnosis](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimization-clock-cap.md)
- [WSL Ollama optimized and Pi fixed](../../real-usage-agent-benchmark/reports/2026-06-24-wsl-ollama-optimized-and-pi-fixed.md)
- [Ollama Windows direct matrix](../../../public-results/results-summary.md)
- [Ollama WSL direct matrix](../../../public-results/results-summary.md)
- [Ollama OpenCode matrix](../../../public-results/results-summary.md)
- [Ollama Windows Pi matrix](../../../public-results/results-summary.md)
- [Ollama WSL Pi matrix](../../../public-results/results-summary.md)

## Remaining Limits

- Ollama Gemma tags gemma3n:e4b and gemma3:12b rejected OpenAI tool-use requests in OpenCode and Pi, so they are not currently viable for agentic tool lanes without a different model/tag/import or endpoint behavior.
- WSL Ollama now discovers and loads Qwen on ROCm/GPU and is performance-comparable after a verified platform wake, but Modern Standby / iGPU clock caps can silently invalidate runs. Rerun WSL Ollama benchmarks only after wake validation or an ADL/throughput sanity check.
- WSL Ollama Pi requires the prompt-file local Qwen/Ollama tool-call reminder; without it, the model can reason correctly but the endpoint/tool parser may end the stream before an edit/write tool call lands.
- Gemma 4 12B cannot currently use the promoted WSL ROCm llama.cpp lane because the AMD build does not recognize gemma4.
- Gemma 4 12B requires reasoning_effort=none on LM Studio/OpenAI-compatible request paths; default reasoning exhausted output tokens with no visible content.
- Gemma 4 12B is proven at 262k only for small controlled prompts; the real filled-prompt OpenCode proof is 65k.
- Gemma 4 12B filled 131k OpenCode is deferred as an overnight-only run; 65k already took about 11.7 minutes per task.
- Gemma 4 12B Pi through LM Studio is proven for file-create, JS edit, and protected browser-style, but failed all three real-usage Pi tasks by timeout.
- Corrected OpenCode real-usage still leaves backend-api unsolved, and several rows reach verifier-passing state only to keep running until the host cap.
- Pi Docker has one guarded real-usage pass for a no-generated-output task; generated-output tasks still need an explicit writable generated-output mount policy.
- A true MCP/tool-mediated local lane is still pending.
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
| model-matrix | 20260622-200545-model-matrix | unknown |  |  | ../results/20260622-200545-model-matrix/model-matrix-summary.json |
| model-matrix | 20260622-153616-model-matrix | unknown |  |  | ../results/20260622-153616-model-matrix/model-matrix-summary.json |
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
| lmstudio-context-ladder | 20260622-200029-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-12b | js-window, browser-style | ../results/20260622-200029-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| lmstudio-context-ladder | 20260622-195835-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-12b | js-window, browser-style | ../results/20260622-195835-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| reliability-gemma12 | 20260622-185709-gemma12-controlled-reliability-sweep | pass | google/gemma-4-12b | browser-style, js-window | ../results/20260622-185709-gemma12-controlled-reliability-sweep/gemma12-controlled-reliability-sweep-summary.json |
| lmstudio-context-ladder | 20260622-185709-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-12b | js-window, browser-style | ../results/20260622-185709-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| pi-lmstudio-gemma12-workflow | 20260622-185347-gemma12-pi-lmstudio-workflow | pass | google/gemma-4-12b | js-edit:pass, browser-style:pass | ../results/20260622-185347-gemma12-pi-lmstudio-workflow/gemma12-pi-lmstudio-workflow-summary.json |
| toolcall-probe-gemma12 | 20260622-174238-gemma12-lmstudio-toolcall-probe | pass | google/gemma-4-12b |  | ../results/20260622-174238-gemma12-lmstudio-toolcall-probe/gemma12-lmstudio-toolcall-probe-summary.json |
| lmstudio-context-ladder | 20260622-171416-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-12b | js-window, browser-style | ../results/20260622-171416-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| lmstudio-context-ladder | 20260622-171211-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-12b | js-window, browser-style | ../results/20260622-171211-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| lmstudio-context-ladder | 20260622-171124-windows-lmstudio-controlled-context-ladder | pass | google/gemma-4-12b | browser-style | ../results/20260622-171124-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| reasoning-control-gemma12 | 20260622-170855-gemma12-thinking-control-probe | pass | google/gemma-4-12b |  | ../results/20260622-170855-gemma12-thinking-control-probe/gemma12-thinking-control-probe-summary.json |
| lmstudio-context-ladder | 20260622-170012-windows-lmstudio-controlled-context-ladder | fail | google/gemma-4-12b | browser-style | ../results/20260622-170012-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
| opencode-gemma12 | 20260622-171740-gemma12-65k-opencode-lmstudio | pass | google/gemma-4-12b | js-window, browser-style | ../results/20260622-171740-gemma12-65k-opencode-lmstudio/gemma12-65k-opencode-lmstudio-summary.json |
| pi-lmstudio-gemma12 | 20260622-174543-gemma12-pi-lmstudio-file-create | pass | google/gemma-4-12b |  | ../results/20260622-174543-gemma12-pi-lmstudio-file-create/gemma12-pi-lmstudio-file-create-summary.json |
| lmstudio-context-ladder | 20260622-153648-windows-lmstudio-controlled-context-ladder | fail | google/gemma-4-12b | js-window, browser-style | ../results/20260622-153648-windows-lmstudio-controlled-context-ladder/windows-lmstudio-controlled-context-ladder-summary.json |
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

- local-inference-dashboard.html
- phase-00-preflight.html
- phase-01-wsl-rocm-runtime.html
- phase-02-agent-benchmarks.html
- phase-03-recommendation.html
- phase-04-browser-verification.html
- phase-05-research-candidates.html
- phase-06-docker-pi-runner.html
- phase-07-rankings-failure-modes.html
- phase-08-multi-model-matrix.html
- phase-09-completion-audit.html
- phase-10-pi-docker-dry-run.html
- phase-11-docker-pi-validation.html
- phase-12-recommended-q4-workflow.html
- phase-13-docker-controlled-agent.html
- phase-14-memory-cap-32gb.html
- phase-15-pi-tool-call-compatibility.html
- phase-16-pi-jinja-toolcall-recovery.html
- phase-17-pi-soak-challenge-dashboard.html
- phase-18-pi-memory-cap-sweep.html
- phase-19-pi-10-run-soak.html
- phase-20-runner-endpoint-final-recommendation.html
- phase-21-16k-controlled-pi-context.html
- phase-22-16k-opencode-windows-models.html
- phase-23-gemma4-e4b-context-comparison.html
- phase-24-gemma4-12b-context-comparison.html
- phase-25-gemma4-12b-follow-up-validation.html
