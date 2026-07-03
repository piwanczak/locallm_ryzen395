# DS4 Windows-Native MTP Redo

Date: 2026-07-03

## Conclusion

This redo was Windows-native only. No WSL runner was used for build, load, or
benchmark validation.

The current Windows ROCm setup can load the compatible DeepSeek V4 Flash base
GGUF plus the public MTP sidecar with full model residency after the OOM fixes:

- Base: `downloads/ds4/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf`
- MTP: `downloads/ds4/DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf`
- Benchmark exe: `build/ds4/winprobe/ds4-bench-rocm-win.exe`

MTP is now genuinely running, not just loading. The metric run accepted 32
generated tokens in 14 speculative decode steps with average acceptance `2.29`.
However, MTP did not improve decode throughput on this machine and build. It
was materially slower than base-only:

| Run | ctx | gen | prefill tok/s | decode tok/s | decode steps | accepted tokens | avg accept |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Base, no MTP | 64 | 32 | 13.29 | 14.62 | 32 | 32 | 1.00 |
| Base + MTP draft=2 | 64 | 32 | 45.25 | 7.74 | 14 | 32 | 2.29 |

Current answer to "does MTP increase decode TPS here?": no. It works and
accepts drafts, but verifier/MTP overhead dominates the saved base decode
steps in this Windows ROCm path.

## Hypotheses

1. With 96 GB VGM configured, Windows-native DS4 should avoid the previous MTP
   OOM if the MTP sidecar is cached before the base model and if the Windows
   secondary-model staging path is bypassed.
2. MTP should increase decode TPS only if draft acceptance offsets the extra
   verifier and sidecar execution cost.

The first hypothesis validated for the small full-residency benchmark shape.
The second did not validate.

## Windows-Native Plan and Gates

1. Toolchain gate: install or discover Visual Studio C++ tools, Windows SDK,
   HIP SDK, hipBLAS, hipBLASLt, and rocWMMA headers.
2. Runtime gate: compile and run a local HIP smoke test against the Windows
   ROCm runtime.
3. Build gate: compile a DS4 ROCm benchmark executable on Windows.
4. OOM gate: load MTP first, then the base model, with both resident.
5. MTP gate: run speculative decode with acceptance metrics.
6. Benchmark gate: compare base-only and MTP draft-2 using the local benchmark
   prompt and CSV output.

## Implementation

Durable wrapper changes:

- `tools/ds4-windows-native-bootstrap.ps1`
  - Added Windows-native bootstrap switches for DS4 source, VS Build Tools, HIP
    SDK, and MTP download.
- `tools/extract-rocm-sdk-msis.ps1`
  - Normalized paths before MSI administrative extraction. This fixed the local
    extraction path failure caused by literal `..\` segments.
- `tools/ds4-windows-native-preflight.ps1`
  - Added system MSVC and Windows SDK discovery.
  - Added local ROCm and rocWMMA header discovery.
  - Accepted Windows HIP SDK `.dll.a` import libraries for hipBLAS and
    hipBLASLt.
- `tools/ds4-windows-local-rocm-build.ps1`
  - Added installed ROCm/MSVC/SDK discovery.
  - Linked the actual Windows ROCm import libraries.
  - Used local rocWMMA headers when the HIP SDK extraction did not include them.
  - Added Windows-safe ROCm build flags and a benchmark-only build path.

Local DS4 source changes under `build/ds4/`:

- `ds4.c`
  - Prepares the MTP cache before the base cache.
  - On Windows ROCm, loads the MTP sidecar from mapped bytes instead of using
    the secondary fd staging path.
  - Uses a Windows-compatible snapshot temp file path where `fmemopen` is not
    available.
- `ds4_bench.c`
  - Added `--mtp`, `--mtp-draft`, and `--mtp-margin`.
  - Added speculative decode metrics: `decode_steps`, `accepted_tokens`, and
    `avg_accept`.
- `ds4_server.c`
  - Uses `prefill_chunk=64` by default for ROCm+MTP unless explicitly
    overridden.
- `build/ds4/wincompat/`
  - Added local Windows shims for pthread, mmap, unistd, stat, file locking,
    and related POSIX calls needed by the benchmark build.

## Toolchain Validation

Preflight command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\ds4-windows-native-preflight.ps1 -RunHipSmoke -ModelPath .\downloads\ds4\DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf
```

Result:

- DS4 source tree found.
- Base GGUF found.
- Local ROCm root found at
  `downloads/amd-hip-sdk/admin-extract/Program Files 64/AMD/ROCm/7.1`.
- MSVC `cl.exe`, `link.exe`, and Windows SDK include/lib paths found.
- HIP, hipBLAS, hipBLASLt, hipcub, rocprim, and rocWMMA headers found.
- `amdhip64`, hipBLAS, and hipBLASLt import libraries found.
- HIP smoke compiled and ran: `hip smoke value=42`.

The full AMD HIP SDK installer exited nonzero on this machine, but MSI
administrative extraction provided the needed Windows ROCm files. Official AMD
docs list Ryzen AI Max+ 395 / `gfx1151` support for the Windows HIP SDK, and
the AMD rocWMMA repository documents `gfx1151` support. Sources:

- [AMD HIP SDK Windows system requirements](https://rocm.docs.amd.com/projects/install-on-windows/en/latest/reference/system-requirements.html)
- [AMD HIP SDK Windows install guide](https://rocm.docs.amd.com/projects/install-on-windows/en/latest/install/install.html)
- [AMD ROCm rocWMMA repository](https://github.com/ROCm/rocWMMA)

## Build Validation

Build command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\ds4-windows-local-rocm-build.ps1 -BuildBench -ModelPath .\downloads\ds4\DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf -MtpPath .\downloads\ds4\DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf -MtpDraft 2 -ModelCopyChunkMb 8 -ModelArenaChunkMb 256
```

Result:

- Built `build/ds4/winprobe/ds4-bench-rocm-win.exe`.
- Remaining compile warnings were Microsoft-extension warnings around gotos
  bypassing initialized variables in local DS4 code. They did not block the
  benchmark executable.

## Benchmark Evidence

Benchmark directory:

- `benchmarks/ds4-mtp-windows-rocm/results/20260703-windows-native-redo/`

Prompt:

- `benchmarks/ds4-mtp-windows-rocm/prompts/repeated-english-ctx1024.txt`

Metric CSVs:

- `base-no-mtp-ctx64-gen32-metrics.csv`
- `mtp-draft2-ctx64-gen32-metrics.csv`

Rows:

```csv
ctx_tokens,prefill_tokens,prefill_tps,gen_tokens,gen_tps,decode_steps,accepted_tokens,avg_accept,kvcache_bytes
64,64,13.29,32,14.62,32,32,1.00,19220108
64,64,45.25,32,7.74,14,32,2.29,19220108
```

Earlier same-shape smoke CSVs also completed:

| Run | CSV | Result |
| --- | --- | --- |
| Base ctx64 gen8 | `base-no-mtp-ctx64-gen8.csv` | pass |
| MTP draft2 ctx64 gen8 | `mtp-draft2-ctx64-gen8.csv` | pass |
| Base ctx64 gen32 | `base-no-mtp-ctx64-gen32.csv` | pass |
| MTP draft2 ctx64 gen32 | `mtp-draft2-ctx64-gen32.csv` | pass |

## OOM Analysis

The previous OOM path was a Windows-native memory-ordering and staging problem,
not a model-pair mismatch.

Passing MTP log:

- `logs/ds4-rocm-win-bench-20260703-121444.log`

Key lines:

```text
ds4: MTP support model loaded: ...DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf (draft=2)
ds4: ROCm backend initialized on AMD Radeon(TM) 8060S Graphics (sm_115)
ds4: ROCm startup model preparation covered 3.55 GiB of tensor spans in 3.446s
ds4: ROCm startup model preparation covered 80.76 GiB of tensor spans in 49.303s
ds4-bench: context buffers 22.96 MiB (ctx=97, backend=rocm, prefill_chunk=64, raw_kv_rows=256, compressed_kv_rows=26)
```

That validates the intended allocation order: MTP first, then base. It also
shows the benchmark got past the old MTP full-residency OOM frontier.

Base-only memory pressure remains tight but nonfatal:

- `logs/ds4-rocm-win-bench-20260703-121336.log`

Key line:

```text
ds4: ROCm q8 fp16 cache budget exhausted; using q8 kernels (request=16.00 MiB cached=10.06 GiB free=5.38 GiB reserve=5.39 GiB total=107.87 GiB)
```

Interpretation:

- The critical MTP OOM was fixed by preparing the MTP cache first and using
  mapped bytes for the Windows ROCm MTP sidecar.
- The optional q8 fp16 cache still runs out of headroom and falls back to q8
  kernels. This is not a terminal OOM in the passing benchmark.
- Larger contexts and server-shaped prompts still need their own memory ladder.
  This redo validated ctx64/gen32 full-residency MTP on Windows, not a broad
  long-context deployment envelope.

## Current Recommendation

For this machine today, use base-only DS4 for decode throughput on Windows.
Keep the MTP path as a working experimental gate, not the promoted fast path.

MTP should be revisited only if one of these changes lands:

- a lower-overhead Windows ROCm MTP/verifier path,
- a smaller compatible MTP sidecar,
- a model/prompt shape with much higher draft acceptance,
- or enough extra memory headroom to enable faster auxiliary caches without
  starving base execution.

## Cleanup State

Post-run process audit found no `ds4`, `llama`, or `hip_smoke` process left
running. LM Studio and Ollama were already running on the machine and were not
started or stopped by this redo.

Local-only artifacts remain local by design:

- `build/`
- `downloads/`
- `logs/`
- benchmark `results/`
