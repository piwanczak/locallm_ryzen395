# Phase 14 WSL 32GB Memory Cap Report

Date: 2026-06-22

## Scope

This phase tests whether the current WSL memory behavior around `65GB` is required for the recommended Qwen3 Coder 30B Q4 host/WSL workflow.

The test used the guarded sweep wrapper and temporarily applied:

```ini
[wsl2]
memory=32GB
swap=16GB
```

The wrapper restored the previous state afterward. The previous state had no `%USERPROFILE%\.wslconfig`.

## Validation Artifact

| Artifact | Result |
| --- | --- |
| `results/20260622-001155-memory-cap-sweep/memory-cap-sweep-summary.json` | Completed at `32GB` |
| `results/20260622-001155-memory-cap-sweep/32GB-wsl-memory-probe.txt` | Confirmed active cap: about `31GiB` visible RAM and `16GiB` swap |

After restoration, `%USERPROFILE%\.wslconfig` was absent again.

## Results Under 32GB

| Check | Result |
| --- | --- |
| WSL visible RAM | `31GiB`; `MemTotal: 32861896 kB` |
| Single calibration | PASS; first content `357.1 ms`; decode estimate `53.38 tok/s` |
| `js-window` controlled edit | PASS; first content `1413.5 ms`; wall `6580.1 ms`; verifier exited `0` |
| Protected `browser-style` edit | PASS; first content `1922.3 ms`; wall `3256.1 ms`; verifier exited `0` |
| 4-way throughput calibration | PASS; `4/4` successful; first content min `396.7 ms`; aggregate `90.58 tok/s` |

## Memory Interpretation

The Qwen3 Coder 30B Q4 short-context profile fits well below `65GB`:

- ROCm model buffer: about `17596 MiB`
- 8k one-slot KV buffer: about `768 MiB`
- 4-way 4k-context KV buffer: about `384 MiB`
- Host memory reported by llama.cpp memory breakdown: about `176-190 MiB`

The model file and OS cache still need system headroom, but the measured `32GB` run proves the current controlled workflow and 4-way short-context throughput do not require `65GB`.

## Decision

For the current recommended host/WSL workflow, `65GB` is not required. A `32GB` WSL cap is proven for:

- Qwen3 Coder 30B Q4
- `CTX_SIZE=8192`, `PARALLEL=1` controlled edit tasks
- protected frontend task
- 4-way throughput at `CTX_SIZE=4096`, `PARALLEL=4`

Use `48GB` instead of `32GB` if keeping more headroom for Docker Desktop, Pi/browser containers, larger contexts, package installs, or parallel agent experiments matters. Keep default/no cap if maximizing WSL flexibility is more important than reserving RAM for Windows.

## Remaining Limits

This is not a long-context memory proof. It does not validate `32GB` for 16k/32k+ agent runs, Gemma after runtime support changes, Docker-controlled runs under cap, Pi browser workflows, or multiple simultaneous agents.
