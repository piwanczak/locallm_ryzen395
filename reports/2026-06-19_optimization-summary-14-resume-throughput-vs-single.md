# Optimization Summary 14 - Resume: Throughput vs Single Stream

## What changed in this chunk

- Resumed the active Qwen3 Coder 30B optimization goal.
- Rechecked the custom-build path.
- Revalidated LM Studio runtime state.
- Added more reliable benchmark switches.
- Restored the fastest known throughput profile.

## Current live profile

- Runtime: LM Studio Vulkan `2.22.0`
- Model: `qwen/qwen3-coder-30b`, Q4_K_M
- Context: `8192`
- Eval batch: `2048`
- Physical batch: `512`
- Experts: `4`
- Parallel slots: `4`
- Flash attention: enabled
- KV cache GPU offload: enabled

## Best current result

- Unique-prompt 4-way aggregate:
  - `122.26 wall tok/s`
  - about `3.02x` versus the original `40.5 tok/s` API wall baseline
- LM Studio internal log for that run:
  - `n_slots = 4`
  - each slot decoded around `31.72-32.61 tok/s`
  - aggregate internal decode roughly `129 tok/s`
- Best fixed-prompt aggregate result today:
  - `139.95 tok/s`

## Caveat

- Single-response 3x is still not achieved.
- `parallel=1` is better for one interactive request, but not enough:
  - observed `67.35 wall tok/s` once
  - later logged `45.39 internal tok/s` and about `40 wall tok/s`
- `parallel=4` is the 3x throughput mode, not the best single-request latency mode.

## Tooling and blockers

- CMake/Ninja wheel install exists in the workspace, but child directories are inaccessible with `Access is denied`.
- No usable CMake/Ninja was found on PATH, under the user profile, or under LM Studio.
- Bundled Codex Python is available, but has no `cmake` or `ninja` packages and no cached wheels.
- Network/elevation requests are currently blocked by the app approval/usage ceiling.
- Windows power scheme is `Standard`; switching to `Performance` was denied without elevation.
- ROCm custom-build probes remain blocked by missing Windows C++ standard library/toolchain pieces.

## Script changes

- `tools/reload-qwen30b-rest.ps1`
  - added `-PhysicalBatchSize`
- `tools/benchmark-lmstudio-chat.ps1`
  - added `-UniquePrompt`
- `tools/benchmark-lmstudio-chat-concurrent.ps1`
  - added `-UniquePrompt`
- `tools/benchmark-lmstudio-chat-with-gpu.ps1`
  - added `-UniquePrompt`
- `tools/reload-qwen30b-throughput.ps1`
  - added wrapper for the 4-slot throughput profile
- `tools/reload-qwen30b-single.ps1`
  - added wrapper for the 1-slot interactive profile

## Interpretation

- The practical win is real for concurrent throughput.
- The strict single-answer 3x target remains blocked by backend/toolchain/system-state limits.
- The current live LM Studio state is intentionally left in the throughput profile.
