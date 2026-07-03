# DS4 ROCm MTP OOM Analysis

Date: 2026-07-01

## Summary

The base+MTP pair can run full-residency on this Windows 96 GB VGM setup, but
the original load/session order left too little contiguous ROCm allocation
headroom.

Fixes applied:

- Prepare the MTP model cache before the base model cache.
- For MTP preload on Windows ROCm, bypass the secondary-model fd staging path
  and copy from the mapped file directly.
- For `ds4-server` ROCm+MTP full-residency, default `--prefill-chunk` to `64`
  unless explicitly set or overridden with `DS4_ROCM_MTP_SERVER_PREFILL_CHUNK`.
- Pass `-PrefillChunk` through the Windows ROCm wrapper for CLI/server runs, not
  only benchmark runs.

Verified working server command shape:

```powershell
.\build\ds4\winprobe\ds4-server-rocm-win.exe --rocm `
  -m .\downloads\ds4\DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf `
  --mtp .\downloads\ds4\DeepSeek-V4-Flash-MTP-Q4K-Q8_0-F32.gguf `
  --mtp-draft 2 --host 127.0.0.1 --port 18081 -c 1024 -n 16
```

The rebuilt server now applies `--prefill-chunk 64` automatically for that
ROCm+MTP full-residency case.

## Evidence

### Failure modes

- `logs/ds4-rocm-win-bench-20260701-121140.log`
  - Base was prepared first: `80.76 GiB`.
  - MTP then failed on `tensor-span:2 (1152.00 MiB): out of memory`.
  - Interpretation: a large non-splittable MTP span was being allocated after
    the base model had fragmented the remaining VGM.
- `logs/ds4-mtp-server-bg-20260701-202629-ctx1024.err.log`
  - With MTP-first load but server default prefill, base+MTP loaded.
  - Session creation failed after `context buffers 102.14 MiB`.
  - Interpretation: server ctx1024 defaulted prefill scratch to 1024 rows,
    exceeding remaining headroom.

### Passing validation

- `benchmarks/ds4-mtp-windows-rocm/results/20260701-oom-analysis/mtp-draft1-pf1-ctx64-gen32-mtpfirst-direct.csv`
  - `ctx64`: prefill `15.09 tok/s`, decode `15.91 tok/s`.
- `benchmarks/ds4-mtp-windows-rocm/results/20260701-oom-analysis/mtp-draft2-strict-pf1-ctx64-gen32-mtpfirst-direct.csv`
  - strict draft-2: prefill `15.13 tok/s`, decode `14.94 tok/s`.
- `benchmarks/ds4-mtp-windows-rocm/results/20260701-oom-analysis/mtp-draft2-strict-defaultpf-ctx64-gen32-mtpfirst-direct.csv`
  - strict draft-2 default benchmark prefill: prefill `46.03 tok/s`, decode
    `14.44 tok/s`.
- `benchmarks/ds4-mtp-windows-rocm/results/20260701-oom-analysis/mtp-draft2-strict-defaultpf-ctx64-alloc1024-gen8-mtpfirst-direct.csv`
  - allocated ctx1024 benchmark: prefill `47.83 tok/s`, decode `14.96 tok/s`.
- `logs/ds4-mtp-server-bg-20260701-203115-ctx1024-pf64.err.log`
  - Server with `--prefill-chunk 64` loaded MTP `3.55 GiB`, then base
    `80.76 GiB`.
  - Session context buffers fell to `35.28 MiB`.
  - Server reached `listening on http://127.0.0.1:18081`.
  - `/v1/models` returned HTTP 200.
  - `/v1/completions` returned HTTP 200 for a one-token request; log showed
    `9.57 t/s` for that single token.
- Rebuild:
  - `tools/ds4-windows-local-rocm-build.ps1 -BuildServer` completed and linked
    the ROCm CLI and server. Existing Microsoft-extension warnings remain.

## Current Interpretation

The OOM was not one single allocator failure.

1. MTP cache allocation was ordered poorly for this memory topology. Loading the
   base first consumed and fragmented most of the VGM; loading MTP first gives
   the large MTP tensor spans their best chance to land.
2. The Windows fd-backed staged loader is not reliable for the secondary MTP
   model when MTP is loaded first. Direct mmap copy avoided the early
   `model range read failed` / `unspecified launch failure` path.
3. Server sessions need lower prefill scratch than the benchmark path on this
   machine. At ctx1024, default prefill scratch was `102.14 MiB` and failed;
   `--prefill-chunk 64` reduced it to `35.28 MiB` and passed.

## Remaining Limits

- MTP did not improve decode throughput in these small probes. Base no-MTP
  ctx64 previously measured about `16.29 tok/s`; strict draft-2 MTP was
  `14.44-14.96 tok/s`.
- Larger server contexts are not proven. ctx1024 is validated; ctx2048+ should
  be treated as a new memory experiment.
- Pinned staging OOM lines are still present during base preload. In these runs
  they were nonfatal fallback messages, not the terminal failure.
- The real-usage suite was not rerun after the server fix in this pass. The
  API smoke test proves server startup and one-token completion only.
