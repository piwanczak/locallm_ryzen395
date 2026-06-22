# Optimization Summary 23 - Wake Watcher

Timestamp: 2026-06-20 15:29:14 +02:00

## Summary

The machine is still in the same Modern Standby-derived low-power state, so a valid 3x verification is not possible yet. I added and launched a passive watcher that waits for a real Windows wake event, then runs the full Qwen3 Coder 30B verification automatically.

## Current Evidence

- Latest Modern Standby enter: `2026-06-20 14:58:39`, event `506`, reason `Idle Timeout`.
- Latest Modern Standby exit: `2026-06-20 14:22:20`, event `507`, reason `Input Keyboard`.
- ADL PMLog still shows `pmlog_CLK_GFXCLK=600` and `14-15 W`.
- LM Studio still serves `qwen/qwen3-coder-30b`.

## Added Tooling

- `tools/wait-wake-and-verify-qwen30b.ps1`
  - Waits until Modern Standby is inactive.
  - Starts/reuses `tools/windows-power-request.exe`.
  - Runs `tools/prepare-qwen30b-3x.ps1 -Verify`.
  - Runs the ADL-clocked concurrent benchmark afterwards.
  - Writes a transcript under `logs`.

## Watcher Status

- Watcher PID: `18580`
- Long power-request helper PID: `2296`
- Power-request duration: `14400` seconds
- Transcript: `logs/2026-06-20_15-30-27_wait-wake-and-verify-qwen30b.log`
- Launcher stdout: `logs/2026-06-20_15-30-26_watcher-launch.out.log`
- Launcher stderr: `logs/2026-06-20_15-30-26_watcher-launch.err.log`
- Note: an earlier watcher attempt was replaced so the live watcher starts its own long-lived power request.

## Remaining Requirement

Wake or unlock the console with real input. After that, the watcher should produce the evidence needed to decide whether the 3x target is currently achieved.
