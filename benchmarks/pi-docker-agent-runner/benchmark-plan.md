# Local Agentic Benchmark Plan

Created: 2026-06-21

## Source Inputs

- Vicki Boykis, "Running local models is good now", 2026-06-15.
- Saved reading file: `%USERPROFILE%\Downloads\local_llm_recommended_reading.html`.
- Existing Windows results and WSL lane under `benchmarks/wsl-local-inference-benchmark`.
- Current host preflight: `benchmarks/wsl-local-inference-benchmark/results/20260621-205116-preflight/host-preflight.json`.

## Constraints From Current State

- WSL is configured for version 2 and `Ubuntu-24.04` is installed as WSL2.
- WSL is configured around `65 GB` memory and reports about `60 GiB` RAM plus `16 GiB` swap inside Linux. This is not comparable to Windows runs that could use roughly 128 GB RAM.
- ROCm/ROCDXG is installed and HIP smoke passed on `AMD Radeon(TM) 8060S Graphics`, `gfx1151`.
- Vulkan is installed but currently exposes only Mesa `llvmpipe` CPU.
- Docker, Podman, and nerdctl are not currently available on PATH.
- No Pi-in-Docker benchmark can run until a container runtime exists.

## Candidate Model Families

Start with models that either match existing local artifacts or are called out by the article/reading list:

| Candidate | Why test it | First runtime target |
| --- | --- | --- |
| Qwen3 Coder 30B A3B GGUF | Existing local artifact and prior Windows benchmark history | llama.cpp server, LM Studio baseline |
| Qwen 2.5 Coder 7B/14B | Small coding baseline, fast enough for repeated agent loops | Ollama or llama.cpp if available |
| Gemma local agentic candidate | Article reports good local agentic behavior from recent Gemma family models | LM Studio first, llama.cpp/Ollama if available |
| GPT-OSS 20B-style candidate | Article calls it the first local model that reduced API double-checking | Ollama or LM Studio if local artifact is practical |
| Mistral 7B-class baseline | Low-resource control for harness behavior vs model quality | Ollama or llama.cpp |

Do not spend time on more models until one runtime passes smoke and one harness completes `js-window`.

## Runtime Order

1. Existing Windows LM Studio endpoint as control if already running.
2. WSL2 llama.cpp ROCm/HIP via AMD ROCDXG.
3. WSL2 llama.cpp Vulkan only if a non-CPU Vulkan ICD becomes visible.
4. Ollama only as a setup-simple baseline, not as the final performance authority.
5. Pi Docker harness after Docker exists and a local endpoint passes OpenAI-compatible calibration.

## Benchmarks

### Runtime Smoke

- Use `benchmarks/wsl-local-inference-benchmark/scripts/run-openai-compatible-calibration.mjs`.
- Record first byte, first content, total wall time, decode estimate, HTTP status/errors, model id, context size, and server command.
- Record WSL memory cap with every WSL run.
- Run concurrency `1` first, then `4` only if the server stays stable.

### Agentic Coding

- Start with the existing OpenCode `js-window` task because it has already been used as the WSL promotion gate.
- Run fuller suite only after the smoke and `js-window` gates pass:
  - `python-ledger`
  - `java-slug`
  - `js-window`
  - `web-retrieval`
  - `browser-style`

### Pi Container Harness

- Use the same disposable fixture tasks where possible.
- First pass should ask Pi to make a small deterministic code edit and run the local test.
- Browser pass should use the `pi-browser` image and a minimal frontend fixture with Playwright verification.
- Record whether Pi loops, respects `/workspace`, chooses the configured local model, and produces clean edits.

## Promotion Gates

- OpenAI-compatible smoke reaches first content without server errors.
- Agent first-content time is under 2 minutes for preferred profiles.
- Hard fail over 5 minutes unless correctness is exceptional and no better profile exists.
- Decode estimate remains near or above `30 tok/s` where measurable.
- No severe shell/tool loop.
- Canary files and manifests remain unchanged outside disposable fixtures.
- Browser-capable profile passes an actual Playwright check before being called frontend-ready.

## WSL Memory Policy

Keep the current roughly `60 GiB` WSL RAM cap for first ROCm llama.cpp smoke and 30B-class short-context tests. This is enough to test whether the ROCm path works without reintroducing host memory pressure as a variable.

Do not compare WSL long-context results directly against Windows long-context results unless the WSL cap is raised or a memory-cap sweep is part of the result. After the first working runtime profile, test whether lower WSL caps such as `48 GiB` and `32 GiB` are sufficient for smaller models or Pi-only harness work.

## Immediate Next Actions

1. Keep the WSL ROCm llama.cpp runtime as the working baseline for `gfx1151`.
2. Run new models only after they are locally available as GGUF/Ollama/LM Studio artifacts.
3. Get explicit approval for Docker/container runtime install.
4. Build the Pi base container and validate model config against the working local endpoint.
5. Run Pi against one disposable coding fixture.
