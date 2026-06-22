# Optimization Summary 16 - Slow-State Root Cause

## What changed in this chunk

- Compared today's fast log block against later slow blocks.
- Confirmed the fast state existed before runtime switching.
- Tried server restart, full LM Studio restart, ROCm retests, and GPU-counter validation.
- Narrowed the remaining blocker to AMD/ASUS/driver/power state rather than LM Studio API settings.

## Key finding

The fast state was real:

- Stable path before runtime switching: Vulkan `2.22.0`
- Internal decode: `70.33 tok/s`
- Prompt eval: `239.09 tok/s`

After runtime changes and direct/custom backend work, the same visible load shape is stuck around:

- Single-slot Vulkan `2.22.0`: `22.89 tok/s` wall with GPU counters
- GPU compute utilization during that slow run: `83.11%` average, `91.41%` max

## What did not fix it

- LM Studio server stop/start.
- Full LM Studio app restart.
- ROCm `2.22.0`.
- ROCm `2.23.0`.
- Stable Vulkan `2.22.0` reload.
- GPU-counter benchmark this time.
- Windows `Performance` power scheme alone.

## Runtime comparison

| Runtime/profile | Observed result |
| --- | ---: |
| Stable Vulkan `2.22.0`, fast state | `70.33 tok/s` internal |
| Vulkan `2.20.1` | about `22.62 tok/s` internal |
| Vulkan `2.23.0` | about `23.41 tok/s` internal |
| ROCm `2.22.0` after restart | about `17.9 tok/s` wall |
| ROCm `2.23.0` after restart | about `17.9 tok/s` wall |
| Stable Vulkan `2.22.0` after restart | `22.89 tok/s` wall |

## Interpretation

- The GPU is being used.
- The load config still shows the expected model, context, experts, flash attention, and KV offload settings.
- The slowdown behaves like a low-level performance state problem:
  - AMD driver/runtime state
  - SoC/GPU clock or memory bandwidth state
  - ASUS/ProArt performance mode
  - Vulkan backend/kernel state
- This is the same class of slow state previously documented on 2026-06-19.

## Current live state

- Runtime: stable Vulkan `2.22.0`
- Model: `qwen/qwen3-coder-30b`, Q4_K_M
- Context: `8192`
- Parallel: `1`
- Experts: `4`
- Flash attention: enabled
- KV cache GPU offload: enabled
- Windows power scheme: `Performance`

## Recommendation

- Do an external reset next:
  - full Windows reboot, or
  - AMD graphics driver reset, or
  - manual ASUS/ProArt performance profile change.
- After the reset, test stable Vulkan `2.22.0` first.
- Only after single-slot speed returns to the `55-70 tok/s` range should the `parallel=4` throughput profile be revalidated.
- The current local work should not be marked complete while this slow state is active.
