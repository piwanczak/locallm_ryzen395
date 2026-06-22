# LM Studio Optimization Summary 02 - Vulkan Tuning Results

## Goal Of This Phase

- Improve Qwen3-Coder 30B speed using LM Studio's stable Vulkan backend.
- Keep the same model and same local API workflow.
- Avoid risky system changes while testing reversible runtime flags.

## Main Successful Changes

- Reduced context length from the huge default-like value to `8192`.
- Reduced parallelism from `4` to `1` for single-stream decode.
- Forced GPU offload with `--gpu max`.
- Enabled flash attention:
  - `LLAMA_ARG_FLASH_ATTN=on`
- Used quantized KV cache:
  - `LLAMA_ARG_CACHE_TYPE_K=q4_0`
  - `LLAMA_ARG_CACHE_TYPE_V=q4_0`
- Added scheduling/polling tuning:
  - `LLAMA_ARG_PRIO=2`
  - `LLAMA_ARG_POLL=100`

## Best Known Reload Command

The reusable script is:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\reload-qwen30b-fast.ps1
```

It reloads:

- `qwen/qwen3-coder-30b`
- Context `8192`
- Parallel `1`
- GPU max
- Flash attention
- Q4 KV cache
- Priority/poll flags

## Measured Improvements

- Initial API wall speed: about `40.5 tok/s`.
- Initial LM Studio internal speed: about `45.37 tok/s`.
- Q4 tuned Vulkan, clean API wall-clock runs: about `59.8-60.3 tok/s` in earlier measurements.
- Best internal observed tuned Vulkan speed: about `64.8 tok/s`.
- N-gram speculative on a favorable counting prompt reached about `65.2 tok/s`, but was prompt-dependent.

## Things That Helped

- Reducing context size helped avoid paying overhead for unused context.
- Parallel `1` matched the actual single-stream goal better than parallel `4`.
- Flash attention and Q4 KV cache were the main meaningful LM Studio-side speed knobs.
- Keeping the Vulkan backend selected was important because it was stable and faster than ROCm in tested conditions.

## Things That Did Not Help Enough

- Context `2048` did not produce a meaningful additional speedup beyond the `8192` setup.
- CPU-MoE experiments did not improve speed.
- Windows `Performance` power plan did not produce meaningful gains and was reverted to the original `Standard` plan.
- `LLAMA_ARG_BATCH=4096` and `LLAMA_ARG_UBATCH=1024` only produced a small immediate variation:
  - Known-good quick run: `53.62 tok/s`
  - Batch/ubatch quick run: `55.96 tok/s`
  - This was not enough to justify changing the main reload script.

## Speculative Decoding Tests

- `ngram-simple` speculative decoding:
  - Could help on repetitive or predictable prompts.
  - Not reliable enough as a general 3x solution.
- `draft-mtp`:
  - Measured around `59.9 tok/s`.
  - No meaningful improvement over tuned Vulkan.
- External draft model attempts:
  - Qwen3 0.6B as draft via direct llama-server was slower, around `39.7 tok/s`.
  - Qwen2.5 draft was not vocabulary-compatible.

## Failure Or Limitation

- Vulkan tuning produced a real improvement, but not 3x.
- Approximate improvement from API baseline:
  - From `40.5 tok/s` to roughly `60 tok/s`.
  - About `1.48x`.
- Approximate improvement from internal baseline:
  - From `45.37 tok/s` to about `64.8 tok/s`.
  - About `1.43x`.

## Outcome For This Chunk

- Vulkan is currently the best working runtime.
- The stable improvement is real, but the 3x target remains unmet.
- Further LM Studio flag tuning appears unlikely to deliver another 2x by itself.
