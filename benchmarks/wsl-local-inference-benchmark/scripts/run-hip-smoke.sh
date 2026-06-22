#!/usr/bin/env bash
set -euo pipefail

stamp="$(date +%Y%m%d-%H%M%S)"
out_dir="${1:-benchmarks/wsl-local-inference-benchmark/results/$stamp-hip-smoke}"
mkdir -p "$out_dir"

export HSA_ENABLE_DXG_DETECTION="${HSA_ENABLE_DXG_DETECTION:-1}"

cat > "$out_dir/hip-smoke.cpp" <<'CPP'
#include <hip/hip_runtime.h>

#include <cstdio>
#include <cstdlib>

__global__ void add_kernel(const float* a, const float* b, float* c, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < n) {
    c[i] = a[i] + b[i];
  }
}

static void check(hipError_t err, const char* what) {
  if (err != hipSuccess) {
    std::fprintf(stderr, "%s: %s\n", what, hipGetErrorString(err));
    std::exit(1);
  }
}

int main() {
  int device_count = 0;
  check(hipGetDeviceCount(&device_count), "hipGetDeviceCount");
  std::printf("device_count=%d\n", device_count);
  if (device_count < 1) {
    return 2;
  }

  hipDeviceProp_t props{};
  check(hipGetDeviceProperties(&props, 0), "hipGetDeviceProperties");
  std::printf("device_name=%s\n", props.name);
  std::printf("gcn_arch=%s\n", props.gcnArchName);
  std::printf("total_global_mem=%zu\n", static_cast<size_t>(props.totalGlobalMem));

  constexpr int n = 1024;
  constexpr size_t bytes = n * sizeof(float);
  float host_a[n];
  float host_b[n];
  float host_c[n];
  for (int i = 0; i < n; ++i) {
    host_a[i] = static_cast<float>(i);
    host_b[i] = static_cast<float>(2 * i);
  }

  float* dev_a = nullptr;
  float* dev_b = nullptr;
  float* dev_c = nullptr;
  check(hipMalloc(&dev_a, bytes), "hipMalloc a");
  check(hipMalloc(&dev_b, bytes), "hipMalloc b");
  check(hipMalloc(&dev_c, bytes), "hipMalloc c");
  check(hipMemcpy(dev_a, host_a, bytes, hipMemcpyHostToDevice), "copy a");
  check(hipMemcpy(dev_b, host_b, bytes, hipMemcpyHostToDevice), "copy b");

  add_kernel<<<(n + 255) / 256, 256>>>(dev_a, dev_b, dev_c, n);
  check(hipGetLastError(), "kernel launch");
  check(hipDeviceSynchronize(), "kernel sync");
  check(hipMemcpy(host_c, dev_c, bytes, hipMemcpyDeviceToHost), "copy c");

  for (int i = 0; i < n; ++i) {
    float expected = static_cast<float>(3 * i);
    if (host_c[i] != expected) {
      std::fprintf(stderr, "mismatch at %d: got %.1f expected %.1f\n", i, host_c[i], expected);
      return 3;
    }
  }

  check(hipFree(dev_a), "hipFree a");
  check(hipFree(dev_b), "hipFree b");
  check(hipFree(dev_c), "hipFree c");
  std::printf("hip_smoke=pass\n");
  return 0;
}
CPP

{
  echo "$ hipcc $out_dir/hip-smoke.cpp -O2 -o $out_dir/hip-smoke"
  hipcc "$out_dir/hip-smoke.cpp" -O2 -o "$out_dir/hip-smoke"
  echo "$ $out_dir/hip-smoke"
  "$out_dir/hip-smoke"
} > "$out_dir/hip-smoke.out" 2> "$out_dir/hip-smoke.err"

echo "$out_dir"
