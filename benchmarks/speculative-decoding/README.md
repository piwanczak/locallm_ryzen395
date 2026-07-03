# Speculative Decoding Benchmark

Purpose: test low- to medium-risk speculative decoding paths that can speed up
local inference on a Windows AMD/Vulkan setup.

This is not a full JetSpec implementation. It uses stock llama.cpp
`draft-simple` drafting, then checks whether the same practical condition from
JetSpec holds locally: the draft path must be cheap enough and accepted often
enough to beat verifier overhead.

## Current Public Summary

See `../../reports/2026-07-03_speculative-decoding-windows-vulkan.md`.

Promoted local Windows Qwen3 result:

- target: Qwen3-8B Q4_K_M
- draft: Qwen3-0.6B Q4_K_M
- runtime: llama.cpp Vulkan b9728
- speculative mode: `draft-simple`
- draft depth: `--spec-draft-n-max 2`
- verified decode: 42.40 tok/s base to 54.80 tok/s speculative, 1.29x
- three-prompt matrix: 42.03 tok/s base to 52.83 tok/s best speculative, 1.26x
- quality matrix: median automated quality stayed 90.0% for base and
  speculative variants; exact output matched base in 4 of 6 comparisons

Strongest scoped result:

- target: Qwen2.5-Coder 7B Q8_0
- draft: Qwen2.5-Coder 0.5B Q8_0
- mode: `draft-simple`, `--spec-draft-n-max 3`
- median decode: 28.90 tok/s base to 64.80 tok/s speculative, 2.24x

Negative result:

- Qwen3 Coder 30B Q4 did not improve with the tested separate draft models.
- n-gram speculative variants slowed down in the tested Qwen3 prompts.

## Included

- `scripts/run-llamacpp-spec-benchmark.ps1`: small target/draft benchmark used
  for the Qwen2.5-Coder 7B + 0.5B lane.
- `scripts/run-llamacpp-spec-benchmark.mjs`: Node variant of the same basic
  benchmark shape.
- `scripts/run-qwen3-windows-spec-sweep.ps1`: Qwen3 sweep over base,
  draft-simple, and related variants.
- `scripts/score-qwen3-quality.mjs`: deterministic heuristic scorer for the
  Qwen3 quality prompts.
- `prompts/`: small public prompts used by the summarized runs.

## Excluded

Raw `results/`, model downloads, llama.cpp runtime binaries, and local logs are
not included in this public slice. The scripts write raw outputs under
`benchmarks/speculative-decoding/results/`, which is intentionally ignored.

## Example Run

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\benchmarks\speculative-decoding\scripts\run-qwen3-windows-spec-sweep.ps1 -Reps 3
```

Provide explicit `-LlamaCli`, `-Model`, and `-Draft` paths when reproducing
outside the original local layout.

Promote a conclusion only after comparing base and speculative runs on the same
prompt, model, runtime, context, and token budget.
