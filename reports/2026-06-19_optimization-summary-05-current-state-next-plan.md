# LM Studio Optimization Summary 05 - Current State And Next Plan

## Current Restored State

- Selected LM Studio runtime:
  - `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`
- Loaded model:
  - `qwen/qwen3-coder-30b`
- Model status:
  - Idle
- Context:
  - `8192`
- Parallel:
  - `1`
- Device:
  - Local
- Fast reload script:
  - `tools/reload-qwen30b-fast.ps1`

## Best Measured Configuration

- Runtime: LM Studio Vulkan `2.22.0`.
- Model: Qwen3-Coder 30B Q4_K_M.
- Context length: `8192`.
- Parallel: `1`.
- GPU: max.
- Flash attention: on.
- KV cache:
  - K: `q4_0`
  - V: `q4_0`
- Scheduling:
  - `LLAMA_ARG_PRIO=2`
  - `LLAMA_ARG_POLL=100`

## Performance Summary

- Starting API wall speed:
  - About `40.5 tok/s`
- Starting LM Studio internal speed:
  - About `45.37 tok/s`
- Best validated tuned Vulkan API wall speed:
  - About `59.8-60.3 tok/s`
- Best tuned Vulkan internal speed:
  - About `64.8 tok/s`
- Best prompt-dependent n-gram result:
  - About `65.2 tok/s`
- Q2 best clean-ish result:
  - About `64.87 tok/s`
- Stable LM Studio ROCm result:
  - About `20-23 tok/s`

## Improvements Achieved

- Built a repeatable benchmark script.
- Reduced wasteful context and parallel settings for the actual single-stream goal.
- Found and scripted the best stable Vulkan configuration.
- Increased practical Qwen3-Coder 30B throughput by about `1.4x-1.5x`.
- Repaired the corrupted Q2 download by downloading directly from Hugging Face.
- Verified AMD HIP SDK support at the device level.
- Downloaded and validated the official AMD HIP SDK installer.
- Extracted enough ROCm SDK runtime to run `hipInfo`, `hipconfig`, and `amdgpu-arch`.
- Found and tested LM Studio's official AMD ROCm runtime.
- Restored the machine to the fastest working configuration after slower experiments.

## Failures And Negative Results

- 3x speed target was not reached.
- Q2 quantization reduced memory but did not reliably beat tuned Q4 Vulkan.
- Speculative decoding was not a general solution.
- Standalone llama.cpp Vulkan b9716 tools hung or failed on this system.
- Standalone llama.cpp HIP b9716 hung.
- Standalone llama.cpp HIP b9601 either hung or crashed depending on DLL/runtime path.
- Full AMD HIP SDK installer did not complete through the command-line path.
- Stable LM Studio ROCm backend loaded successfully but was much slower than Vulkan.
- Beta LM Studio ROCm runtime was listed but not tested because the download/select request was rejected.

## Key Assumptions Still Standing

- The target remains Qwen3-Coder 30B.
- The practical measure is single-stream API wall-clock tokens per second.
- Vulkan is currently the best backend for this specific model and machine.
- A real 3x gain likely requires a backend/kernel improvement, not another minor LM Studio flag.

## Recommended Next Steps

- Keep using the restored Vulkan configuration for daily work.
- Optionally test LM Studio beta ROCm runtime `2.23.0` if allowed:
  - It is the most direct remaining ROCm experiment.
  - It may include backend fixes not present in stable `2.22.0`.
- Watch for newer LM Studio Vulkan/ROCm runtime releases and retest.
- If a full development toolchain is later installed, consider building llama.cpp HIP locally against ROCm 7.1 and `gfx1151`.
- Retain Q2 model as a memory-saving fallback, not as the speed default.
- Avoid switching the primary workflow to stable ROCm `2.22.0`, because it measured slower.

## Practical Commands

Restore the fastest current configuration:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\reload-qwen30b-fast.ps1
```

Benchmark current LM Studio model:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\benchmark-lmstudio-chat.ps1 -Model 'qwen/qwen3-coder-30b'
```

Check selected runtime and loaded model:

```powershell
lms runtime ls
lms ps
```

## Final Status

- The goal is partially progressed but not complete.
- Current speed is materially better than the starting point.
- The requested 3x speedup has not been proven or achieved.
- Best current action is to keep Vulkan fast settings active and treat ROCm beta or future runtime updates as the next high-leverage tests.
