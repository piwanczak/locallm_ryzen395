# Local LLM Ryzen 395 Results

Public journal-style notes, benchmark summaries, and reusable harnesses from local inference experiments on a Ryzen AI Max+ 395 / Radeon 8060S class Windows + WSL2 machine.

The current practical headline is narrow: Qwen3 Coder 30B Q4 is viable at a 16k configured context window for the tested controlled WSL ROCm lane, Pi Docker tool-call validation, Docker-controlled tasks, OpenCode thin-prompt tasks, and Windows LM Studio controlled tasks. These are small verifier-backed workflows, not a claim that all 16k-agent workloads are solved.

## What Is Interesting Here

- Ryzen AI Max+ 395 / Radeon 8060S can run Qwen3 Coder 30B Q4 as a practical local coding model across several host paths: Windows LM Studio Vulkan, Windows LM Studio ROCm, WSL2 ROCm/ROCDXG llama.cpp, Docker-controlled runners, Pi, and OpenCode.
- Windows LM Studio reached the original 3x speed goal only as warmed `parallel=4` aggregate throughput. Strict single-request latency did not improve by 3x.
- Modern Standby / platform power state can invalidate benchmarks: ADL PMLog showed the iGPU pinned near `600 MHz` despite high utilization, and the fast path returned only after real wake/power-state recovery.
- The advertised/native 256k-class context is loadable in some profiles, but not practically interactive here. The documented LM Studio ladder found 32k as the usable long-context target; 196k took about 80.5 minutes before generation.
- WSL2 ROCm/ROCDXG plus AMD's llama.cpp ROCm build became the best Linux path. WSL Vulkan was present but exposed Mesa `llvmpipe` CPU instead of the AMD GPU in this setup.
- Pi tool-call execution worked only after serving Qwen through llama.cpp with `--jinja` and keeping a local Qwen tool-call reminder. Without that endpoint format, Pi saw tool-call-shaped text but did not execute it.
- Smaller models and lower quantization were useful controls, but verifier-backed tasks repeatedly favored Qwen3 Coder 30B Q4 over faster small-model candidates.
- Gemma 4 E4B is included as an experimental Windows LM Studio high-context lane. It is not the default recommendation and is not the same as a true Gemma 4 12B result.


## What Is Novel vs Known

Known background: AMD documents the Ryzen AI Max+ 395 as a 16-core Zen 5 APU with Radeon 8060S graphics, up to 128GB LPDDR5x, and up to 126 total TOPS; AMD also documents ROCm-on-WSL setup for Radeon/Ryzen systems. Qwen documents Qwen3 Coder 30B as a long-context, tool-capable coding model. Those facts are not novel by themselves.

What this repo adds is a concrete field report on how those pieces behaved together on one Ryzen AI Max+ 395 machine: WSL2 ROCm/ROCDXG vs WSL Vulkan, Windows LM Studio Vulkan/ROCm profiles, Pi/Docker/OpenCode runner behavior, verifier-backed 16k coding tasks, high-context practical limits, and the power-state failure mode that pinned the iGPU near `600 MHz`. Treat the novelty as operational evidence and reproducible harness work, not as a new benchmark standard or model-quality claim.

Useful external baselines:

- AMD Ryzen AI Max+ 395 specifications: <https://www.amd.com/en/products/processors/laptop/ryzen/ai-300-series/amd-ryzen-ai-max-plus-395.html>
- AMD ROCm on Radeon/Ryzen documentation: <https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/>
- Qwen3 Coder 30B model card: <https://huggingface.co/Qwen/Qwen3-Coder-30B-A3B-Instruct>
- Long-context coding cautionary evidence: <https://arxiv.org/abs/2602.16069>

## Evidence Policy

The repo keeps the journal feel: chronological reports remain available even when later reports supersede them. Treat the newest dashboard and phase reports as the current state.

To make the summaries auditable without publishing large local state, this public repo includes selected Markdown reports, harness source, and promoted result summary JSON/probe artifacts when they are small and non-sensitive. It still excludes downloaded model files, extracted runtimes, raw server logs, large prompt dumps, generated build trees, local caches, and machine-specific binary output.

Any paths in commands are examples. Replace `<you>` with your Windows user name and run commands from the repository root, for example:

```powershell
cd "$env:USERPROFILE\Documents\locallm_ryzen395-public"
```

## Current Limitations

- This is a single-machine field report, not a general benchmark of all Ryzen AI Max systems.
- Many claims are workload-specific and verifier-specific. Controlled runner passes are not equivalent to broad autonomous coding-agent reliability.
- 16k was not rerun as a 10-run soak under a 32GB WSL cap.
- Large product-scale frontend work, simultaneous agents, and long-context Pi/OpenCode runs remain untested.
- Chronological reports may contain intermediate blocked states; later phase reports supersede earlier blocked/setup notes.
