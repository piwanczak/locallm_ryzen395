# Optimization Summary 06 - Slow Regression And Recovery Investigation

## Scope

- Target remains `qwen/qwen3-coder-30b`, Q4_K_M GGUF, in LM Studio.
- This chunk documents the regression that appeared after speculative/direct-backend experiments, plus the later recovery to the tuned Vulkan speed range.
- The fixed benchmark remains the count prompt with `max_tokens = 320` and `temperature = 0`.

## Baseline Before Regression

- Earlier tuned Vulkan state:
  - `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`
  - context `8192`
  - parallel `1`
  - Qwen3-Coder 30B Q4_K_M
- Prior verified performance:
  - about `54-60 tok/s` wall-clock in the API benchmark
  - about `64.8 tok/s` best internal decode in older logs

## Investigation Performed

- Updated `tools/benchmark-lmstudio-chat.ps1` to accept `-BaseUrl`, so the same benchmark can test LM Studio and direct backend servers.
- Tested direct `llama-server.exe` on port `1235`.
- Tested:
  - explicit Q4 KV cache
  - default/f16 KV cache
  - flash attention off
  - Vulkan runtime `2.22.0`
  - Vulkan runtime `2.23.0`
  - Windows `Performance` power plan
- Restarted the LM Studio local server and reloaded the target model.

## Results

- Initial LM Studio stable Vulkan after restore:
  - `18.30 tok/s`
- Later verified recovery on stable Vulkan:
  - `51.41 tok/s` with the GPU-counter helper
  - `54.65 tok/s` plain benchmark
  - `54.23 tok/s` plain confirmation
  - `56.17 tok/s` after helper cleanup
- Direct Vulkan with explicit Q4 KV:
  - up to about `19.39 tok/s`
- Direct Vulkan with default KV:
  - up to about `18.52 tok/s`
- Direct Vulkan with flash attention off:
  - up to about `15.43 tok/s`
- Vulkan beta `2.23.0`:
  - about `18.35 tok/s`
- Windows `Performance` plan:
  - did not restore the prior fast path

## Evidence

- Fast LM Studio log block at about `2026-06-19 20:21`:
  - decode `320` tokens in `5596.33 ms`
  - about `57.18 tok/s`
- Slow LM Studio log block at about `2026-06-19 21:38`:
  - decode `320` tokens in `16923.56 ms`
  - about `18.91 tok/s`
- Visible load config remained essentially the same:
  - context `8192`
  - parallel `1`
  - unified KV
  - flash attention exposed as enabled
- Windows GPU counters during a slow run:
  - LM Studio compute engine average about `85.75%`
  - LM Studio compute engine max about `94.13%`
- Windows GPU counters after recovery:
  - LM Studio compute engine average about `67.60%`
  - LM Studio compute engine max about `89.71%`

## Interpretation

- The slow phase did not look like a simple CPU fallback.
- The GPU compute engine was heavily used, but throughput was roughly one third of the earlier fast state.
- Direct backend testing reproduced the slow behavior, so the issue was likely below the LM Studio API wrapper.
- The later recovery happened after returning to stable Vulkan `2.22.0`, keeping Windows on the `Performance` plan, and running another benchmark with GPU counters.
- Most plausible remaining causes:
  - GPU/SoC clock or memory bandwidth state
  - AMD driver/runtime state
  - ASUS/ProArt power profile outside plain Windows `powercfg`
  - low-level Vulkan backend/kernel mode not visible in LM Studio config

## Failures

- `amd-smi` hung and did not provide telemetry.
- WMI did not expose useful clock, power, or thermal data.
- Server restart, model reload, Performance power plan, Vulkan beta, default KV, Q4 KV, and flash-off tests did not recover the prior fast speed immediately.
- The fast-ish state returned later without a reboot, so the exact trigger remains uncertain.

## Current State

- Selected runtime:
  - `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`
- Loaded model:
  - `qwen/qwen3-coder-30b`
  - context `8192`
  - parallel `1`
- Current active Windows power plan:
  - `Performance`
- Current verified speed:
  - about `54.23-56.17 tok/s`

## Next Plan

- Keep stable Vulkan `2.22.0` selected and keep Windows on the `Performance` plan for continued tests.
- Use `tools/benchmark-lmstudio-chat-with-gpu.ps1` after any restart or driver change to capture speed and GPU utilization together.
- If the slow state returns, reboot or reset the AMD graphics driver, then immediately benchmark before changing runtime settings again.
- Check ASUS/ProArt performance mode manually or through vendor tooling, because plain Windows `Performance` did not fix the slow state.
- If the fast `~55-60 tok/s` state returns, capture GPU counters and logs immediately as the known-good reference.
- If it does not return, focus on AMD driver/runtime repair or update, then revisit custom/newer llama.cpp HIP/Vulkan backends for `gfx1151`.
