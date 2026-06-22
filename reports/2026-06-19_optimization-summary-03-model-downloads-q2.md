# LM Studio Optimization Summary 03 - Model Downloads And Q2 Quantization

## Goal Of This Phase

- Test whether a smaller quantization of the same Qwen3-Coder 30B family could improve speed.
- Keep the target model family at Qwen3-Coder 30B rather than switching to a small unrelated model.
- Repair the failed/corrupted LM Studio proxy download by downloading directly from Hugging Face.

## Direct Hugging Face Download

- Target model:
  - `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF`
  - File: `Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf`
- The LM Studio proxy partial was corrupted/incomplete.
- The corrupt partial was removed.
- The model was downloaded directly from Hugging Face and imported into LM Studio.

## Verified Q2 File

- Final LM Studio model path:
  - `%USERPROFILE%\.lmstudio\models\unsloth\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf`
- Size:
  - `11,258,612,896` bytes
- SHA256:
  - `6db9853d31fdb928a731666c9d44e8cdebf52f62f4810cb0908c6c677e6c84b5`
- LM Studio indexed it as:
  - `unsloth/qwen3-coder-30b-a3b-instruct`

## Q2 Benchmark Results

- Q2 with Q4 KV:
  - About `52.58 tok/s`
- Q2 with default KV:
  - About `64.87 tok/s`
- Q2 with default KV plus `ngram-simple`:
  - About `67.46 tok/s` on a favorable counting prompt
- Coding-style prompt test:
  - `88` tokens in `2.582` seconds
  - About `34.08 tok/s`
  - This was likely dominated by short-output overhead and not representative of long decode throughput.

## Interpretation

- Q2 reduced memory use substantially.
- Q2 did not produce a reliable speed win over tuned Q4 Vulkan.
- On this AMD Vulkan path, memory footprint was not the only bottleneck.
- The faster-looking Q2 + n-gram result was prompt-dependent and not a general solution.

## Smaller Model Controls

- Smaller models were tested only as controls or draft helpers.
- Qwen2.5-Coder 1.5B could reach around `97 tok/s`.
- This proved the stack can go faster on small models, but it does not satisfy the target because the goal is Qwen3-Coder 30B.

## Failure Or Limitation

- Q2 did not unlock the 3x target.
- The lower quantization can be useful for memory headroom, but not as the main speed answer.
- The best Q2 numbers were close to tuned Q4, not dramatically ahead.

## Outcome For This Chunk

- Direct Hugging Face download problem was solved.
- Corrupted partial file was removed.
- Q2 model is available and verified.
- Q2 is not the recommended performance path for the target workload.
