param(
  [string]$RocmRoot = "$PSScriptRoot\..\downloads\amd-hip-sdk\admin-extract\Program Files 64\AMD\ROCm\7.1"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path $RocmRoot
$clang = Join-Path $root "bin\clang++.exe"
$hipcc = Join-Path $root "bin\hipcc.exe"
$tmp = Join-Path $env:TEMP "codex-rocm-build-probe"

New-Item -ItemType Directory -Force -Path $tmp | Out-Null

$cpp = Join-Path $tmp "hello.cpp"
$exe = Join-Path $tmp "hello.exe"
$hip = Join-Path $tmp "hello.hip"
$hipExe = Join-Path $tmp "hello-hip.exe"

@"
#include <cstdio>
int main() {
  std::puts("hello");
  return 0;
}
"@ | Set-Content -LiteralPath $cpp -Encoding ASCII

@"
#include <hip/hip_runtime.h>
#include <cstdio>
int main() {
  int count = 0;
  hipError_t err = hipGetDeviceCount(&count);
  if (err != hipSuccess) {
    std::printf("hip error: %s\n", hipGetErrorString(err));
    return 2;
  }
  std::printf("devices=%d\n", count);
  return 0;
}
"@ | Set-Content -LiteralPath $hip -Encoding ASCII

$results = @()

foreach ($probe in @(
  @{ Name = "clang++ cpp"; Exe = $clang; Args = @($cpp, "-o", $exe) },
  @{ Name = "hipcc hip"; Exe = $hipcc; Args = @($hip, "-o", $hipExe) }
)) {
  Push-Location $tmp
  try {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & $probe.Exe @($probe.Args) 2>&1
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
    Pop-Location
  }

  $results += [pscustomobject]@{
    Probe = $probe.Name
    ExitCode = $exitCode
    Output = ($output | Out-String)
  }
}

$results
