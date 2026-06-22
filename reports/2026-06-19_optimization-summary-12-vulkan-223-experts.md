# Optimization Summary 12 - Vulkan 2.23 With 4 Experts

## Scope

- Target model: `qwen/qwen3-coder-30b`, Q4_K_M GGUF.
- This chunk retests LM Studio Vulkan `2.23.0` with the newer 4-expert profile.

## Result

- Vulkan `2.23.0`, 4 experts, parallel `1`:
  - `65.13 tok/s`
- Vulkan `2.23.0`, 4 experts, parallel `4`:
  - `128.00 tok/s` aggregate

## Restored State

- Runtime restored to:
  - `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`
- Loaded profile:
  - Qwen3-Coder 30B Q4_K_M
  - context `8192`
  - `num_experts = 4`
  - `parallel = 4`
  - flash attention enabled
  - KV cache offload enabled
- Confirmation after restore:
  - `69.28 tok/s` single request

## Conclusion

- Vulkan `2.23.0` remains slightly slower than Vulkan `2.22.0` for this setup.
- Best current runtime remains Vulkan `2.22.0`.
