# WSL2 Benchmark Matrix

Created: 2026-06-21

This matrix is the next-run checklist for comparing WSL2 hosts against the existing Windows journal results.

## Phase 0 - Inventory

| Check | Evidence | Pass Condition |
| --- | --- | --- |
| WSL installed | `wsl.exe --status` | PASS: default version is `2` |
| Distro present | `wsl.exe -l -v` | PASS: `Ubuntu-24.04`, WSL version `2` |
| Linux kernel | `uname -a` in WSL | PASS: `6.18.33.1-microsoft-standard-WSL2` |
| WSL memory | `free -h`, `/proc/meminfo` | INFO: about `60 GiB` RAM plus `16 GiB` swap; not comparable to Windows 128 GB-class RAM runs |
| GPU device exposure | `/dev/dxg`, `/dev/dri`, `/dev/kfd` | PASS: `/dev/dxg` exists |
| ROCm tools | `rocminfo`, `hipconfig`, `rocm-smi` | PASS: installed; `rocminfo` sees `gfx1151` / Radeon 8060S |
| HIP execution | `scripts/run-hip-smoke.sh` | PASS: vector-add kernel ran on `AMD Radeon(TM) 8060S Graphics` |
| Vulkan tools | `vulkaninfo --summary` | PARTIAL: installed, but only `llvmpipe` CPU is visible |
| Runtime binaries | `llama-server`, `llama-cli`, `llama-bench` | PASS: AMD validated ROCm llama.cpp binary installed |
| Model location | explicit path or host-managed model id | Same quant/model family as Windows where practical |

Current status: WSL2 + Ubuntu 24.04 + ROCm/ROCDXG are working. AMD's validated ROCm llama.cpp binary serves Qwen3 Coder 30B Q2 successfully. Docker/Pi remains blocked by missing Docker/Podman/nerdctl on Windows PATH.

## Phase 1 - Runtime Smoke

| Candidate | Backend | Host | Context | Settings | First Test |
| --- | --- | --- | ---: | --- | --- |
| `wsl-llamacpp-vulkan-8k-qwen` | Vulkan | direct `llama-server` | `8192` | flash attention on, Qwen 4 experts if supported | BLOCKED: WSL Vulkan currently CPU-only |
| `wsl-llamacpp-rocm-4k-qwen` | ROCm/HIP | AMD llama.cpp `b8407` | `4096` | flash attention on, default slots | PASS: single and 4-way OpenAI-compatible smoke |
| `wsl-llamacpp-rocm-8k-qwen` | ROCm/HIP | AMD llama.cpp `b8407` | `8192` | flash attention on, `--parallel 1` | PARTIAL: OpenCode solved `js-window`, but did not terminate |
| `wsl-ollama-qwen` | best available | Ollama | host default | only if already installed or explicitly approved | OpenAI-compatible smoke if API compatible |
| `wsl-other-host-qwen` | documented | selected host | `8192` | one or two knobs only | OpenAI-compatible smoke |

Record:

- server command and exact binary path.
- runtime build/version.
- visible GPU/backend device.
- WSL memory cap and `free -h` output.
- context, batch, ubatch, parallel/slots, flash attention, KV cache type, prompt cache flags.
- TTFT, first byte, first content, decode estimate, total wall time.
- stderr/server timing rows.
- GPU memory and process memory if available.

## Phase 2 - Short Throughput

Run single and 4-way aggregate requests where the host supports it. Compare to Windows:

| Windows Reference | Value |
| --- | ---: |
| LM Studio ROCm beta `2.23.0`, Qwen 4 experts, single | `51.73 tok/s` |
| LM Studio ROCm beta `2.23.0`, Qwen 4 experts, 4-way aggregate | `109.64 tok/s` |
| LM Studio Vulkan `2.22.0`, Qwen 4 experts, restored single | `69.62 tok/s` |
| LM Studio Vulkan `2.22.0`, Qwen 4 experts, restored 4-way aggregate | `130.18 tok/s` |
| Later Windows throughput profile reference | `167.62 tok/s` aggregate |

Measured WSL ROCm llama.cpp smoke on `2026-06-21`:

| WSL Candidate | Context | Shape | Result |
| --- | ---: | --- | ---: |
| `wsl-llamacpp-rocm-4k-qwen` | `4096` | single, 128 completion tokens | `70.20 tok/s`, first content `752.9 ms` |
| `wsl-llamacpp-rocm-4k-qwen` | `4096` | 4-way, 128 completion tokens each | `84.65 tok/s` aggregate, about `21.16 tok/s` per stream |

Promotion guidance:

- A WSL backend that is slower than Windows Vulkan but more stable may still be useful for direct llama.cpp flags.
- A WSL backend that is slower than Windows ROCm is rejected unless it enables a unique feature needed by long-context testing.
- Any WSL long-context result above 32k must be labeled memory-capped under the current 60 GiB WSL RAM limit and not compared directly to Windows 128 GB-class runs.

## Phase 3 - OpenCode Calibration

Use the existing disposable OpenCode benchmark fixture, starting with `js-window`.

Minimum first pass:

| Candidate | Task | Prompt Mode | Context Band | Promote If |
| --- | --- | --- | --- | --- |
| WSL Qwen ROCm 4k | `js-window` | thin, no padding | 4k | REJECT: OpenCode context overflow, no fixture edit |
| WSL Qwen ROCm 8k | `js-window` | thin, no padding | 8k | PARTIAL: fixture edit passed verifier; reject promotion until termination/tool loop is fixed |
| viable WSL Gemma | `js-window` | thin, no padding | 16k | pass, clean shell behavior |

Record whether OpenCode resends full context after each tool call and whether the WSL server exposes prompt-cache hits.

## Phase 4 - Fuller Suite

Run the fuller suite only after a candidate passes runtime and `js-window` gates.

Tasks:

- `python-ledger`
- `java-slug`
- `js-window`
- `web-retrieval`
- `browser-style`

Stop early if:

- first task loops longer than the timeout,
- the server crashes,
- a candidate attempts denied external directories, package installs, live web search, destructive commands, or unsafe git operations,
- canary changes.
