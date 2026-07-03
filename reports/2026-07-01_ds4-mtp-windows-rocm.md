# DS4 MTP on Windows ROCm, 96 GB VGM

Date: 2026-07-01

## Conclusion

The compatible public pair is the antirez DeepSeek-V4 Flash GGUF base plus its
matching MTP GGUF:

- Base: `downloads/ds4/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf`
- MTP: `downloads/ds4/DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf`
- Source repo: <https://huggingface.co/antirez/deepseek-v4-gguf/tree/main>

The pair is structurally compatible and can be loaded together on this Windows
ROCm setup after setting VGM to 96 GB. It is not practically useful here for
normal prompts or the real-usage suite. With full base+MTP residency, ctx=64
prefill fails with ROCm OOM. The only benchmarked speculative MTP path that
completed was a tiny ctx=1 strict-verifier run, and it was slower than base:

| Run | ctx | gen tokens | decode tok/s | Result |
| --- | ---: | ---: | ---: | --- |
| Base, no MTP | 1 | 32 | 15.94 | pass |
| Base + MTP draft=2, strict verifier | 1 | 32 | 14.72 | pass, slower |
| Base, no MTP | 64 | 32 | 16.29 | pass |
| Base + MTP draft=1 | 64 | 32 | n/a | ROCm prefill OOM |
| Base + MTP draft=2 | 64 | 32 | n/a | ROCm/Tensile or prefill OOM |

Current answer to "does MTP increase decode TPS here?": no. In the only
completed like-for-like run it reduced decode throughput by about 7.7%, and
larger frontiers fail before producing TPS.

## Hypothesis

If the model and MTP file have matching architecture metadata, then DS4 should
load both on the 96 GB VGM allocation and speculative decoding should improve
decode throughput when MTP drafts are accepted.

Secondary hypothesis: the remaining failures are memory-headroom failures, not
model-pair mismatch, because the compatible pair loads while the Spark base
fails immediately on expert-count mismatch.

## Validation Plan

1. Find a model/MTP pair that agrees on architecture dimensions.
2. Patch the Windows DS4 path so the project benchmark can load `--mtp` and
   exercise the speculative decode path instead of merely loading the extra
   GGUF.
3. Validate small synthetic throughput with `ds4-bench-rocm-win.exe`.
4. Try the project real-usage benchmark through the existing OpenAI-compatible
   proxy and record whether real prompts fit.
5. Treat failures as data: reduce context, disable optional caches, and compare
   base-only against base+MTP.

## Implementation

Changed local source and wrappers:

- `build/ds4/ds4_bench.c`
  - Added `--mtp`, `--mtp-draft`, and `--mtp-margin`.
  - Passed those through `ds4_engine_options`.
  - Updated the decode loop to call `ds4_session_eval_speculative_argmax()`
    when `--mtp-draft > 1`.
  - Avoided ROCm snapshot restore on single-frontier decode runs, because
    restore failed with `unsupported session payload version`.
- `build/ds4/ds4_help.c`
  - Exposed MTP options for `ds4-bench`.
- `tools/ds4-windows-local-rocm-build.ps1`
  - Added `-BuildBench` and `-RunBench`.
  - Added benchmark run arguments for prompt, CSV, context, generation tokens,
    and prefill chunk.
- `benchmarks/ds4-mtp-windows-rocm/scripts/make-prompt.mjs`
  - Deterministic prompt generator used by the synthetic benchmark.

Build command that passed:

```powershell
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\ds4-windows-local-rocm-build.ps1 -BuildBench -ModelPath .\downloads\ds4\DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf -MtpPath .\downloads\ds4\DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf -MtpDraft 2 -ModelCopyChunkMb 8 -ModelArenaChunkMb 256
```

## Synthetic Benchmark Evidence

Prompt source:

- `benchmarks/ds4-mtp-windows-rocm/prompts/repeated-english-ctx1024.txt`

Raw CSV directory:

- `benchmarks/ds4-mtp-windows-rocm/results/20260701-local-rocm-mtp/`

Passing CSVs:

- `base-no-mtp-ctx1-gen32.csv`
- `base-no-mtp-ctx64-gen32.csv`
- `mtp-draft2-strict-noq8f16-ctx1-gen32.csv`

Important failed runs:

- `mtp-draft2-ctx64-gen32.csv`: loaded base+MTP, then crashed at ROCm/Tensile
  initialization with `bad allocation`.
- `mtp-draft2-noq8f16-ctx64-gen32.csv`: loaded base+MTP, then failed prefill
  with ROCm OOM.
- `mtp-draft2-noq8f16-ctx1-gen32.csv`: entered speculative MTP, then failed
  the production verifier with `MTP verifier failed`.
- `mtp-draft1-noq8f16-ctx64-gen32.csv`: loaded MTP at draft=1, then failed
  ctx=64 prefill with ROCm OOM.

Representative local logs:

- `logs/ds4-rocm-win-bench-20260701-112551.log`: strict MTP ctx=1 pass.
  It loaded 80.76 GiB base tensors plus 3.55 GiB MTP tensors, then logged
  repeated `mtp decode2 verifier failed, falling back to sequential` and
  `mtp spec seq accept drafted=2 accepted=3`.
- `logs/ds4-rocm-win-bench-20260701-112159.log`: MTP draft=2 ctx=64 failure,
  `ROCm compressor prefill pool launch failed: out of memory`.
- `logs/ds4-rocm-win-bench-20260701-113041.log`: MTP draft=1 ctx=64 failure,
  `ROCm routed_moe gate/up launch failed: out of memory`.

## Real-Usage Suite Evidence

The real-usage benchmark did not get a successful DS4+MTP task run. The smallest
task prompt was already too large for the full-residency MTP path.

Prompt-size probe:

| Task | Estimated prompt tokens |
| --- | ---: |
| failing-command-recovery | 688 |
| sandbox-canary | 821 |
| cli-report | 1009 |
| schema-validation | 1087 |
| multi-file-cart | 1174 |
| backend-api | 1301 |
| frontend-filter | 1423 |

Smallest actual task attempt:

- Summary:
  `benchmarks/real-usage-agent-benchmark/results/20260701-110806-ollama-ds4-mtp-cli-proxy-ctx1024-pf256-direct-matrix/ollama-direct-api-matrix-summary.json`
- Task: `failing-command-recovery`
- Context: 1024
- Prefill chunk: 256
- Max output: 256
- Result: failed after about 95 s before output.
- Stderr evidence: context buffers were only about 57 MiB, but ROCm still
  failed creating the graph runtime / prefill path after loading base+MTP.

Prior `backend-api` attempts at ctx 32768, 4096, 2048, and 1536 also failed
before useful output with `failed to allocate GPU graph runtime`.

## Compatibility Notes

Spark base plus the public antirez MTP is not compatible. The failure was:

```text
tensor mtp.0.ffn_gate_inp.weight has dim[1]=256, expected 160
```

That means the public MTP targets a 256-expert base, while the Spark GGUF used
locally is a 160-expert variant. The antirez base is the correct pair for the
public MTP file.

## Current Recommendation

Do not spend more time trying to force this full-residency MTP setup into the
real-usage suite on the current 96 GB Windows ROCm configuration. The working
envelope is too small and the strict MTP path is slower than base. Next useful
experiments would need one of:

- a smaller compatible base+MTP pair,
- a lower-memory MTP file,
- a DS4 ROCm change that avoids loading all MTP tensors resident with the base,
- or a larger effective VRAM budget than this machine exposes under Windows.
