# Optimization Summary 10 - Official b9728 Vulkan Backend Check

## Scope

- Target model: `qwen/qwen3-coder-30b`, Q4_K_M GGUF.
- This chunk documents a final official standalone llama.cpp backend check after the throughput target was reached in LM Studio.

## Source

- Official llama.cpp release page:
  - `https://github.com/ggml-org/llama.cpp/releases/tag/b9728`
- The page listed release `b9728` and Windows x64 Vulkan assets.

## Action

- Downloaded:
  - `downloads/llama-vulkan/llama-b9728-bin-win-vulkan-x64.zip`
- Extracted:
  - `downloads/llama-vulkan/b9728-vulkan`
- Temporarily unloaded LM Studio's model.
- Tested b9728's `llama-server.exe` through `tools/benchmark-direct-llama-server.ps1`.

## Result

- The standalone b9728 Vulkan server exited early:
  - exit code `-1073741819`
- This is a Windows access violation.
- No useful diagnostic log content was produced.
- This matches the earlier b9716 standalone Vulkan failure pattern.

## Restored State

- LM Studio was restored to the best verified profile:
  - model: `qwen/qwen3-coder-30b`
  - Q4_K_M
  - context `8192`
  - `num_experts = 4`
  - `parallel = 4`
  - flash attention enabled
  - KV cache offload enabled
- Fresh restored aggregate throughput:
  - `132.09 tok/s`

## Conclusion

- The official b9728 standalone Vulkan backend does not improve the situation because it crashes on this PC.
- LM Studio's bundled Vulkan runtime remains the best working backend.
- Current best result remains:
  - about `66-71 tok/s` single-response
  - about `132-136 tok/s` aggregate throughput with four concurrent requests
