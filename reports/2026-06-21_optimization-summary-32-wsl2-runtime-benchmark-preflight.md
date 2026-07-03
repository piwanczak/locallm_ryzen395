# Optimization Summary 32 - WSL2 Runtime Benchmark Preflight

Created: 2026-06-21 10:27 Europe/Warsaw

## Executive Conclusion

The WSL2 benchmark lane is now separated from the Windows OpenCode/LM Studio artifacts, but actual WSL2 runtime benchmarking cannot start yet because no Linux distribution is installed.

Read-only host inventory found:

| Check | Result |
| --- | --- |
| WSL default version | `2` |
| Installed WSL distros | none |
| Distro benchmark status | blocked until a distro is installed |
| Package/runtime changes made | none |

Machine-readable preflight:

- `benchmarks/wsl-local-inference-benchmark/results/20260621-103150-preflight/host-preflight.json`

I preserved the existing Windows profiles and did not install WSL, Linux packages, ROCm, Vulkan tools, llama.cpp, Ollama, or any other runtime.

## Windows Baseline To Compare Against

The WSL2 lane should compare against the already recorded Windows evidence:

| Area | Windows Result |
| --- | --- |
| Best short-context backend direction | LM Studio Vulkan `2.22.0` |
| Windows ROCm beta retest | Qwen 4 experts: `51.73 tok/s` single, `109.64 tok/s` 4-way aggregate |
| Windows Vulkan 2.22 restored check | Qwen 4 experts: `69.62 tok/s` single, `130.18 tok/s` 4-way aggregate |
| Later Windows throughput profile reference | `167.62 tok/s` aggregate |
| Long-context practical recommendation | Qwen `32768`, `parallel=1`, eval batch `2048`, physical batch `512`, flash attention, 4 experts, KV offload |
| OpenCode 65k result | Qwen passed `js-window` but first TTFT was `283.8 s`; not a practical default |
| OpenCode practical speed result | Qwen 16k thin/no-padding `12.6 s` first TTFT on `js-window`, but poor tool behavior |
| OpenCode cleaner calibration result | Gemma 16k thin/no-padding `15.6 s` first byte on `js-window`, clean tool use |

## New WSL2 Artifact Lane

Added:

| Artifact | Purpose |
| --- | --- |
| `benchmarks/wsl-local-inference-benchmark/README.md` | Scope, gates, and baseline references |
| `benchmarks/wsl-local-inference-benchmark/matrix.md` | ROCm/Vulkan/host comparison matrix |
| `benchmarks/wsl-local-inference-benchmark/scripts/collect-host-preflight.ps1` | Windows-side read-only WSL/GPU/baseline inventory |
| `benchmarks/wsl-local-inference-benchmark/scripts/wsl-preflight.sh` | Linux-side no-install GPU/runtime inventory |
| `benchmarks/wsl-local-inference-benchmark/scripts/run-openai-compatible-calibration.mjs` | Generic streaming TTFT/decode smoke test for LM Studio, llama.cpp, Ollama, or another OpenAI-compatible host |

Outputs are isolated under:

- `benchmarks/wsl-local-inference-benchmark/results`
- `benchmarks/wsl-local-inference-benchmark/logs`

## Candidate Order

The first real WSL2 run should use this order:

| Priority | Candidate | Rationale |
| ---: | --- | --- |
| 1 | direct `llama.cpp`/`llama-server` Vulkan | Closest Linux analogue to the current winning Windows Vulkan path |
| 2 | direct `llama.cpp`/`llama-server` ROCm/HIP | Main question is whether native Linux ROCm inside WSL2 beats Windows ROCm/Vulkan on this APU |
| 3 | LM Studio if a WSL-native path is available | Useful only if it can run inside WSL or clearly target a WSL runtime |
| 4 | Ollama or another host | Only if already installed or explicitly approved, and only as an OpenAI-compatible endpoint comparison |

## Promotion Gates

Do not run the fuller OpenCode suite until a candidate passes:

- read-only WSL preflight,
- runtime streaming smoke test,
- measurable first byte and first content,
- decode estimate near or above `30 tok/s`,
- `js-window` OpenCode calibration,
- unchanged canary and fixture-local-only modifications.

## Current Blocker

`wsl.exe -l -v` returned that no distributions are installed. Installing a distro is an external state change and likely network/package action, so it needs explicit approval before I proceed.

## Next Step

After approval, install or select a WSL2 distro, then run:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\collect-host-preflight.ps1
```

Inside the distro, run:

```bash
bash /mnt/c/Users/<you>/Documents/LocalInference\ -\ dzienniczek/benchmarks/wsl-local-inference-benchmark/scripts/wsl-preflight.sh
```

Then start one WSL runtime at a time and measure it with:

```powershell
node .\benchmarks\wsl-local-inference-benchmark\scripts\run-openai-compatible-calibration.mjs --base-url http://127.0.0.1:8080/v1 --model MODEL --concurrency 1
```
