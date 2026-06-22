# Optimization Summary 08 - Parallel Throughput Profile

## Scope

- Target model: `qwen/qwen3-coder-30b`, Q4_K_M GGUF.
- This chunk documents server-throughput tuning after the 4-expert speed profile.
- The main question was whether 3x could be reached by LM Studio settings without switching to a smaller model.

## Tooling Added

- Added `tools/benchmark-lmstudio-chat-concurrent.ps1`.
- It sends concurrent `/v1/chat/completions` requests and reports aggregate wall-clock tokens/sec.

## Best Applied Profile

- Model: `qwen/qwen3-coder-30b`
- Quantization: Q4_K_M
- Context: `8192`
- Eval batch: `2048`
- Physical batch: `512`
- Flash attention: enabled
- KV cache offload: enabled
- Experts: `4`
- Parallel slots: `4`

Restore command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\reload-qwen30b-rest.ps1 -Model 'qwen/qwen3-coder-30b' -NumExperts 4 -Parallel 4 -ContextLength 8192
```

## Results

- Original API wall-clock baseline:
  - about `40.5 tok/s`
- Best prior single-request 4-expert profile:
  - about `70-72 tok/s`
- Final profile, single request:
  - `66.21 tok/s` in the final restored-state check
- Final profile, four concurrent requests:
  - `132.87 tok/s` in the final restored-state check
  - another repeat sagged to `121.04 tok/s`
- Observed four-way aggregate range:
  - about `121-133 tok/s`

## Interpretation

- The server can now exceed 3x the original API wall-clock baseline as aggregate throughput.
- It does not produce one answer at 3x the original speed.
- The cleanest statement is:
  - single response: about `1.6-1.75x` over baseline
  - four concurrent responses: about `3.0-3.3x` over baseline, with some variability

## Failed Or Inferior Paths

- Q2_K 30B did not help:
  - 4 experts, parallel 1: `70.69-72.89 tok/s`
  - 4 experts, parallel 4: `104.24 tok/s`
  - 3 experts: slower and malformed output
- Full 8-expert quality mode with parallel 4:
  - `90.88 tok/s`
  - not enough for 3x
- Parallel 5:
  - `116.25 tok/s`
  - worse than parallel 4
- Context 4096:
  - `131-133 tok/s`
  - similar to 8192, not enough benefit to justify reducing context
- Context 2048:
  - `123.27 tok/s`
  - worse
- `ngram-simple` speculative decoding was tested earlier with the direct backend and accepted zero draft tokens, so it did not help.

## Current State

- LM Studio is currently loaded with the best practical profile:
  - Q4_K_M
  - 8192 context
  - 4 experts
  - 4 parallel slots
- This is the strongest verified throughput setting found so far without installing a new backend or changing to a smaller model.

## Remaining Limit

- True 3x single-request speed was not achieved.
- Reliable 3x over the older internal decode baseline would require about `136.1 tok/s`; the observed aggregate range is close but not consistently above that.
- Further progress likely needs backend-level changes rather than more LM Studio setting tweaks.
