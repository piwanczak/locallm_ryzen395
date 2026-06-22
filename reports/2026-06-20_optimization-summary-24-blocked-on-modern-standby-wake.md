# Optimization Summary 24 - Blocked On Modern Standby Wake

Timestamp: 2026-06-20 15:32:32 +02:00

## State

The optimization goal is blocked on an external wake/unlock action. Windows still reports the system entered Modern Standby at `2026-06-20 14:58:39` and has not logged a newer exit event.

## Evidence

- Latest event `506`: `2026-06-20 14:58:39`, reason `Idle Timeout`.
- Latest event `507`: `2026-06-20 14:22:20`, reason `Input Keyboard`.
- ADL PMLog: GPU core remains around `600 MHz`; ASIC power remains around `14-15 W`.
- LM Studio still serves `qwen/qwen3-coder-30b`.
- Power scheme remains prepared: AC sleep/display idle values are `0`.

## Active Watcher

- Watcher PID: `18580`
- Long power-request helper PID: `2296`
- Transcript: `logs/2026-06-20_15-30-27_wait-wake-and-verify-qwen30b.log`
- The watcher waits for a real `507` wake event, then runs the full Qwen3 Coder 30B verification and an ADL-clocked benchmark.

## Blocked Reason

This is the third consecutive goal continuation with the same condition. I cannot safely wake or unlock the Windows console from here, and a benchmark before wake would only re-measure the known low-power cap.

## Required User Action

Wake or unlock the console with real keyboard/touchpad input. Then the watcher should run automatically, or the verification can be launched manually:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare-qwen30b-3x.ps1 -Verify
```

The goal can be resumed once the system logs a newer `507` event than `506`.
