# Optimization Summary 18 - GPU Clock Root Cause

## What this chunk covers

- Adds AMD ADL PMLog telemetry.
- Confirms the degraded LM Studio speed is caused by low GPU clocks, not just LM Studio settings.
- Tests whether a separate D3D11 graphics workload can wake the GPU.
- Identifies the next useful action as an ASUS/AMD/platform reset or manual performance-mode change.

## Current performance

| Measurement | Result |
| --- | ---: |
| Best single-stream Vulkan state observed earlier | `70.33-71.59 tok/s` internal |
| Current single-stream Vulkan state | about `22-24 tok/s` wall |
| Fresh benchmark with PMLog sampling | `23.07 tok/s` wall |
| GPU compute utilization during slow runs | high, usually mid-80 percent average |
| Actual PMLog GFX clock during inference | about `600 MHz` |

The key discovery is that high GPU utilization was misleading: the GPU is busy, but it is busy at a very low clock.

## Tools added

| Tool | Purpose |
| --- | --- |
| `tools/adl-readonly-probe.cpp` | AMD ADL read-only telemetry probe |
| `tools/adl-readonly-probe.exe` | Compiled probe executable |
| `tools/d3d11-gpu-warmup.cpp` | D3D11 graphics workload for clock-wakeup testing |
| `tools/d3d11-gpu-warmup.exe` | Compiled warmup executable |
| `tools/benchmark-lmstudio-chat-with-adl-pmlog.ps1` | Combined post-reset PMLog plus tokens/sec benchmark |
| `downloads/adl-sdk/` | Official AMD ADL sample/header files used for signatures |

## ADL PMLog result

During active Qwen3 Coder 30B inference, ADL PMLog reported:

| Sensor | Observed range |
| --- | ---: |
| `pmlog_CLK_GFXCLK` | about `600 MHz` |
| `pmlog_CLK_MEMCLK` | about `480-540 MHz` during active samples |
| `pmlog_CLK_SOCCLK` | about `615-622 MHz` |
| `pmlog_GFX_POWER` | about `3-4 W` |
| `pmlog_TEMPERATURE_GFX` | about `46-47 C` |

That is a classic clock/power-state limit: low temperature, low power, low clock, but high utilization.

## ADL and Overdrive findings

- ADL is installed at `C:\Windows\System32\atiadlxx.dll`, version `7.25.20.1600`.
- ADLX is installed at `C:\Windows\System32\amdadlx64.dll`, version `1.4.0.123`.
- ADL PMLog is useful and returns live sensor values.
- ADL `ObservedClockInfo` is not useful for this diagnosis because it reports `2900/1000` even when PMLog shows `600 MHz`.
- OverdriveN performance status is unsupported: `odn_performance_status_rc=-8`.
- Overdrive8 tuning readouts are unsupported: `od8_init_rc=-8`, `od8_current_rc=-8`.
- ADL speed/Force3DClock control is unsupported: `speed_caps=0`.

## D3D11 wakeup test

A separate D3D11 workload was run for 12 seconds. It did not raise the GPU clock:

| Sensor | D3D11 warmup result |
| --- | ---: |
| `pmlog_CLK_GFXCLK` | `600 MHz` |
| `pmlog_GFX_POWER` | `3-4 W` |
| `pmlog_TEMPERATURE_GFX` | about `45 C` |

That means the problem is broader than LM Studio's Vulkan workload. A normal D3D11 graphics workload also remains capped.

## Current interpretation

- The model and runtime config are still the known-good visible shape:
  - stable Vulkan `2.22.0`
  - Qwen3 Coder 30B Q4_K_M
  - context `8192`
  - parallel `1`
  - experts `4`
  - flash attention on
  - KV cache GPU offload on
- The PC is on AC power and battery is at 100 percent.
- LM Studio is High priority.
- Windows `Performance` scheme is active.
- AC PCIe ASPM and CPU performance settings have already been cleaned up.
- The remaining blocker is below ordinary LM Studio settings:
  - ASUS/ProArt performance mode
  - AMD PMF platform policy
  - AMD graphics driver power state
  - a stuck vendor-service or S0 Modern Standby-adjacent state

## What failed

| Attempt | Outcome |
| --- | --- |
| LM Studio reload/restart | speed stayed degraded |
| Stable Vulkan `2.22.0` reselect | did not recover fast state |
| ROCm runtimes | slower than degraded Vulkan |
| ASPM and CPU power policy cleanup | only tiny improvement |
| D3D11 warmup | did not wake GPU above `600 MHz` |
| ADL speed/Force3DClock | unsupported |
| OverdriveN/Overdrive8 telemetry/control | unsupported on this APU |
| ProArt service restart from this session | blocked by Windows service permissions |
| ProArt UI automation from this session | blocked by bundled `@oai/sky` package export error |

## Next recommended action

Keep stable Vulkan `2.22.0` selected. Then perform one external platform action:

- Manually switch ProArt/Armoury Crate to the highest performance or turbo profile, or
- reboot Windows, or
- restart AMD/ASUS platform services from an elevated administrator shell.

After that action, run the ADL PMLog probe during inference. The immediate success criterion is not tokens/sec first; it is seeing `pmlog_CLK_GFXCLK` rise clearly above `600 MHz` under load. Then rerun the single-slot Qwen3 Coder 30B benchmark. If single-stream returns to `55-70 tok/s`, reload the `parallel=4` throughput profile and revalidate the aggregate 3x path.
