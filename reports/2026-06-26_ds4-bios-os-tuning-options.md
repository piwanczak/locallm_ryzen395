---
title: BIOS and OS tuning options for DS4 on ProArt PX13
date: 2026-06-26
tags:
  - local-inference
  - ds4
  - rocm
  - wsl
  - bios
  - windows
---

# BIOS and OS tuning options for DS4 on ProArt PX13

## Summary

The largest actionable OS-level finding is that WSL currently sees only about 64 GiB of RAM on a 128 GiB machine. That matches Microsoft's documented default behavior for WSL2 memory when `.wslconfig` is absent. For DS4 DeepSeek V4 Flash K160, this likely explains why ROCm reports about 65.65 GiB total, why SSD streaming is required, and why MTP/speculative decoding cannot be used.

Highest-upside change to test: create a temporary `%USERPROFILE%\.wslconfig` with a larger memory cap, restart WSL, and retry K160 full residency. Start at 96GB, then 112GB if Windows remains stable.

## Machine State Observed

| Area | Current value |
| --- | --- |
| System | ASUS ProArt PX13 HN7306EA |
| BIOS | HN7306EA.304, 2025-12-24 |
| CPU/GPU | AMD Ryzen AI MAX+ 395 with Radeon 8060S |
| Windows GPU driver | 32.0.31021.1015, 2026-06-20 |
| Physical RAM | 132,766,306,304 bytes |
| Memory modules | 8 x 16 GiB Samsung LPDDR5X, configured 8000 MT/s |
| WSL distro | Ubuntu 24.04.4 |
| WSL kernel | 6.18.33.1-microsoft-standard-WSL2 |
| ROCm/HIP | 7.2.4 |
| WSL visible RAM | 63,594,172 kB |
| WSL swap | 16 GiB |
| `.wslconfig` | absent |
| Windows power scheme | Whisper |
| ASUS performance registry | `UsePerformanceMode=0`, `ThermalPolicyIndex=2` |
| VBS / HVCI | VBS running, Memory Integrity enabled |

## Highest-Value OS Change: WSL Memory Cap

Microsoft documents that the WSL2 `memory` setting defaults to 50% of total memory on Windows. This machine has no `.wslconfig`, and WSL reports about 63.6 GiB visible RAM on a 128 GiB host.

Suggested temporary test config:

```ini
[wsl2]
memory=96GB
swap=32GB
processors=32
```

If stable, retry:

```ini
[wsl2]
memory=112GB
swap=32GB
processors=32
```

Procedure:

1. Save any WSL work.
2. Write `%USERPROFILE%\.wslconfig`.
3. Run `wsl --shutdown`.
4. Start Ubuntu again.
5. Confirm `grep MemTotal /proc/meminfo`.
6. Retry K160 full residency first; if it loads, retry MTP without `--ssd-streaming`.
7. Remove `.wslconfig` and `wsl --shutdown` again if the machine becomes unstable or Windows memory pressure is unacceptable.

Why this matters: DS4's current K160 SSD-streaming run caps the expert cache at 45 GiB and reports about 65.65 GiB ROCm total. Giving WSL 96-112 GiB may expose enough ROCm memory to make K160 full residency possible, or at least increase the expert cache headroom.

## BIOS / Firmware Options To Check

These were not changed during this run.

| Option | Why it may help | Risk / note |
| --- | --- | --- |
| Update BIOS through MyASUS / ASUS support if newer than HN7306EA.304 exists | Strix Halo/8060S firmware and memory training are central to ROCm stability and shared-memory behavior. | Do only on AC power and after reading release notes; BIOS updates carry normal firmware-update risk. |
| Look for UMA / iGPU memory / graphics memory allocation controls | If exposed, a larger graphics/shared-memory aperture may help ROCm lock more memory. | Some Strix Halo systems may manage this dynamically; Windows `AdapterRAM` showing ~4 GiB is not necessarily the compute limit. |
| Use ASUS Performance/Turbo/full-fan mode in ProArt Creator Hub/MyASUS | Sustained DS4 runs are thermal/power heavy; higher fan and power limits can avoid clock caps. | A short Windows power-scheme-only test did not improve DS4, so test with fan/thermal mode specifically, not just `powercfg`. |
| Disable silent/whisper thermal policy for benchmark sessions | Current active plan is `Whisper`; prior local inference work also found platform wake/clock-cap states can invalidate GPU results. | Restore quiet profile afterward if desired. |

## Windows Options

| Option | Recommendation |
| --- | --- |
| Windows power scheme | `Performance` alone did not improve the short K160 DS4 test: 6.79 tok/s vs 6.81 tok/s. Still use AC power and avoid Whisper for long heat-soaked tests if fan policy also changes. |
| WSL Ollama service | Stop WSL Ollama during DS4 benchmarks. A transient DS4 ROCm init failure occurred while WSL Ollama/GPU discovery was active; clean GPU state avoids a confound. |
| Memory Integrity / HVCI | Currently enabled. Do not disable as a first-line change; WSL depends on virtualization and the security tradeoff is high. Consider only as a controlled A/B after the WSL memory cap test. |
| Hardware-accelerated GPU scheduling | Registry value was not present. No recommendation from current evidence. |
| Modern Standby / platform wake state | Keep using a quick low-level throughput sanity check after sleep/wake. Previous WSL ROCm work found iGPU clock-cap states can silently wreck performance. |

## Linux / ROCm Options

AMD's ROCm on WSL documentation supports the current WSL/ROCm style setup, and AMD has a system optimization page for RDNA 3.5 / Strix Halo. The Strix Halo page is Linux-focused and discusses kernel versions and TTM shared-memory limits. In WSL, `/sys/module/ttm/parameters/pages_limit` was present but `0`, and `/sys/module/ttm/parameters/pages` was absent, so the Linux TTM tuning path does not map cleanly to this WSL session.

Practical WSL path:

1. Increase WSL memory cap first.
2. Keep ROCm/HIP current.
3. Keep `HSA_ENABLE_SDMA=0` for DS4 runs because it has been the working local convention.
4. Recheck `rocminfo` and DS4 `--inspect` after any driver, BIOS, or WSL memory change.

## Test Matrix To Run If Approved

| Step | Test | Success signal |
| --- | --- | --- |
| 1 | `.wslconfig memory=96GB`, WSL shutdown/restart | WSL reports ~96 GiB RAM; DS4 K160 full residency progresses beyond old 48 GiB wall. |
| 2 | K160 full-residency smoke, no SSD streaming | Generates 32-128 tokens without stall. |
| 3 | K160 full-residency + MTP draft 2 | DS4 no longer rejects MTP; throughput improves or stays neutral. |
| 4 | `.wslconfig memory=112GB` if 96GB insufficient | More ROCm headroom without Windows instability. |
| 5 | ASUS Performance/Turbo fan profile, same DS4 bench | Sustained decode improves across repeated runs, not just first cold run. |
| 6 | K128 REAP Q2 if K160 remains slow | Speed improves enough to justify quality loss. |

## Sources

- AMD ROCm on WSL install documentation: https://rocm.docs.amd.com/projects/radeon/en/latest/docs/install/wsl/install-radeon.html
- AMD RDNA 3.5 / Strix Halo system optimization: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/rdna3-5.html
- Microsoft WSL `.wslconfig` documentation: https://learn.microsoft.com/en-us/windows/wsl/wsl-config
- ASUS ProArt PX13 HN7306 technical specifications: https://www.asus.com/laptops/for-creators/proart/proart-px13-hn7306/techspec/
