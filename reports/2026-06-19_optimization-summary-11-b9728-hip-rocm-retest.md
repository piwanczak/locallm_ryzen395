# Optimization Summary 11 - b9728 HIP And ROCm 4-Expert Retest

## Scope

- Target model: `qwen/qwen3-coder-30b`, Q4_K_M GGUF.
- This chunk documents:
  - official llama.cpp b9728 HIP Radeon test
  - LM Studio ROCm beta retest with the newer 4-expert profile
  - final Vulkan restore verification

## b9728 HIP Result

- Official asset confirmed through GitHub release metadata:
  - `llama-b9728-bin-win-hip-radeon-x64.zip`
  - about `321 MB`
- Downloaded and extracted under:
  - `downloads/llama-hip/b9728-hip-radeon`
- Smoke checks exited with code `1` and no useful output.
- Direct `llama-server.exe` test exited with access violation:
  - `-1073741819`
- No useful diagnostic log content was produced.

## ROCm Beta 4-Expert Result

- Runtime:
  - `llama.cpp-win-x86_64-amd-rocm-avx2@2.23.0`
- Load:
  - Qwen3-Coder 30B Q4_K_M
  - context `8192`
  - `num_experts = 4`
- Single request:
  - `51.73 tok/s`
- Four concurrent requests:
  - `109.64 tok/s`

## Restored Vulkan Result

- Runtime:
  - `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`
- Load:
  - Qwen3-Coder 30B Q4_K_M
  - context `8192`
  - `num_experts = 4`
  - `parallel = 4`
- Sequential verification after restore:
  - single request: `69.62 tok/s`
  - four concurrent requests: `130.18 tok/s`

## Conclusion

- ROCm beta with 4 experts is better than earlier ROCm tests, but still slower than Vulkan.
- b9728 HIP standalone cannot run reliably on this machine.
- Best current backend remains LM Studio Vulkan `2.22.0`.
- The current machine remains configured for the best verified profile:
  - Q4_K_M
  - 8192 context
  - 4 experts
  - 4 parallel slots
  - Vulkan `2.22.0`
