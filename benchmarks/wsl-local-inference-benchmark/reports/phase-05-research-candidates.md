# Phase 05 Research Candidate Report

Date: 2026-06-21

## Source Inputs

| Source | Used For |
| --- | --- |
| Vicki Boykis, `Running local models is good now`, 2026-06-15, https://vickiboykis.com/2026/06/15/running-local-models-is-good-now/ | Practical local-agent pattern: Pi harness, LM Studio endpoint, Docker isolation, Gemma/GPT-OSS/Qwen model candidates |
| Pi docs, containerization, https://pi.dev/docs/latest/containerization | Docker isolation patterns for running Pi inside a container |
| Pi docs, custom models, https://pi.dev/docs/latest/models | OpenAI-compatible provider and `baseUrl` model config shape |
| AMD ROCm Ryzen WSL guide, https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/wsl/howto_wsl.md | WSL ROCm/ROCDXG as the supported Linux-on-Windows compute path for this machine |
| Microsoft WSL install docs, https://learn.microsoft.com/en-us/windows/wsl/install | WSL2 install and distro selection baseline |
| Saved reading list, `%USERPROFILE%\Downloads\local_llm_recommended_reading.html` | Local inference topics: memory bandwidth, GGUF quantization, KV cache, batching, vLLM/PagedAttention, llama.cpp, ROCm, Vulkan, Strix Halo |

## Extracted Ideas

The article's useful pattern is not "copy the exact Mac setup." It is the shape of the workflow: run a local OpenAI-compatible inference server, run an agent harness against it, isolate agent execution in Docker, and keep the model/runtime knobs inspectable.

The saved reading list points to the same pressure points seen in the benchmark: KV cache and context size consume memory quickly, quantization matters more than headline parameter count, batching and continuous scheduling matter for multi-request throughput, and backend selection must be measured on the actual hardware.

## Model Candidates

| Candidate | Status On This Machine | Why Keep It |
| --- | --- | --- |
| `Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf` | Available and benchmarked | Quality-default local coding model after passing code and protected frontend tasks |
| `Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf` | Available and benchmarked | Throughput fallback; passed controlled edit tasks under WSL ROCm |
| Gemma 4 E4B Q4 | Available but blocked on this runtime | AMD llama.cpp `b8407` fails to load the local artifact because the architecture is `gemma4` |
| GPT-OSS 20B-style candidate | Not locally available in this run | Article calls out this family as a step-change for local usefulness |
| Qwen2.5-Coder 1.5B Q4/Q8 | Available and benchmarked | Useful latency controls; both failed the basic edit task with syntax-invalid edits |
| Mistral 7B class | Not locally available in this run | Cheap control model to separate harness failures from model size/quality |

Do not download a large model blindly. The next useful model addition is not another tiny control; it is either a runtime-supported Gemma-family artifact or a mid-size coding model that can plausibly pass the edit fixtures.

## Runtime Candidates

| Runtime | Current Decision | Reason |
| --- | --- | --- |
| WSL2 llama.cpp ROCm/HIP | Promote as current runtime baseline | HIP smoke passed, llama.cpp server works, and Qwen3 Coder Q2 reached `70.20 tok/s` single-request decode estimate |
| Windows LM Studio | Keep as Windows control | Article pattern uses LM Studio; prior Windows results are already recorded in the journal |
| WSL2 llama.cpp Vulkan | Reject for now | WSL Vulkan currently sees Mesa `llvmpipe` CPU, not the AMD GPU |
| Ollama | Candidate only after explicit install/availability | Simple OpenAI-compatible baseline, but backend/device path must be measured |
| vLLM | Research candidate, not first implementation target | Reading list highlights PagedAttention and batching, but ROCm-on-WSL compatibility and model support need separate proof |
| Pi in Docker | Build-validated, agent edit blocked | Correct isolation shape; base/browser images build, but Pi did not execute Qwen/llama.cpp tool-call-shaped text |

## Agent Candidates

| Agent/Harness | Current Decision | Reason |
| --- | --- | --- |
| Controlled edit-agent runner | Current default | Passed small edit and protected frontend fixture with verifiers |
| OpenCode | Keep as realism benchmark | Found real context/tool-loop failure modes; not reliable enough as default here |
| Pi Docker runner | Container harness candidate, not default | Matches the article's Docker-isolated shape, but needs executable tool-call compatibility before it can replace the controlled runner |
| Browser verification | Keep as explicit promotion gate | The protected `browser-style` workflow passed both Node verifier and in-app browser checks |

## Memory Position

WSL is configured around `65 GB`, which appears as about `60 GiB` inside Linux. That is enough for the current 11.3 GB Qwen3 Coder Q2 GGUF, an 8k llama.cpp context, the controlled agent harness, and simple browser verification.

It is not enough to treat WSL as equivalent to the Windows 128 GB-class runs. Long-context tests, larger quants, larger batch counts, and multi-agent/browser/container runs should be labeled WSL-memory-capped unless the cap is raised or swept.

Recommended memory policy:

- Keep `65 GB` for the 30B Q2 WSL ROCm baseline because it removes memory pressure from the first stable profile.
- Test `48 GiB` next if the goal is to find a practical daily cap for the same model.
- Test `32 GiB` only for smaller models or Pi-only harness work.
- Do not spend time above `65 GB` until a larger quant, longer context, or higher concurrency run actually needs it.
