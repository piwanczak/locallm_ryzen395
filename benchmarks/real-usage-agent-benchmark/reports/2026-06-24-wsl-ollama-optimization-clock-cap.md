# WSL Ollama Optimization - Clock-Cap Diagnosis

Created: 2026-06-24 Europe/Warsaw

## Objective

Optimize WSL Ollama on the AMD/ROCDXG stack until `qwen3-coder:30b` is
comparative with Windows native Ollama, accepting up to a 30% slowdown on fair
direct API throughput, then rerun direct API, OpenCode, and Pi benchmark lanes.

## Current status

WSL Ollama is GPU-fixed but not performance-fixed.

The ROCm placement fix is valid:

- WSL Ollama loads `qwen3-coder:30b` as `100% GPU`.
- `HSA_ENABLE_DXG_DETECTION=1` and preloading Ollama's bundled
  `libhsa-runtime64.so.1` are required for reliable ROCDXG discovery.
- Fit mode now succeeds when the bundled HSA runtime is preloaded.

The performance target is not met:

- WSL Ollama 4k, fit on, flash attention on: about `11-12 tok/s`.
- WSL Ollama 262k, fit on, flash attention on: about `11-12 tok/s`.
- AMD WSL llama.cpp current runtime, same model blob: about `9-12 tok/s`.
- Low-level `llama-bench`, bypassing Ollama and server adapters: about
  `11.37 tok/s` generation.

Because standalone AMD llama.cpp is slow in the same session, the remaining
issue is below Ollama configuration.

## Key evidence

### Low-level WSL ROCm benchmark

Command family:

```text
llama-bench -m /usr/share/ollama/.ollama/models/blobs/sha256-1194192cf2a187eb02722edcc3f77b11d21f537048ce04b67ccf8ba78863006a -p 512 -n 1024 -b 2048 -ub 512 -ngl 99 -fa 1 -r 1 -o json
```

Result log:

```text
benchmarks/wsl-local-inference-benchmark/logs/20260624-ollama-opt-adl-during-wsl-llama-bench-2/llama-bench-p512-n1024.log
```

Observed result:

| Metric | Value |
| --- | ---: |
| Prompt eval | `190.79 tok/s` |
| Generation | `11.37 tok/s` |
| Backend | ROCm |
| GPU | `AMD Radeon(TM) 8060S Graphics`, `gfx1151` |

### ADL PMLog during WSL ROCm generation

ADL sample log:

```text
benchmarks/wsl-local-inference-benchmark/logs/20260624-ollama-opt-adl-during-wsl-llama-bench-2/adl-samples.txt
```

Parsed PMLog summary:

| Sensor | Min | Max | Avg |
| --- | ---: | ---: | ---: |
| `pmlog_CLK_GFXCLK` | `600 MHz` | `717 MHz` | `609.3 MHz` |
| `pmlog_CLK_MEMCLK` | `401 MHz` | `811 MHz` | `682.2 MHz` |
| `pmlog_ASIC_POWER` | `14 W` | `15 W` | `14.3 W` |
| `pmlog_TEMPERATURE_GFX` | `38 C` | `49 C` | `43.4 C` |

This is a low-power clock cap: active GPU work, low temperature, low power, and
GFX clock pinned around 600 MHz.

## Modern Standby state

The current Windows power event state matches the prior documented slow-state
root cause:

| Event | Time | Reason |
| --- | --- | --- |
| Last Modern Standby enter `506` | `2026-06-24 07:42:31` | Idle Timeout |
| Last Modern Standby exit `507` | `2026-06-24 07:37:25` | Input Keyboard |

There is no later `507` exit event after the latest `506` enter event. `LockApp`
and `LogonUI` are also present. This is the same class of state previously
documented in:

- `reports/2026-06-20_optimization-summary-18-gpu-clock-root-cause.md`
- `notes/2026-06-20_15-24-17_lmstudio-qwen3-modern-standby-root-cause.md`
- `reports/2026-06-20_optimization-summary-25-unblocked-3x-verified.md`

## Actions applied

The known AC performance baseline was restored:

- Windows `Performance` power scheme.
- AMD AC `Overlay=3`.
- AMD AC `PMF Controller=3`.
- AC sleep idle disabled.
- AC display idle disabled.
- Console lock display timeout set to `0` where available.

The existing power-request helper was started for 4 hours:

```text
tools/windows-power-request.exe 14400
```

This should help prevent another idle-triggered Modern Standby entry, but prior
evidence says it does not reliably exit an already-active Modern Standby low
power path.

## Interpretation

The WSL Ollama slowdown is currently caused by platform power state, not by the
tested Ollama knobs:

- `LLAMA_ARG_FIT` is no longer the active bottleneck.
- 4k versus 262k context is not the active bottleneck.
- Flash attention and larger batch settings are not enough while the GPU is
  clock-capped.
- The same low generation rate appears in standalone AMD `llama-bench`.
- ADL PMLog confirms the GPU is capped around 600 MHz and 14-15 W.

The 30% comparison target cannot be honestly evaluated while this platform
state is active.

## Required next step

Wake or unlock the Windows console with real keyboard/touchpad input. The
immediate validation target is:

- Windows logs a newer Modern Standby exit event `507` than the last enter
  event `506`.
- ADL PMLog during WSL ROCm generation shows `pmlog_CLK_GFXCLK` clearly above
  the current 600-700 MHz cap.

Only after that should the goal rerun:

1. WSL low-level `llama-bench`.
2. WSL Ollama direct API probes.
3. Windows native baseline.
4. Full direct API, OpenCode, and Pi benchmark lanes if WSL Ollama is within
   the accepted 30% envelope.
