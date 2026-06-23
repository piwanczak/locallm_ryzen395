# Optimization Summary 33 - WSL OpenCode Runner And Setup Runbook

Created: 2026-06-21 10:36 Europe/Warsaw

## Executive Conclusion

Actual WSL2 ROCm/Vulkan benchmarking is still blocked because this machine has no installed WSL distribution. I did not install a distro, packages, drivers, or runtimes.

This step makes the next approved benchmark run practical: the WSL lane now has a setup runbook and an OpenCode runner that can target any local WSL-hosted OpenAI-compatible endpoint, such as direct `llama-server`, without touching the known-good Windows LM Studio profiles.

## Current Machine State

| Check | Result |
| --- | --- |
| `wsl.exe --status` | default version `2` |
| `wsl.exe -l -v` | no installed distributions |
| WSL benchmark execution | blocked until distro install |
| Windows LM Studio/OpenCode profiles | not changed |
| Package/runtime installs | none |

Existing clean preflight artifact remains:

- `benchmarks/wsl-local-inference-benchmark/results/20260621-103150-preflight/host-preflight.json`

## Added Artifacts

| Artifact | Purpose |
| --- | --- |
| `benchmarks/wsl-local-inference-benchmark/setup-runbook.md` | Approval-gated distro, preflight, runtime, and benchmark sequence |
| `benchmarks/wsl-local-inference-benchmark/scripts/run-opencode-wsl-compatible-benchmark.ps1` | Runs existing OpenCode fixtures against a local OpenAI-compatible WSL endpoint |
| `notes/2026-06-21_10-36-12_wsl2-opencode-runner-and-runbook.md` | Timestamped step note |

The new runner:

- reuses the existing disposable OpenCode fixture workspace,
- writes WSL-specific results/logs/prompts under `benchmarks/wsl-local-inference-benchmark`,
- starts the timing proxy against a supplied local endpoint such as `http://127.0.0.1:8080`,
- creates an isolated benchmark OpenCode config for the WSL endpoint,
- does not load or restore LM Studio profiles,
- redirects OpenCode config/data/cache/state/temp under the WSL benchmark root,
- denies external directories, live web search, user questions, destructive shell patterns, package installs, git commit, and git push,
- records prompt metadata, OpenCode step tokens, tool calls, grades, manifests, proxy timings, and canary checks.

## Official Source Checks

Primary docs checked on 2026-06-21:

| Source | Relevant Finding |
| --- | --- |
| Microsoft WSL install docs | `wsl --install -d <Distro>` installs a selected distro; `wsl.exe --list --online` lists available distros |
| Microsoft WSL GPU acceleration docs | WSL GPU workflows require a WSL distro and suitable Windows-side GPU support |
| AMD ROCm on Ryzen WSL guide | Current Ryzen WSL path uses ROCDXG; Ubuntu `24.04` and `22.04` are listed as supported WSL distros |
| AMD ROCDXG repo/compatibility matrix | ROCDXG uses `/dev/dxg`; `AMD Ryzen AI Max+ 395` appears in the ROCm `7.2.x` compatibility row |
| AMD Ryzen llama.cpp prebuilt-binaries guide | AMD documents Ubuntu 24.04 llama.cpp binaries with `gfx110X`, `gfx115X`, and `gfx120X` support |

Links:

- https://learn.microsoft.com/en-us/windows/wsl/install
- https://learn.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl
- https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/wsl/howto_wsl.md
- https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/advanced/advancedryz/linux/llm/llamacpp.md
- https://github.com/ROCm/librocdxg/

## Recommended Next Sequence

After explicit approval:

1. Install Ubuntu 24.04:

```powershell
wsl.exe --install -d Ubuntu-24.04
```

2. Confirm it is WSL2:

```powershell
wsl.exe -l -v
```

3. Run the no-install Linux preflight:

```powershell
wsl.exe --distribution Ubuntu-24.04 -- bash -lc "cd /mnt/c/Users/<you>/Documents/'LocalInference - dzienniczek' && bash benchmarks/wsl-local-inference-benchmark/scripts/wsl-preflight.sh benchmarks/wsl-local-inference-benchmark/results/wsl-linux-preflight"
```

4. Install one runtime path at a time, starting with AMD's validated ROCm/llama.cpp path if approved.

5. Smoke-test the local OpenAI-compatible server:

```powershell
node .\benchmarks\wsl-local-inference-benchmark\scripts\run-openai-compatible-calibration.mjs --base-url http://127.0.0.1:8080/v1 --model qwen/qwen3-coder-30b --concurrency 1
```

6. Run the OpenCode `js-window` calibration:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\run-opencode-wsl-compatible-benchmark.ps1 -BaseUrl http://127.0.0.1:8080 -Model qwen/qwen3-coder-30b -Tasks js-window -ContextLimit 16384 -PromptSourceMode thin -PromptPaddingMode none
```

## Validation

| Check | Result |
| --- | --- |
| `run-opencode-wsl-compatible-benchmark.ps1` parse | pass |
| `collect-host-preflight.ps1` parse | pass |
| `run-openai-compatible-calibration.mjs` `node --check` | pass |
| WSL OpenCode runner dry-run | pass |

Dry-run artifacts:

- `benchmarks/wsl-local-inference-benchmark/results/20260621-103729-opencode/opencode-wsl-benchmark.config.json`
- `benchmarks/wsl-local-inference-benchmark/results/20260621-103729-opencode/runs.jsonl`

## Status

The goal remains active. Completion still requires real WSL2 runtime benchmarks and a final recommendation versus Windows, which cannot be produced until a WSL distro and at least one runtime path are installed with approval.
