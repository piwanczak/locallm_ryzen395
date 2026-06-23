# Local LLM Ryzen 395 Results

Public notes, benchmark summaries, and reusable harnesses from local inference experiments on a Ryzen AI Max / Radeon 8060S class Windows + WSL2 machine.

## Highlights

- **Best current default:** Qwen3 Coder 30B Q4 on WSL2 Ubuntu 24.04 with AMD ROCm/ROCDXG llama.cpp is the strongest local coding profile tested so far.
- **Controlled work is viable:** Qwen3 Coder 30B Q4 passed controlled edit-agent tasks, Docker-controlled tasks, and Windows LM Studio controlled context checks.
- **Context and memory:** 32GB WSL memory cap is enough for the current short-context Q4 workflow and 4-way throughput tests; 48GB is a more comfortable target for Docker/browser/parallel headroom.
- **Pi runner status:** Pi Docker builds and reaches the local model endpoint, but direct promotion still needs structured tool-call handling rather than model-emitted function-tag text.
- **Public result policy:** raw result trees are not published; `public-results/` contains sanitized summaries generated from local benchmark outputs.

## Where To Start

- `benchmarks/wsl-local-inference-benchmark/reports/local-inference-dashboard.md` for the main dashboard.
- `public-results/results-summary.md` for the sanitized benchmark result index.
- `benchmarks/wsl-local-inference-benchmark/setup-runbook.md` for setup and run notes.
- `benchmarks/` for reusable benchmark harnesses and task templates.

This repo intentionally excludes raw logs, downloaded models, extracted runtimes, local result trees, absolute machine paths, and generated build output.
