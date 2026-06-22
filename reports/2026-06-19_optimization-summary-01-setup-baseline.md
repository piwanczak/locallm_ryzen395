# LM Studio Optimization Summary 01 - Setup And Baseline

## Scope

- Objective: improve local inference speed for `qwen/qwen3-coder-30b` in LM Studio, ideally to roughly 3x the starting tokens per second.
- The target model remained Qwen3-Coder 30B. Smaller models were only used as controls or draft/speculative helpers.
- The main workload measured was single-stream chat completion through LM Studio's OpenAI-compatible local API.
- Notes were kept as timestamped Markdown files under `notes/`.

## Machine And Runtime

- Operating system: Windows.
- CPU/APU: AMD Ryzen AI Max+ 395 with Radeon 8060S Graphics.
- GPU/accelerator: AMD Radeon(TM) 8060S Graphics.
- Memory visible to HIP after ROCm SDK extraction: about `50.37 GiB`.
- LM Studio API endpoint: `127.0.0.1:1234`.
- Current restored LM Studio runtime: `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`.
- Current loaded target model:
  - Identifier: `qwen/qwen3-coder-30b`
  - Size: `18.63 GB`
  - Context: `8192`
  - Parallel: `1`
  - Device: Local

## Starting Point

- LM Studio was initially running Qwen3-Coder 30B with mostly default settings.
- Initial model settings included very large context and higher parallelism:
  - Context was around `262144`.
  - Parallel was `4`.
- Starting observed throughput:
  - LM Studio internal: about `45.37 tok/s`.
  - API wall-clock benchmark: about `40.5 tok/s`.

## Assumptions

- The user wanted speed for Qwen3-Coder 30B, not simply a smaller model swap.
- Single-stream generation speed was the main target, not aggregate multi-user throughput.
- Changes should be reversible and should leave LM Studio in a working state.
- Because this is an AMD integrated GPU/APU, Vulkan and ROCm/HIP were the meaningful acceleration paths.

## Baseline Tooling Added

- `tools/benchmark-lmstudio-chat.ps1`
  - Sends a deterministic chat completion request to LM Studio.
  - Reports completion tokens, elapsed seconds, wall tokens per second, and total tokens.
- `tools/reload-qwen30b-fast.ps1`
  - Reloads Qwen3-Coder 30B with the best validated Vulkan settings.
- `tools/finalize-qwen30b-q2.ps1`
  - Verifies/imports the Q2 model after direct download.
- `tools/install-rocm-sdk-msis.ps1`
  - Prepared for narrow ROCm SDK MSI installation.
- `tools/extract-rocm-sdk-msis.ps1`
  - Prepared for administrative extraction of ROCm SDK MSI payloads into the workspace.

## Current Baseline After Work

- The machine is restored to Vulkan, not ROCm, because Vulkan remained faster.
- Current best practical setup is:
  - LM Studio runtime: `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`
  - Model: `qwen/qwen3-coder-30b`
  - Context: `8192`
  - Parallel: `1`
  - GPU: max
  - Flash attention: on
  - KV cache: Q4 for K and V
  - Priority/poll tuning enabled

## Outcome For This Chunk

- Setup analysis is complete.
- Benchmark tooling exists and is reusable.
- Baseline was established around `40.5 tok/s` API wall speed and about `45 tok/s` internal speed.
- Best validated Vulkan path later reached roughly `60-65 tok/s` depending on benchmark path and prompt.
- The 3x target has not yet been achieved.
