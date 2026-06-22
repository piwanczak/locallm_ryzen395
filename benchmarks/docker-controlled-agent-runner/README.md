# Docker Controlled Agent Runner

This runner packages the existing controlled edit-agent benchmark into a small Docker image. It is separate from the Pi runner:

- Pi tests a real third-party agent CLI and currently exposes a local llama.cpp tool-call compatibility gap.
- This runner tests the proven controlled edit-agent harness inside Docker so containerized local coding benchmarks can produce deterministic pass/fail evidence.

Build and run is normally handled by:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  .\benchmarks\wsl-local-inference-benchmark\scripts\run-docker-controlled-q4-workflow.ps1 `
  -Build
```

The workflow starts the WSL ROCm Qwen3 Coder Q4 endpoint, runs `js-window` and protected `browser-style` from inside Docker, writes raw results under `benchmarks/wsl-local-inference-benchmark/results`, and stops the WSL server.
