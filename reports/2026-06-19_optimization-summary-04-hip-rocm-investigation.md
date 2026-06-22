# LM Studio Optimization Summary 04 - HIP And ROCm Investigation

## Goal Of This Phase

- Determine whether AMD HIP/ROCm can outperform Vulkan enough to approach the 3x target.
- Use official AMD and LM Studio paths where possible.
- Avoid permanent driver/system changes unless clearly necessary.

## Official Hardware Support Finding

- AMD documentation lists Ryzen AI Max+ 395 as supported for Windows HIP SDK.
- The relevant architecture is:
  - RDNA3.5
  - LLVM target `gfx1151`
- This made HIP/ROCm the most plausible remaining path toward a large speedup.

## AMD HIP SDK Download

- AMD's EULA page was inspected.
- The EULA was found to be a normal POST form.
- Submitting the form with `curl.exe` and cookies returned a real installer URL:
  - `https://download.amd.com/developer/eula/rocm-hub/AMD-Software-PRO-Edition-26.Q1-Win11-For-HIP.exe`
- Downloaded installer:
  - `downloads/amd-hip-sdk/AMD-Software-PRO-Edition-26.Q1-Win11-For-HIP.exe`
- Size:
  - `1,754,164,768` bytes
  - About `1.634 GiB`
- Authenticode signature:
  - Valid
- Product metadata:
  - `AMD Software: PRO Edition`
  - Product version `25.30.02.01`

## Full Installer Attempts

- Running the official installer with `-install -log`:
  - Exited with code `1`.
  - Did not produce the requested log.
  - Extracted payloads to `<amd-software-installer-cache>`.
- A narrow MSI install script was prepared:
  - `tools/install-rocm-sdk-msis.ps1`
- The elevated install step was canceled, so the narrow MSI installation was not performed.

## Administrative Extraction

- MSI administrative extraction was explored to avoid full system install.
- Non-elevated extraction failed with:
  - MSI `1603`
  - Internal sequence errors `2502` and `2503`
- Elevated administrative extraction succeeded for:
  - `ROCm_SDK_Core.msi`
  - `ROCm_Libs_RT.msi`
- Extracted local ROCm tree:
  - `downloads/amd-hip-sdk/admin-extract/Program Files 64/AMD/ROCm/7.1`

## Local HIP Validation

- `hipconfig.exe` from the extracted SDK reported:
  - HIP version `7.1.51803-d3a86bd04`
- `amdgpu-arch.exe` reported:
  - `gfx1151`
- `hipInfo.exe` successfully detected:
  - `AMD Radeon(TM) 8060S Graphics`
  - About `50.37 GB` total global memory
  - `gfx1151`
- This proved that HIP itself can see the GPU from the extracted local SDK tree.

## Standalone llama.cpp HIP Tests

- Official llama.cpp b9716 HIP Radeon package was downloaded and extracted.
- Official llama.cpp b9601 HIP Radeon package was also downloaded and extracted.
- b9716 HIP tools:
  - Hung before usable output, including `--help`.
- b9601 HIP tools:
  - With bundled DLLs: hung.
  - With local ROCm 7.1 runtime ahead in PATH: crashed early with access violation `0xC0000005`.
- Standalone HIP binaries were therefore not usable for benchmarking.

## LM Studio ROCm Runtime

- LM Studio runtime manager was checked.
- Available AMD runtime found:
  - `llama.cpp-win-x86_64-amd-rocm-avx2@2.22.0`
- It was downloaded successfully through LM Studio.
- It was selected successfully.
- LM Studio hardware survey then reported:
  - `AMD Radeon(TM) 8060S Graphics (ROCm, Integrated)`
  - `50.37 GiB` VRAM
- Qwen3-Coder 30B loaded successfully under this ROCm runtime.

## ROCm Benchmark Results In LM Studio

- ROCm stable runtime with fast Vulkan-style flags:
  - First run: about `23.22 tok/s`
  - Second run: about `20.29 tok/s`
- ROCm stable runtime with default KV/cache flags:
  - About `22.93 tok/s`
- These results were much slower than tuned Vulkan.

## Beta ROCm Runtime

- LM Studio listed a beta runtime:
  - `llama.cpp-win-x86_64-amd-rocm-avx2@2.23.0`
- Attempt to download/select/test it was rejected by the user/admin prompt.
- It remains untested.

## Outcome For This Chunk

- HIP/ROCm support on this machine is real at the SDK/device level.
- LM Studio's stable ROCm backend can load the target model.
- Stable ROCm was slower than Vulkan for Qwen3-Coder 30B in tested conditions.
- The main successful result was integration and validation, not speed.
- Vulkan was restored after ROCm testing.
