# Optimization Summary 34 - WSL Distro Approval Gate

Created: 2026-06-21 10:39 Europe/Warsaw

## Executive Conclusion

The WSL2 benchmark path is ready to resume, but actual runtime testing remains blocked because no WSL distribution is installed. This is now the third consecutive goal turn where the same missing-distro condition was verified.

This step added and validated a guarded distro preparation wrapper. It is read-only by default and refuses to install anything unless explicitly called with both `-Install` and `-ConfirmInstall`.

## Current Evidence

| Check | Result |
| --- | --- |
| WSL default version | `2` |
| Installed distros | none |
| Target distro | `Ubuntu-24.04` |
| Install requested during validation | `false` |
| Windows LM Studio/OpenCode profiles changed | no |
| Packages/runtimes installed | none |

Read-only validation artifact:

- `benchmarks/wsl-local-inference-benchmark/results/20260621-103937-wsl-distro-prepare/prepare-wsl-distro.json`

## Added Artifact

| Artifact | Purpose |
| --- | --- |
| `benchmarks/wsl-local-inference-benchmark/scripts/prepare-wsl-distro.ps1` | Guarded WSL distro install/preflight wrapper |

Default read-only usage:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\prepare-wsl-distro.ps1 -Distro Ubuntu-24.04
```

Approved install and immediate Linux preflight usage:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\prepare-wsl-distro.ps1 `
  -Distro Ubuntu-24.04 `
  -Install `
  -ConfirmInstall `
  -RunLinuxPreflight
```

Optional web-download form if normal WSL install hangs:

```powershell
.\benchmarks\wsl-local-inference-benchmark\scripts\prepare-wsl-distro.ps1 `
  -Distro Ubuntu-24.04 `
  -Install `
  -ConfirmInstall `
  -WebDownload `
  -RunLinuxPreflight
```

## What Is Ready

- Windows baseline reports are identified.
- WSL benchmark artifacts are isolated under `benchmarks/wsl-local-inference-benchmark`.
- Host preflight is recorded.
- Linux-side preflight script is ready.
- Generic OpenAI-compatible TTFT/decode calibration helper is ready.
- OpenCode-to-WSL OpenAI-compatible runner is ready and dry-run validated.
- The distro install/preflight wrapper is ready and read-only validated.

## Blocker

No WSL distribution exists. The requested ROCm vs Vulkan and host/runtime comparisons require installing or selecting a WSL2 distro before any Linux-side device, runtime, or benchmark evidence can be gathered.

## Resume Criteria

Resume the goal after explicit approval to install/select a distro, preferably Ubuntu 24.04 for the current AMD Ryzen WSL ROCm path.
