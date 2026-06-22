# Phase 00 Preflight Report

Date: 2026-06-21

## Scope

This phase records the machine constraints relevant to WSL2 local inference before promoting any runtime or agent workflow.

## Evidence

| Area | Evidence | Finding |
| --- | --- | --- |
| WSL | `../results/20260621-205116-preflight/host-preflight.json` and later WSL checks | WSL2 is available and `Ubuntu-24.04` is installed |
| GPU | host preflight plus WSL `rocminfo` | AMD Radeon 8060S is exposed to ROCm in WSL as `gfx1151` |
| WSL RAM | `free -h`, `/proc/meminfo` in WSL preflight | About `60 GiB` RAM plus `16 GiB` swap |
| HIP | `../results/20260621-210721-hip-smoke/hip-smoke.out` | HIP vector-add smoke passed |
| Vulkan | `../results/20260621-210633-linux-preflight/vulkaninfo-summary.out` | Vulkan currently exposes Mesa `llvmpipe` CPU only |
| Docker | Windows PATH checks at preflight time | Docker, Podman, and nerdctl were not available during this initial preflight |

## Constraint

The WSL memory cap is not comparable to Windows runs that could use roughly 128 GB-class system RAM. Short-context throughput and 8k agent tests are still valid. Long-context and heavy-concurrency results must be labeled WSL-memory-capped unless the WSL cap is raised or swept.

## Decision

Use WSL2 Ubuntu 24.04 plus ROCm/ROCDXG as the primary WSL acceleration path. Do not promote WSL Vulkan until a GPU Vulkan ICD is actually visible. Docker was installed later; see `phase-11-docker-pi-validation.md` for the updated container evidence.
