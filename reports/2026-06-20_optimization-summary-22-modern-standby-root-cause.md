# Optimization Summary 22 - Modern Standby Root Cause

Timestamp: 2026-06-20 15:24:17 +02:00

## Scope

This chunk covers the continuation after the driver/chipset upgrade pause. The goal was to verify the actual current state, explain why Qwen3 Coder 30B performance regressed again, apply safe mitigations, and document failures.

## Evidence

- LM Studio is serving `qwen/qwen3-coder-30b` on `http://127.0.0.1:1234`.
- AMD graphics driver still reports:
  - `AMD Radeon(TM) 8060S Graphics`
  - Version `32.0.31019.2002`
  - Date `2026-05-29`
- Controlled concurrent benchmark:
  - `43.03 tok/s` aggregate
  - `pmlog_CLK_GFXCLK` around `600 MHz`
  - `pmlog_CLK_MEMCLK` around `400 MHz` during load
  - ASIC power around `14-15 W`
- Windows power events:
  - Entered Modern Standby: `2026-06-20 14:58:39`
  - Reason: `Idle Timeout`
  - Last exit before that: `2026-06-20 14:22:20`, reason `Input Keyboard`
- ASUS log repeats:
  - `Under Modern Standby mode, ignore CheckThreadWorks.`

## Interpretation

The current bottleneck is platform power state, not the LM Studio runtime settings. The iGPU is in the S0/Modern Standby low-power path, which caps GPU clocks and power. This explains the drop from earlier warmed `140-150 tok/s` runs to the current `43.03 tok/s` or worse.

## Improvements Applied

- Active `Performance` scheme retained.
- AMD AC Power Slider settings retained at best performance:
  - Overlay: `3`
  - PMF Controller: `3`
- AC display timeout changed to `0`.
- AC console-lock display timeout set to `0`.
- Added `tools/windows-power-request.exe`:
  - Uses Windows power-request APIs rather than only `SetThreadExecutionState`.
  - Intended to prevent future benchmark sessions from falling back into Modern Standby.
- Updated `tools/prepare-qwen30b-3x.ps1`:
  - Applies the power settings.
  - Starts the power-request helper.
  - Reports Modern Standby status from Windows event logs.
  - Warns when physical wake input is required.

## Failures And Corrections

- `tools/windows-keep-awake.exe` did not lift the cap once Modern Standby was already active.
- ASUS GPU wake calls returned success for the helper call but did not raise clocks.
- Direct ASUS native setter probing was unsafe:
  - `SetGamingCenterThrottleMode(3)` corrupted `ThrottleModeOnAC`.
  - The value was immediately restored to `3`.
  - The probe now ignores setters unless `--unsafe-enable-setters` is supplied.
- Service restarts remain unavailable without elevated permissions.

## Current State

- Goal is not complete.
- Current measured performance is below the 3x target while Modern Standby is active.
- The practical blocker is waking the console out of S0/Modern Standby using real input.
- Once awake, the new prep script should prevent the idle timeout from recurring during benchmarks.

## Next Verification

Run after waking/unlocking the console:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare-qwen30b-3x.ps1 -Verify
```

Target evidence:

- Latest Windows event `507` is newer than latest `506`.
- ADL PMLog is no longer pinned at `600 MHz` / `14-15 W`.
- Qwen3 Coder 30B 4-way aggregate throughput is at least `121.5 tok/s`.
