# GLM-5.1 IQ2_XXS Local Benchmark Retry

Date: 2026-06-30 Europe/Warsaw

## Verdict

GLM-5.1 was retried with a single shared GGUF download instead of duplicate
Ollama or LM Studio imports. The shared artifact route works: llama.cpp b9728
can load the first split shard directly from `downloads/` and can produce a
small visible response when automatic Vulkan fitting and `--reasoning off` are
used.

It is not practical for the current full benchmark suite on this machine. The
model is larger than physical RAM, partial Vulkan fitting leaves most work on
CPU/mmap paging, and the full real-usage matrix timed out every task before any
model output was returned.

## Shared Artifact

Local directory:

```text
downloads/glm-5.1/bartowski-zai-org_GLM-5.1-GGUF/IQ2_XXS/
```

First shard path:

```text
downloads/glm-5.1/bartowski-zai-org_GLM-5.1-GGUF/IQ2_XXS/zai-org_GLM-5.1-IQ2_XXS-00001-of-00006.gguf
```

Shard verification:

| Shard | Bytes | Match |
| --- | ---: | --- |
| `00001` | `39354271744` | yes |
| `00002` | `39198005216` | yes |
| `00003` | `39198005216` | yes |
| `00004` | `39198005216` | yes |
| `00005` | `39995634368` | yes |
| `00006` | `6985802720` | yes |

Total: `203929724480` bytes, about `189.92 GiB`.

Post-download `C:` free space: `135378202624` bytes, about `126.10 GiB`.

## Runtime Gate

Machine/runtime observations:

- Physical RAM: `132766306304` bytes, about `123.63 GiB`.
- llama.cpp device log: Radeon 8060S Vulkan device with about `64033 MiB`
  free at load time.
- Runtime: `downloads/llama-vulkan/b9728-vulkan/llama-server.exe`.
- Alias: `glm-5.1-iq2-xxs`.
- The model was loaded directly from the shared shard path.

Smoke results:

| Route | Result |
| --- | --- |
| CPU-only mmap, `-ngl 0`, `512` ctx | Loaded, but one-token chat returned empty content with `finish_reason=length`; logs showed template `thinking = 1`. |
| Forced Vulkan, `-ngl 999` | Failed during load with Vulkan out-of-device-memory. |
| Automatic fit, `512` ctx, `--reasoning off` | Passed: response `OK` in `28.549s`; prompt eval about `0.59 tok/s`, decode about `1.27 tok/s`. |

The full-suite server used automatic fitting with:

```text
-c 16384 -np 1 --no-warmup --cache-ram 0 -t 12 -tb 12 -fa off --reasoning off
```

Known runtime warnings:

- `special_eot_id` and `special_eom_id` are not in `special_eog_ids`.
- llama.cpp reported unused `blk.78.*` tensors.
- The server warned that tensor overrides to CPU were used with mmap enabled.
- The GLM chat template emitted repeated `render_message_to_json` warnings.

## Real-Usage Matrix

Run:

- Runner: `ollama-direct-api:llama-vulkan-glm51-iq2xxs`
- Base URL: `http://127.0.0.1:8091/v1`
- Model: `glm-5.1-iq2-xxs`
- Tasks: full 7-task direct API suite
- Attempts: `1`
- Context: `16384`
- Max tokens: `4096`
- Task timeout: `300000 ms`

Result: `0/7` passed.

Every task reached the model-call timeout with `0` output characters. Prompt
estimates ranged from `689` to `1425` tokens, which is consistent with the
observed smoke throughput being too slow for a 300s task budget.

| Task | Prompt token estimate | Output chars | Elapsed |
| --- | ---: | ---: | ---: |
| `backend-api` | `1302` | `0` | `300244.5 ms` |
| `schema-validation` | `1089` | `0` | `300183.4 ms` |
| `frontend-filter` | `1425` | `0` | `300140.8 ms` |
| `multi-file-cart` | `1175` | `0` | `300203.2 ms` |
| `cli-report` | `1011` | `0` | `300348.9 ms` |
| `failing-command-recovery` | `689` | `0` | `309230.0 ms` |
| `sandbox-canary` | `823` | `0` | `300240.3 ms` |

Safety checks:

- No files were modified by the model.
- No allowlist or protected-file violations were reported.
- Canary remained unchanged on every task.

Reports:

- [Real-usage rollup](../benchmarks/real-usage-agent-benchmark/reports/2026-06-30-glm51-iq2xxs-real-usage-rollup.md)
- [Raw matrix summary](../public-results/results-summary.md)

## Kebab Benchmark

The Kebab runner was updated to accept a custom OpenAI-compatible provider so it
could use the same shared llama.cpp server without importing the model into
another runtime cache.

Run:

- Provider: `llama-vulkan`
- Base URL: `http://127.0.0.1:8091/v1`
- Model: `glm-5.1-iq2-xxs`
- Context: `8192`
- Max tokens: `8192`
- Timeout: `1800s`

Result:

- Status: failed.
- Runner error: `fetch failed`.
- Server had begun decoding and reached about `207` decoded tokens at roughly
  `1.05 tok/s` before the client-side failure/cancel.
- Output chars: `0`.
- Automatic code feature score: `2/8`, from the empty placeholder HTML.
- Screenshot render completed for the placeholder artifact.

Reports:

- [Kebab report](../benchmarks/kebab-benchmark/reports/2026-06-30-glm51-iq2xxs-kebab.md)
- [Kebab summary JSON](../public-results/results-summary.md)

## Operational Notes

- [Preflight](../public-results/results-summary.md)
- [Shared download](../public-results/results-summary.md)
- [Runtime smoke](../public-results/results-summary.md)

## Conclusion

Do not promote GLM-5.1 `IQ2_XXS` on this hardware as a practical local benchmark
runner. The single shared artifact approach is the right storage model, but the
model is too large for the current RAM/VRAM balance and produces no useful
full-suite output under the established task timeouts.

If GLM-5.1 is revisited locally, the next useful change should be a materially
different memory/runtime setup, not another duplicate cache import. A smaller
quant may fit disk more comfortably, but `IQ1_S` is still about `147.30 GiB` and
would trade quality down while remaining above physical RAM.
