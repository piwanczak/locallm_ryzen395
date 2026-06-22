# Optimization Summary 20 - Post-Reboot Clock Cap

## What this chunk covers

- Validates the machine after a full reboot.
- Confirms AMD PMF best-performance settings survived.
- Confirms the Qwen3 Coder 30B speed and GPU clock cap did not recover.
- Narrows the remaining path to ASUS/ProArt mode or administrator-level platform reset.

## Post-Reboot Setup

| Item | Value |
| --- | --- |
| Active power scheme | `Performance` |
| AMD AC `Overlay` | `3` |
| AMD AC `PMF Controller` | `3` |
| AMD DC `Overlay` | `2` |
| AMD DC `PMF Controller` | `2` |
| Runtime | stable Vulkan `2.22.0` |
| Model | `qwen/qwen3-coder-30b` |
| Context | `8192` |
| Parallel | `1` |

## Post-Reboot Benchmark

| Measurement | Result |
| --- | ---: |
| Completion tokens | `320` |
| Elapsed | `13.376 s` |
| Wall speed | `23.92 tok/s` |
| Total tokens | `382` |
| PMLog GFX clock under load | about `600 MHz` |
| PMLog GFX power under load | about `3-4 W` |
| PMLog GPU temperature | about `45-46 C` |

The reboot did not restore the earlier `70+ tok/s` single-stream Vulkan state.

## ASUS State

| Registry value | Data |
| --- | ---: |
| `ThrottleModeOnAC` | `2` |
| `ThrottleModeOnDC` | `2` |
| `UsePerformanceMode` | `0` |
| `PowerModePolicy` | `1` |
| `PowerMode` | `0` |
| `ThermalPolicyIndex` | `0` |
| `EnablePowerSettingsSync` | `1` |

ASUS/AMD platform services were running after reboot, including AMD PMF, AMD External Events, Armoury Crate ProArt Service, ASUS ProArt Service, and ASUS Optimization.

## Interpretation

- The GPU is still active but clock-capped.
- The cap survived:
  - reboot,
  - AMD PMF AC best-performance values,
  - LM Studio model reload,
  - stable Vulkan `2.22.0` selection.
- Further LM Studio runtime switching is unlikely to help until the GPU clock cap is removed.
- The likely remaining owner is ASUS/ProArt thermal/performance mode or an AMD/ASUS platform policy below `powercfg` and ADL.

## Next Best Step

Use the ProArt/Armoury Crate UI or an administrator shell to force the highest platform performance mode. The immediate validation target is `pmlog_CLK_GFXCLK` clearly above `600 MHz` during inference. Only after that should the 4-way throughput profile be retested for the 3x aggregate target.
