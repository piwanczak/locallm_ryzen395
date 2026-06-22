# Optimization Summary 17 - ASUS, Power, and Driver State

## What this chunk covers

- Captures the state after the slow Vulkan regression persisted.
- Documents ASUS/ProArt, Windows power, AMD GPU, and thermal evidence.
- Records the low-risk performance settings that were applied.
- Separates useful improvements from changes that did not restore the fast state.

## Current live setup

| Item | Value |
| --- | --- |
| LM Studio server | `http://127.0.0.1:1234` |
| Selected runtime | `llama.cpp-win-x86_64-vulkan-avx2@2.22.0` |
| Model | `qwen/qwen3-coder-30b`, Q4_K_M |
| Context | `8192` |
| Parallel slots | `1` |
| Experts | `4` |
| Flash attention | enabled |
| KV cache GPU offload | enabled |
| Windows power scheme | `Performance` |

## Performance position

| Measurement | Result |
| --- | ---: |
| Original API wall baseline | about `40.5 tok/s` |
| Original LM Studio internal baseline | about `45.37 tok/s` |
| Best single-stream Vulkan result | `70.33-71.59 tok/s` internal |
| Best aggregate throughput result | `122.26 tok/s` wall |
| Current single-stream after this pass | about `24.26 tok/s` wall |

The 4-way aggregate result already reached about `3.02x` the original API wall baseline, but the current machine state is degraded and is not yet a reproducible final solution.

## ASUS and platform evidence

- ASUS/ProArt services and helper processes are installed and running.
- ProArt throttle-plugin registry values show an ASUS-controlled performance layer:
  - `ThrottleModeOnAC=2`
  - `ThrottleModeOnDC=2`
  - `UsePerformanceMode=0`
  - `PowerModePolicy=1`
  - `ThermalPolicyIndex=0`
- ASUS logs around the relevant window mention:
  - `HyperFanMode 2`
  - `CPU Use mode 2`
  - `GPU Use mode 2`
  - `SetGraphicsSetting : Begin Select Mode : 2`
  - `PowerModeChangeEvent mode=2`
  - `PowerModeChangeEvent mode=4`
  - `SetPowerModePolicy to Manual`
- No safe documented CLI was found for changing those modes.
- `ConfigHelper.exe /?` and `SetWhisperMode.exe /?` failed with `0xc0000142`, so no blind ASUS setting changes were attempted.

## AMD and thermal evidence

- GPU: `AMD Radeon(TM) 8060S Graphics`.
- OpenCL device: `gfx1151`.
- OpenCL compute units: `20`.
- OpenCL max clock: `2900 MHz`.
- OpenCL driver version: `3661.0`.
- Windows thermal counters did not show active throttling.
- LM Studio GPU compute utilization is high during slow runs, usually around the mid-80 percent range with peaks above 90 percent.

## Changes applied

- Confirmed the active Windows power scheme is `Performance`.
- Disabled AC PCI Express ASPM:
  - `SUB_PCIEXPRESS ASPM = 0`
- Set AC CPU energy/performance preference values to maximum performance where exposed:
  - `PERFEPP=0`
  - `PERFEPP1=0`
  - `PERFEPP2=0`
- Set AC core parking minimum cores to 100 percent where exposed:
  - `CPMINCORES=100`
  - `CPMINCORES1=100`
- Set LM Studio related processes to High priority.

## What improved

- The machine now has a cleaner AC performance-policy baseline for later tests.
- PCIe ASPM is no longer an obvious hidden power-saving setting on AC.
- CPU energy preference and core parking are less likely to interfere with prompt evaluation or backend scheduling.

## What failed to restore speed

| Attempt | Result |
| --- | --- |
| ASPM off before reload | about `23.90 tok/s` wall |
| ASPM off after reload | about `23.54 tok/s` wall |
| High process priority | about `23.20 tok/s` wall |
| CPU performance policy changes | about `24.26 tok/s` wall |
| Full LM Studio restart | did not recover fast state |
| Stable Vulkan `2.22.0` reload | did not recover fast state |
| ROCm `2.22.0` and `2.23.0` | slower than degraded Vulkan |
| Qwen3 0.6B speculative draft | high acceptance, lower throughput |

## Working interpretation

- The visible LM Studio load config is probably not the main difference between fast and slow states.
- The selected stable Vulkan runtime can be fast on this hardware because it already reached `70+ tok/s`.
- The slow state still uses the GPU, but each token takes about three times longer.
- The remaining suspect is below the ordinary LM Studio settings layer:
  - AMD driver/runtime state
  - SoC or GPU clock state
  - memory-bandwidth state on the unified-memory GPU
  - ASUS/ProArt performance mode
  - Vulkan backend state that survives normal LM Studio reloads

## Next recommended step

Keep stable Vulkan `2.22.0` selected. Try one more read-only telemetry pass for AMD/ASUS GPU performance state if a safe interface is available. If that remains opaque, use an external reset: full Windows reboot, manual ASUS/ProArt performance-mode change, or AMD graphics driver reset.

After reset, benchmark stable Vulkan `2.22.0` immediately with the single-slot profile. If it returns to the `55-70 tok/s` range, reload the `parallel=4` throughput profile and revalidate the aggregate 3x path.
