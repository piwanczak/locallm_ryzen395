# Optimization Summary 07 - Expert Count Speed Profile

## Scope

- Target model: `qwen/qwen3-coder-30b`, Q4_K_M GGUF.
- This chunk documents MoE expert-count tuning.
- The objective is speed, but quality was sanity-checked because reducing experts can degrade the model.

## Key Finding

- Qwen3-Coder 30B is a MoE model with metadata key:
  - `qwen3moe.expert_used_count`
- Default active experts:
  - `8`
- LM Studio's REST load endpoint exposes this as:
  - `num_experts`

## Tooling Added

- Added `tools/reload-qwen30b-rest.ps1`.
- Speed profile command:
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\reload-qwen30b-rest.ps1 -NumExperts 4`
- Full/default expert command:
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\reload-qwen30b-rest.ps1 -NumExperts 8`

## Results

- Full restored 8-expert Vulkan state:
  - about `54-56 tok/s`
- 4 experts:
  - direct backend second run: `72.46 tok/s`
  - LM Studio REST run: `67.62 tok/s`
  - reusable helper run: `70.49 tok/s`
  - simple coding prompt produced correct code
- 3 experts:
  - `75.93-78.01 tok/s`
  - simple coding prompt produced malformed and logically wrong code
- 2 experts:
  - up to `84.25 tok/s`
  - output was visibly broken
- 1 expert:
  - server returned a parse/server error with garbled generated text

## Current State

- Current loaded LM Studio profile:
  - `qwen/qwen3-coder-30b`
  - context `8192`
  - parallel `1`
  - flash attention enabled
  - KV cache offloaded to GPU
  - `num_experts = 4`
- Latest verified speed:
  - `70.49 tok/s`

## Improvement

- Compared with original API baseline:
  - from about `40.5 tok/s` to `70.49 tok/s`
  - about `1.74x`
- Compared with restored full 8-expert profile:
  - from `56.17 tok/s` to `70.49 tok/s`
  - about `1.25x`
- Compared with the temporary slow regression:
  - from about `18 tok/s` to `70.49 tok/s`
  - about `3.9x`

## Limits

- This is not a true 3x improvement over the original baseline.
- It is a speed/quality tradeoff.
- The lower expert-count tests show quality falls apart quickly below 4 experts.

## Next Plan

- Keep 4 experts as the speed-oriented current profile.
- Use 8 experts when quality matters.
- Continue looking for backend-level improvements for AMD `gfx1151`, because expert-count reduction alone does not reach the original 3x target.
