# Optimization Summary 13 - Custom Build Gate

## Scope

- Target model: `qwen/qwen3-coder-30b`, Q4_K_M GGUF.
- This chunk documents whether a custom local backend build is feasible with tools already present on the machine.

## Findings

- Found:
  - Git
  - extracted ROCm/HIP compiler components, including `clang`, `clang++`, `clang-cl`, and `hipcc`
- Not found:
  - CMake
  - Ninja
  - MSVC `cl`
  - `vswhere.exe`
  - Visual Studio install directories
- Added `tools/probe-rocm-clang-build.ps1` and ran actual compile probes.
- ROCm `clang++` failed because it could not find Visual Studio or standard C++ header `cstdio`.
- ROCm `hipcc` failed because it could not find standard C++ headers `cmath` and `cstdlib`.

## Interpretation

- A custom llama.cpp build is not ready with the current local toolchain.
- The missing dependency is not just CMake/Ninja; a Windows C++ standard-library/build environment is absent too.
- The remaining single-response 3x path requires an external-state change:
  - install/download CMake and Ninja or Visual Studio Build Tools
  - install/update Windows C++ SDK pieces
  - possibly update AMD driver/runtime pieces

## Current Best State

- Runtime: LM Studio Vulkan `2.22.0`
- Model: Qwen3-Coder 30B Q4_K_M
- Context: `8192`
- Experts: `4`
- Parallel slots: `4`
- Latest restored single-response check:
  - `69.28 tok/s`
- Latest aggregate range:
  - about `130+ tok/s`

## Conclusion

- The normal local runtime/settings matrix is exhausted.
- Aggregate 3x is achieved.
- Single-response 3x is not achieved and is gated on installing/building/testing a newer backend or changing AMD runtime/driver state.
