# Local LLM Ryzen 395 Results

Public notes, benchmark summaries, and reusable harnesses from local inference
experiments on a Ryzen AI Max / Radeon 8060S class Windows + WSL2 machine.

This repository is a curated public slice of a larger private working folder.
It intentionally publishes conclusions, reusable source, report Markdown,
and sanitized result indexes, not raw local logs, model files, caches, prompt
dumps, or private machine paths.

## Current Reading

Qwen3 Coder 30B Q4 remains the best default local coding stack tested here.
The later batches did not displace it; they mostly sharpened the boundaries:

- Draft-model speculative decoding has a narrow useful Windows/Vulkan lane:
  Qwen2.5-Coder 7B/0.5B reached 2.24x, and Qwen3-8B/0.6B reached
  1.26-1.29x without automated quality loss; Qwen3 Coder 30B did not benefit.
- Gemma 4 12B is a strong Windows LM Studio high-context experiment when
  `reasoning_effort=none` is forced, but it is not the broad default.
- Windows and WSL Ollama can run useful Qwen lanes, but wake/clock state and
  endpoint behavior matter.
- DeepSeek V4 Flash can run locally through DS4 ROCm/SSD-streaming paths, but
  the useful results are slow and experimental.
- The real-usage benchmark suite is now the best discriminator; backend API
  work remains harder than small frontend or multi-file edit tasks.

## Main Highlights

1. **Default stack:** Qwen3 Coder 30B Q4 on WSL2 Ubuntu 24.04 with AMD
   ROCm/ROCDXG llama.cpp is still the promoted local coding profile.
2. **16k is realistic:** Qwen3 Coder 30B Q4 passed controlled WSL, Pi, Docker,
   OpenCode, and Windows LM Studio checks at or around the 16k target.
3. **Large context is not automatically useful:** 32k is practical, 65k is
   occasional and slow, and 128k/196k-class runs are mostly loadability or
   overnight evidence rather than interactive coding evidence.
4. **Gemma 4 12B is interesting:** Windows LM Studio passed small controlled
   tasks through 262k configured context and passed a filled 65k OpenCode lane,
   but only with `reasoning_effort=none`; WSL ROCm llama.cpp could not load
   `gemma4` in the tested AMD build.
5. **Real-usage benchmark added:** the seven-task suite covers backend API
   edits, multi-file fixes, schema validation, CLI behavior, frontend behavior,
   failing-command recovery, and sandbox/canary boundaries.
6. **Ollama WSL was corrected:** WSL Ollama became GPU-backed and comparable to
   Windows Ollama after ROCm/ROCDXG environment fixes and a real platform wake;
   Modern Standby/iGPU clock caps can silently invalidate runs.
7. **Qwen3 Coder Next did not promote:** UD-Q2_K_XL and Q4_K_M are viable on
   small tasks, but neither cleared enough backend/agent gates to replace the
   Qwen3 Coder 30B Q4 default.
8. **DeepSeek V4 Flash is runnable but constrained:** DS4 ROCm SSD streaming
   produced usable K160 evidence, including a 5/7 real-usage result, but at low
   throughput and with full-residency/MTP work still experimental.
9. **Windows-native DS4 MTP now runs:** the compatible antirez DeepSeek V4
   Flash base plus public MTP sidecar can load and execute speculative decode
   on Windows ROCm with 96 GB VGM, but the measured tiny MTP run was slower
   than base and is not a practical recommendation yet.
10. **Draft-model speculation has a useful narrow lane:** stock llama.cpp
    `draft-simple` reached 2.24x on Qwen2.5-Coder 7B/0.5B and 1.26-1.29x
    on Qwen3-8B/0.6B, while Qwen3 Coder 30B and n-gram speculation did not
    improve.

## Where To Start

- `benchmarks/wsl-local-inference-benchmark/reports/local-inference-dashboard.md`
  for the main dashboard through the WSL/Ollama/Gemma 12B batch.
- `reports/2026-07-03_ds4-windows-native-mtp-redo.md` for the newest
  Windows-native DS4/MTP result.
- `reports/2026-07-03_speculative-decoding-windows-vulkan.md` for the Windows
  Vulkan draft-model speculative decoding batch.
- `reports/2026-06-26_deepseek-v4-flash-180b-local-run.md` and
  `reports/2026-06-26_antirez-ds4-q2-retry.md` for DeepSeek V4 Flash local
  viability and limits.
- `benchmarks/real-usage-agent-benchmark/reports/real-usage-benchmark-rationale.md`
  for the practical coding benchmark design.
- `benchmarks/kebab-benchmark/reports/2026-06-25-kebab-benchmark-full-run-rollup.md`
  for the visual/canvas benchmark rollup used in several challenger-model
  reports.
- `reports/2026-06-24_good-enough-local-coder-index-v0.md` for the proposed
  "good enough local coder" scoring direction.
- `public-results/results-summary.md` for the sanitized index of local result
  summaries that were used to build the earlier dashboard conclusions.

## Report Order

The most useful current reading order is:

1. Main dashboard:
   `benchmarks/wsl-local-inference-benchmark/reports/local-inference-dashboard.md`
2. Real-usage benchmark rationale:
   `benchmarks/real-usage-agent-benchmark/reports/real-usage-benchmark-rationale.md`
3. Local model 16k context pass:
   `benchmarks/real-usage-agent-benchmark/reports/2026-06-25-local-model-16k-context-benchmark.md`
4. Qwen3 Coder Next reports:
   `benchmarks/wsl-local-inference-benchmark/reports/phase-26-qwen3-coder-next-ollama-ud-q2-xl.md`,
   `reports/2026-06-25_qwen3-coder-next-ud-q2-xl-benchmark.md`,
   `reports/2026-06-25_qwen3-coder-next-ud-q2-xl-agent-harness-eval.md`,
   `reports/2026-06-25_qwen3-coder-next-ud-q4-k-m-followup.md`
5. DeepSeek V4 Flash / DS4 reports:
   `reports/2026-06-26_deepseek-v4-flash-180b-local-run.md`,
   `reports/2026-06-26_deepseek-v4-flash-smaller-quants.md`,
   `reports/2026-06-26_deepseek-v4-flash-fit-scan.md`,
   `reports/2026-06-26_antirez-ds4-q2-retry.md`
6. DS4 tuning and MTP reports:
   `reports/2026-06-26_ds4-k160-performance-options.md`,
   `reports/2026-06-26_ds4-bios-os-tuning-options.md`,
   `reports/2026-07-01_ds4-mtp-windows-rocm.md`,
   `reports/2026-07-01_ds4-rocm-mtp-oom-analysis.md`,
   `reports/2026-07-03_ds4-windows-native-mtp-redo.md`
7. Speculative decoding reports:
   `reports/2026-07-03_speculative-decoding-windows-vulkan.md`
8. Challenger model reports:
   `reports/2026-06-26_bios307-full-local-model-benchmarks.md`,
   `reports/2026-06-27_ornith-1-0-9b-q4km-local-benchmark.md`,
   `reports/2026-06-27_ornith-1-0-9b-tuning-followup.md`,
   `reports/2026-06-29_qwen36-glm51-local-benchmark.md`,
   `reports/2026-06-30_glm51-iq2xxs-local-benchmark.md`
9. Visual benchmark reports:
   `benchmarks/kebab-benchmark/reports/2026-06-25-kebab-benchmark-research-and-harness.md`,
   `benchmarks/kebab-benchmark/reports/2026-06-25-kebab-benchmark-full-run-rollup.md`

## Public Data Policy

Published data is sanitized and deliberately incomplete:

- raw benchmark result trees are excluded;
- local logs, generated workspaces, downloaded models, and build outputs are
  excluded;
- public reports may mention local artifact paths as evidence pointers, but the
  paths are relative or sanitized;
- `public-results/` contains a sanitized index of selected result summaries,
  with private absolute paths rewritten or omitted.

The goal is informational value and partial reproducibility, not a full raw
experiment dump.
