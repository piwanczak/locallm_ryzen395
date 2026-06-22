# Optimization Summary 09 - Direct Draft Checks And Final Throughput

## Scope

- Target model: `qwen/qwen3-coder-30b`, Q4_K_M GGUF.
- This chunk documents the final remaining local setting checks:
  - real draft-model speculative decoding
  - REST advanced-key probing
  - CLI environment override probing
  - final restored throughput verification

## Tooling Added

- Added `tools/benchmark-direct-llama-server.ps1`.
- It starts a direct bundled `llama-server.exe` on port `1235`, runs one benchmark request, then stops the process.

## Draft Model Result

- Target:
  - Qwen3-Coder 30B Q4_K_M
  - 4 active experts
  - Vulkan 2.22 direct backend
- Draft:
  - Qwen3 0.6B Q4_K_M
  - `draft-simple`
- Result:
  - no-draft direct control: `51.51 tok/s` wall-clock, `66.97 tok/s` internal decode
  - Qwen3 0.6B draft: `31.54 tok/s` wall-clock, `42.54 tok/s` internal decode
- The draft model accepted many tokens, about `273 / 363`, but the draft work cost more than it saved.

## REST And CLI Checks

- LM Studio REST rejected lower-level keys:
  - `cache_type_k`
  - `cache_type_v`
  - `priority`
  - `poll`
- CLI environment override check did not apply the useful MoE override:
  - attempted `LLAMA_ARG_OVERRIDE_KV=qwen3moe.expert_used_count=int:4`
  - LM Studio reported the loaded model as `num_experts = 8`
  - benchmark was only `49.78 tok/s`

## Final Applied Profile

- LM Studio is currently restored to:
  - model: `qwen/qwen3-coder-30b`
  - quantization: Q4_K_M
  - context: `8192`
  - eval batch: `2048`
  - physical batch: `512`
  - parallel: `4`
  - flash attention: enabled
  - active experts: `4`
  - KV cache offload: enabled

Restore command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\reload-qwen30b-rest.ps1 -Model 'qwen/qwen3-coder-30b' -NumExperts 4 -Parallel 4 -ContextLength 8192
```

## Verified Speed

- Fresh restored-state single request:
  - `65.79 tok/s`
- Fresh restored-state four concurrent requests:
  - `136.59 tok/s`
- Baselines:
  - original API wall-clock: about `40.5 tok/s`
  - older internal decode: about `45.37 tok/s`
- Final aggregate ratios:
  - `136.59 / 40.5 = 3.37x`
  - `136.59 / 45.37 = 3.01x`

## Conclusion

- The current setup reaches the requested 3x level as aggregate server throughput.
- It does not reach 3x for a single interactive answer.
- The fastest practical current profile is a throughput profile:
  - Q4_K_M
  - 4 active experts
  - 4 parallel slots
  - 8192 context
- Further single-request improvement likely requires a newer/custom backend or better AMD runtime support.
