# Optimization Summary 15 - Performance, Vulkan Build, and Regression

## What changed in this chunk

- Switched Windows to the `Performance` power scheme.
- Finished a custom llama.cpp Vulkan build that had previously failed at shader generation.
- Benchmarked the custom server, packaged direct server, and a speculative decoding attempt.
- Found a temporary performance regression after heavy build/direct-server work.

## Successful build work

- Built `bvk/bin/llama-server.exe` with Vulkan enabled.
- Root cause of the previous build failure:
  - `vulkan-shaders-gen.exe` was missing `libc++.dll` and `libunwind.dll`.
  - `glslc.exe` path quoting broke inside the generator's Windows `CreateProcessA` path.
- Fix applied:
  - copied the llvm-mingw runtime DLLs beside helper executables
  - reconfigured CMake with the DOS short path to `glslc.exe`
- The build now generates real SPIR-V-backed `.comp.cpp` files and links successfully.

## Benchmark results

| Test | Result | Interpretation |
| --- | ---: | --- |
| Custom Vulkan server | `17.58 tok/s` wall, `23.21 tok/s` internal | Regression |
| Packaged direct server control | `17.01 tok/s` wall, `22.80 tok/s` internal | Regression |
| Packaged direct + Qwen3 0.6B draft | `14.09 tok/s` wall, `18.28 tok/s` internal | Regression |
| LM Studio managed single-slot retest | `23.11 tok/s` wall, `24.79 tok/s` internal | Temporarily degraded |
| LM Studio managed 4-way retest | `34.56 tok/s` aggregate wall | Temporarily degraded |

## Speculative decoding finding

- Draft model: `Qwen3-0.6B-Q4_K_M`.
- Spec type: `draft-simple`.
- Draft acceptance was high at `85.764%`.
- Despite that, throughput fell because the draft model added too much work.
- This draft setup should not be used for the Qwen3 Coder 30B speed profile.

## Comparison with earlier best

- Earlier best single-slot LM Studio result:
  - about `65-66 tok/s`
- Earlier best unique-prompt 4-way aggregate:
  - `122.26 tok/s`
  - about `3.02x` versus the original `40.5 tok/s` baseline
- Current retests are far below those values and should be treated as a degraded post-build state, not as the new best.

## Current best-known configuration

- Runtime: LM Studio Vulkan `2.22.0`
- Model: `qwen/qwen3-coder-30b`, Q4_K_M
- Context: `8192`
- Eval batch: `2048`
- Physical batch: `512`
- Experts: `4`
- Parallel slots for throughput: `4`
- Flash attention: enabled
- KV cache GPU offload: enabled
- Windows power scheme: `Performance`

## What failed

- Custom Vulkan build did not outperform LM Studio.
- Newest Vulkan SDK `glslc` was not usable earlier because it crashed.
- Older working `glslc` produced a build, but likely missed important shader extensions.
- Qwen3 0.6B speculative decoding reduced speed.
- Immediate post-build LM Studio retests did not reproduce the earlier 3x aggregate result.

## Current interpretation

- The practical 3x aggregate path still comes from LM Studio managed Vulkan `2.22.0` with `parallel=4`.
- The strict single-response 3x target is still not achieved.
- The newest problem is stateful: after heavy build and direct-server testing, the local runtime is temporarily much slower.
- Next useful step is cooldown plus a clean LM Studio/backend restart if the slowdown persists.

## Next actions

- Restore the LM Studio throughput profile before pausing.
- Re-run the 4-way aggregate benchmark after cooldown.
- If still low, restart LM Studio or its backend process and retest.
- Keep the custom Vulkan build as a diagnostic artifact, not as the recommended runtime.
