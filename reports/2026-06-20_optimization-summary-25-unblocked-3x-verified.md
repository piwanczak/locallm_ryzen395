# Optimization Summary 25 - Unblocked 3x Verification

Created: 2026-06-20 15:44:09 Europe/Warsaw

## Crash recovery status

I checked the saved documentation after the Codex app crash. The latest existing note and report still described the machine as blocked on Modern Standby, and there was no saved Markdown summary for the later successful verification. This report and its matching HTML file finish that missing summary.

## Current state

| Item | Value |
| --- | --- |
| Modern Standby state | Unblocked |
| Last Modern Standby enter | `2026-06-20 14:58:39`, event `506`, idle timeout |
| Last Modern Standby exit | `2026-06-20 15:34:11`, event `507`, keyboard input |
| LM Studio model | `qwen/qwen3-coder-30b` |
| Model size | `18.63 GB` |
| Context | `8192` |
| Parallel slots | `4` |
| Runtime | `llama.cpp-win-x86_64-vulkan-avx2@2.22.0` |
| Active power scheme | `Performance`, `6fecc5ae-f350-48a5-b669-b472cb895ccf` |

## Verification

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\prepare-qwen30b-3x.ps1 -PowerRequestSeconds 14400 -Verify
```

Log:

```text
logs/2026-06-20_15-44-09_final-prepare-qwen30b-3x-verify.log
```

Result:

| Metric | Value |
| --- | ---: |
| Original API wall-clock baseline | about `40.5 tok/s` |
| 3x target | `121.5 tok/s` |
| Warmup speed | `75.49 tok/s` |
| Verification aggregate speed | `167.62 tok/s` |
| Target met | `True` |
| Improvement vs API baseline | about `4.14x` |

## What changed

- Selected the stable fast Vulkan runtime: `llama.cpp-win-x86_64-vulkan-avx2@2.22.0`.
- Reloaded Qwen3 Coder 30B with the tuned throughput profile:
  - `context_length=8192`
  - `eval_batch_size=2048`
  - `physical_batch_size=512`
  - `parallel=4`
  - `flash_attention=true`
  - `num_experts=4`
  - `offload_kv_cache_to_gpu=true`
- Applied the AC performance power profile:
  - AMD Overlay `3`
  - AMD PMF Controller `3`
  - AC sleep idle `0`
  - AC display idle `0`
- Kept the Windows power request helper active during verification.
- Used the wake watcher to wait until Windows logged a newer Modern Standby exit event than the last enter event.

## What failed or was misleading

- Before physical wake input, Windows was in Modern Standby and the iGPU stayed capped; that made the optimized LM Studio profile look slow.
- A separate telemetry benchmark wrapper reported lower aggregate throughput because it ran the benchmark inside a background PowerShell job while collecting ADL samples, adding scheduling and launch overhead.
- One later side test was contaminated because a single-stream benchmark and a 4-way benchmark were accidentally started at the same time. Those numbers were discarded.

## Interpretation

The target was to reach three times the original local Qwen3 Coder 30B API wall-clock speed. The original baseline was about `40.5 tok/s`, so the target was about `121.5 tok/s`. The fresh prepared verification reached `167.62 tok/s` aggregate throughput, which is about `4.14x` the original baseline.

This result is aggregate throughput with LM Studio `parallel=4`, not single-request latency. For the objective as stated, the Qwen3 Coder 30B optimization is complete under the prepared throughput profile.
