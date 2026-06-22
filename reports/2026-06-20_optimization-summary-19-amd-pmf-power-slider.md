# Optimization Summary 19 - AMD PMF Power Slider

## What this chunk covers

- Found a hidden AMD Power Slider subgroup in the active Windows power plan.
- Identified documented `Best performance` values for AMD `Overlay` and `PMF Controller`.
- Applied the AC-side values safely and tested them with ADL PMLog.
- Confirmed that the GPU clock cap survives those settings.

## Settings Found

| Setting | GUID | Previous AC | Tested AC | Meaning |
| --- | --- | ---: | ---: | --- |
| `Overlay` | `7ec1751b-60ed-4588-afb5-9819d3d77d90` | `2` | `3` | Best performance |
| `PMF Controller` | `38cab4d5-db09-449f-9db5-1c91c909b6d4` | `2` | `3` | Best performance |

The `PMF Controller` registry description is `Controls the thermal power solution`. Its value `3` is labeled `Best performance` and described as enabling all possible AMD performance-gaining features.

## Results

| Test | Speed | PMLog GFX clock |
| --- | ---: | ---: |
| AC `Overlay=3` only | about `24.3 tok/s` | about `600 MHz` |
| AC `Overlay=3`, AC `PMF Controller=3` | about `23.61 tok/s` | about `600 MHz` |
| Temporary DC values also set to `3` | about `21.73 tok/s` | about `600 MHz` |
| Model reload after AC PMF changes | about `23.63 tok/s` | about `600 MHz` |
| Active scheme flipped away and back | about `22.2 tok/s` | about `600 MHz` |
| AMD PMF / External Events service restart | blocked by service permissions | not retested |

The DC test did not help, so DC values were restored to `2`.

## ASUS Evidence

- ASUS throttle registry stayed unchanged after AMD PMF changes:
  - `ThrottleModeOnAC=2`
  - `ThrottleModeOnDC=2`
  - `UsePerformanceMode=0`
  - `PowerModePolicy=1`
  - `PowerMode=0`
  - `ThermalPolicyIndex=0`
- ASUS throttle XML files are present but encrypted.
- Temporarily importing ASUS's bundled high-performance power scheme showed it still uses AMD `Overlay=2` and `PMF Controller=2`.
- The active `Performance` plan is now stronger than ASUS's bundled high-performance plan on those AMD values.
- Restarting `amdpmfservice` and `AMD External Events Utility` from this session was blocked by Windows service permissions.

## Current State Left In Place

| Item | Value |
| --- | --- |
| Active scheme | `Performance` |
| AC AMD `Overlay` | `3` |
| AC AMD `PMF Controller` | `3` |
| DC AMD `Overlay` | `2` |
| DC AMD `PMF Controller` | `2` |
| LM Studio runtime | stable Vulkan `2.22.0` |
| Loaded model profile | Qwen3 Coder 30B, context `8192`, parallel `1`, experts `4` |

## Interpretation

The AMD PMF settings were real and relevant, but they did not release the `600 MHz` GPU cap. The remaining bottleneck is probably a deeper ASUS/AMD service, firmware, or driver state that is not re-applied by `powercfg` alone.

## Next Best Step

Use an external platform reset or explicit ASUS mode change:

- switch ProArt/Armoury Crate to the highest performance profile,
- reboot Windows,
- or restart/reset AMD/ASUS platform services/devices from an elevated administrator session.

After that, run `tools/benchmark-lmstudio-chat-with-adl-pmlog.ps1` and check for `pmlog_CLK_GFXCLK` clearly above `600 MHz` during inference before retesting throughput mode.
