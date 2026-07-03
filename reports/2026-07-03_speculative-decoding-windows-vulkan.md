# Windows Vulkan Draft-Model Speculative Decoding

Date: 2026-07-03

## Conclusion

A small local speculative-decoding lane is real on this machine, but it is
narrow. The useful implementation is stock llama.cpp `draft-simple` on Windows
Vulkan, not JetSpec itself.

Best results from the latest local runs:

| Target | Draft | Mode | DraftN | Base generation tok/s | Speculative generation tok/s | Speedup | Result |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| Qwen2.5-Coder 7B Q8_0 | Qwen2.5-Coder 0.5B Q8_0 | `draft-simple` | 3 | 28.90 | 64.80 | 2.24x | strongest scoped result |
| Qwen3-8B Q4_K_M | Qwen3-0.6B Q4_K_M | `draft-simple` | 2 | 42.40 | 54.80 | 1.29x | promoted Qwen3 verification |
| Qwen3-8B Q4_K_M | Qwen3-0.6B Q4_K_M | three-prompt matrix | 2 | 42.03 | 52.83 | 1.26x | broader Qwen3 check |
| Qwen3 Coder 30B Q4_K_M | Qwen3-0.6B or larger drafts | `draft-simple` | 1+ | mixed | mixed | <1.00x | not useful |

The result does not change the promoted default coding stack. Qwen3 Coder 30B
Q4 remains the better default local coding-agent profile. The speculative lane
is best treated as a separate fast-completion profile for smaller dense models.

## What Was Tested

Runtime and host shape:

- Windows AMD/Vulkan setup on a Ryzen AI Max / Radeon 8060S class machine.
- llama.cpp Vulkan build `b9728-fabde3bf5`.
- Physical RAM inventory: 128 GiB installed.
- During the Qwen3 run, Windows reported about 31.6 GiB visible system RAM,
  consistent with a large VGM/UMA reservation.
- llama.cpp Vulkan saw the Radeon 8060S device with about 114507 MiB total and
  108782 MiB free at the start of the Qwen2.5-Coder pass.

Qwen2.5-Coder result:

| Mode | Median prompt tok/s | Median generation tok/s |
| --- | ---: | ---: |
| Base Qwen2.5-Coder 7B Q8_0 | 613.00 | 28.90 |
| 7B target + 0.5B draft | 553.50 | 64.80 |

The same Qwen2.5-Coder pair also worked as a temporary llama.cpp server
endpoint. A smoke request completed at 48.25 predicted tok/s with speculative
telemetry `draft_n=58` and `draft_n_accepted=43`.

Qwen3 promoted verification:

| Variant | Rep 1 | Rep 2 | Rep 3 | Median generation tok/s | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| `base` | 42.00 | 42.40 | 42.60 | 42.40 | 1.00x |
| `draft-simple` | 54.80 | 54.00 | 54.80 | 54.80 | 1.29x |
| `draft-simple-fast` | 54.70 | 54.70 | 55.50 | 54.70 | 1.29x |

Qwen3 three-prompt matrix:

| Prompt | Base median generation tok/s | Best speculative median generation tok/s | Best speedup |
| --- | ---: | ---: | ---: |
| Coding validator module | 41.70 | 54.80 | 1.31x |
| Repetitive validator continuation | 42.20 | 51.10 | 1.21x |
| Refactor/explanation coding task | 42.20 | 52.60 | 1.25x |

Aggregate over the three prompt medians: 42.03 tok/s base to 52.83 tok/s best
speculative, or 1.26x.

Qwen3 quality matrix, using deterministic answer mode and a mechanical task
rubric:

| Prompt | Base quality | `draft-simple` quality | `draft-simple-fast` quality | Exact speculative match vs base |
| --- | ---: | ---: | ---: | ---: |
| Coding validator module | 100.0% | 100.0% | 100.0% | 0/2 |
| Repetitive validator continuation | 89.5% | 89.5% | 89.5% | 2/2 |
| Refactor/explanation coding task | 90.0% | 90.0% | 90.0% | 2/2 |

Median automated quality stayed 90.0% for base and both speculative variants.
Exact output matched base in 4 of 6 speculative comparisons. The two
non-identical outputs were on the coding validator task, where both speculative
variants still scored 100.0% on the rubric.

## Negative Results

Separate-model speculation did not help the already-fast Qwen3 Coder 30B MoE
profile:

- Qwen3 Coder 30B Q4 target + Qwen3-0.6B Q8 draft, `DraftN=1`: 66.00 tok/s
  base vs 62.30 tok/s speculative.
- Qwen3 Coder 30B Q4 target + Qwen3-1.7B Q4 draft: slower in smoke tests.
- Qwen3 Coder 30B Q4 target + Qwen3 Coder 30B Q2 draft: much slower in smoke
  tests.
- n-gram speculative variants slowed both the normal coding prompt and a
  deliberately repetitive validator prompt.
- Windows runtime knobs such as `--poll 0`, `-sm none`, microbatch changes, and
  KV cache quantization were at most noise-level improvements for Qwen3 Coder
  and did not explain the Qwen3-8B speedup.

## Relation To JetSpec

The comparison target was JetSpec: Breaking the Scaling Ceiling of Speculative
Decoding with Parallel Tree Drafting, arXiv:2606.18394.

Public JetSpec claims include up to 9.64x on MATH-500 and 4.58x on open-ended
chat, with optimized vLLM/CUDA-style serving and trained causal parallel draft
heads. The public JetSpec repository also reports high token throughput on
B200-class NVIDIA hardware.

This local work should not be described as a JetSpec port. It does not include:

- a trained JetSpec draft head,
- causal parallel tree drafting,
- custom Triton tree attention,
- CUDA graphs,
- or vLLM JetSpec serving integration.

What it does validate is the same operational constraint under a much simpler
Windows AMD/Vulkan stack: speculative decoding only helps when draft execution
is cheap enough and acceptance is high enough. The Qwen2.5-Coder and Qwen3-8B
lanes passed that test. Qwen3 Coder 30B did not.

Sources:

- https://arxiv.org/abs/2606.18394
- https://github.com/hao-ai-lab/JetSpec
- https://github.com/JetSpec-project/vllm-jetspec

## Novelty Assessment

This is not novel as an algorithm. Draft-model speculative decoding and
JetSpec-style tree drafting are public research and implementation areas.

The potentially useful public contribution is narrower: a measured Windows
AMD/Vulkan llama.cpp field report with both positive and negative model-pair
results. In the public material checked during review, there was no obvious
matching report for this exact profile:

- Windows AMD/Vulkan llama.cpp,
- Qwen2.5-Coder 7B Q8_0 + Qwen2.5-Coder 0.5B Q8_0 at 2.24x,
- Qwen3-8B Q4_K_M + Qwen3-0.6B Q4_K_M at 1.26-1.29x,
- quality checked with a small deterministic rubric,
- and Qwen3 Coder 30B negative cases included.

That makes it worth publishing if framed as practical field evidence, not as a
new method and not as a full JetSpec implementation.

## Reproduction Notes

Public harness and prompts are in `benchmarks/speculative-decoding/`.

Example Qwen3 sweep:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\benchmarks\speculative-decoding\scripts\run-qwen3-windows-spec-sweep.ps1 -Reps 3
```

Example Qwen2.5-Coder sweep:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\benchmarks\speculative-decoding\scripts\run-llamacpp-spec-benchmark.ps1 -Reps 3 -Tokens 128
```

Raw result directories, downloaded models, runtime binaries, and local logs are
excluded from the public repository. The published values above are curated
medians from the local raw runs.

## Validity Limits

- The Qwen3 quality scorer is heuristic and task-specific. It catches obvious
  regressions but is not a human preference evaluation.
- The Qwen2.5-Coder result is a speed proof, not yet a full coding-agent quality
  validation.
- The Qwen3 matrix uses small public prompts and deterministic decode settings;
  larger real-usage tasks may show different acceptance and overhead behavior.
- The Qwen3 Coder 30B negative result is important: a speculative draft can be
  technically valid and still slower than base decode on a fast MoE target.
