param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$MaxTokens = 320,
  [string]$Prompt = "Count from 1 to 200, separated by spaces. Output only the numbers.",
  [int]$Samples = 7,
  [int]$SampleIntervalSeconds = 2,
  [switch]$UniquePrompt
)

$ErrorActionPreference = "Stop"

$cwdPath = (Get-Location).Path
$benchmarkScript = Join-Path $cwdPath "tools\benchmark-lmstudio-chat.ps1"
$adlProbe = Join-Path $cwdPath "tools\adl-readonly-probe.exe"
$toolchainBin = Join-Path $cwdPath "downloads\build-tools\llvm-mingw-20260616-ucrt-x86_64\bin"

if (-not (Test-Path -LiteralPath $benchmarkScript)) {
  throw "Benchmark script not found: $benchmarkScript"
}
if (-not (Test-Path -LiteralPath $adlProbe)) {
  throw "ADL probe not found: $adlProbe"
}
if (Test-Path -LiteralPath $toolchainBin) {
  $env:PATH = "$toolchainBin;$env:PATH"
}

function Get-Adapter0Telemetry {
  $out = & $adlProbe
  $match = $out | Select-String -Pattern "^\[adapter 0\]" | Select-Object -First 1
  if (-not $match) {
    return $out
  }

  $start = [Math]::Max(0, $match.LineNumber - 1)
  $end = $out.Count - 1
  for ($j = $start + 1; $j -lt $out.Count; $j++) {
    if ($out[$j] -match "^\[adapter ") {
      $end = $j - 1
      break
    }
  }
  $out[$start..$end] | Where-Object {
    $_ -match "^(observed_core_clock|observed_memory_clock|dedicated_vram_usage_MB|shared_vram_usage_MB|speed_|odn_|od8_|pmlog_CLK_GFXCLK|pmlog_CLK_MEMCLK|pmlog_CLK_SOCCLK|pmlog_GFX_POWER|pmlog_ASIC_POWER|pmlog_TEMPERATURE_GFX|pmlog_TEMPERATURE_SOC|pmlog_THROTTLE|throttle_)"
  }
}

"ADL_IDLE_SAMPLE:"
Get-Adapter0Telemetry

$bench = Start-Job -ArgumentList $cwdPath, $benchmarkScript, $BaseUrl, $Model, $MaxTokens, $Prompt, $UniquePrompt.IsPresent -ScriptBlock {
  param($dir, $script, $baseUrl, $model, $maxTokens, $prompt, $uniquePrompt)
  Set-Location $dir
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $script,
    "-BaseUrl",
    $baseUrl,
    "-Model",
    $model,
    "-MaxTokens",
    $maxTokens,
    "-Prompt",
    $prompt
  )
  if ($uniquePrompt) {
    $args += "-UniquePrompt"
  }
  powershell.exe @args | Out-String
}

Start-Sleep -Seconds 1
for ($i = 0; $i -lt $Samples; $i++) {
  "ADL_LOAD_SAMPLE=$i"
  Get-Adapter0Telemetry
  Start-Sleep -Seconds $SampleIntervalSeconds
}

"BENCHMARK:"
Receive-Job -Job $bench -Wait -AutoRemoveJob
