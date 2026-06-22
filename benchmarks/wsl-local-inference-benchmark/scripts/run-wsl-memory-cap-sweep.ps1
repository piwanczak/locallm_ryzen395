param(
  [string]$Distro = "Ubuntu-24.04",
  [string[]]$MemoryCaps = @("65GB", "48GB", "32GB"),
  [string]$Model = "qwen3-coder-30b-q4",
  [int]$AgentContextSize = 8192,
  [int]$ThroughputContextSize = 4096,
  [int]$ThroughputParallel = 4,
  [int]$ThroughputConcurrency = 4,
  [switch]$Apply,
  [switch]$ConfirmWslShutdown,
  [switch]$ConfirmWslConfigWrite
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not $Apply) {
  Write-Output "Dry run only. Re-run with -Apply -ConfirmWslShutdown -ConfirmWslConfigWrite to edit .wslconfig and restart WSL."
}

if ($Apply -and (-not $ConfirmWslShutdown -or -not $ConfirmWslConfigWrite)) {
  throw "Refusing to run. The memory sweep requires -Apply -ConfirmWslShutdown -ConfirmWslConfigWrite."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-memory-cap-sweep"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
$backupPath = Join-Path $runRoot "wslconfig-before.txt"
$summaryPath = Join-Path $runRoot "memory-cap-sweep-summary.json"

$hadExistingConfig = Test-Path -LiteralPath $wslConfigPath
$existingConfig = if ($hadExistingConfig) {
  Get-Content -Raw -LiteralPath $wslConfigPath
} else {
  ""
}
Set-Content -LiteralPath $backupPath -Value $existingConfig -Encoding UTF8

$rows = @()

foreach ($memoryCap in $MemoryCaps) {
  $row = [ordered]@{
    memoryCap = $memoryCap
    status = "planned"
    memoryProbe = $null
    agentRun = $null
    throughputRun = $null
    error = $null
  }

  try {
    if ($Apply) {
      $config = @"
[wsl2]
memory=$memoryCap
swap=16GB
"@
      Set-Content -LiteralPath $wslConfigPath -Value $config -Encoding ASCII
      & wsl.exe --shutdown
      if ($LASTEXITCODE -ne 0) {
        throw "wsl.exe --shutdown failed with exit code $LASTEXITCODE"
      }
      Start-Sleep -Seconds 5

      $probePath = Join-Path $runRoot "$memoryCap-wsl-memory-probe.txt"
      $probeOutput = & wsl.exe --distribution $Distro -- bash -lc "printf 'free -h\n'; free -h; printf '\nfree -b\n'; free -b; printf '\nmeminfo\n'; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo"
      if ($LASTEXITCODE -ne 0) {
        throw "WSL memory probe failed at memory cap $memoryCap with exit code $LASTEXITCODE"
      }
      $probeOutput | Set-Content -LiteralPath $probePath -Encoding UTF8
      $row.memoryProbe = $probePath

      $agentOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "run-wsl-model-matrix.ps1") `
        -Distro $Distro `
        -Models $Model `
        -ContextSize $AgentContextSize `
        -Parallel 1 `
        -CalibrationConcurrency 1 `
        -AgentTasks js-window,browser-style
      if ($LASTEXITCODE -ne 0) {
        throw "Agent matrix failed at memory cap $memoryCap with exit code $LASTEXITCODE"
      }
      $row.agentRun = ($agentOutput | Select-Object -Last 1)

      $throughputOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scriptRoot "run-wsl-model-matrix.ps1") `
        -Distro $Distro `
        -Models $Model `
        -ContextSize $ThroughputContextSize `
        -Parallel $ThroughputParallel `
        -CalibrationConcurrency $ThroughputConcurrency `
        -SkipAgent
      if ($LASTEXITCODE -ne 0) {
        throw "Throughput matrix failed at memory cap $memoryCap with exit code $LASTEXITCODE"
      }
      $row.throughputRun = ($throughputOutput | Select-Object -Last 1)
      $row.status = "completed"
    }
  } catch {
    $row.status = "failed"
    $row.error = $_.Exception.Message
  }

  $rows += [pscustomobject]$row
  [ordered]@{
    createdAt = (Get-Date).ToString("o")
    distro = $Distro
    model = $Model
    apply = [bool]$Apply
    wslConfigPath = $wslConfigPath
    hadExistingWslConfig = $hadExistingConfig
    backupPath = $backupPath
    memoryCaps = $MemoryCaps
    rows = $rows
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}

if ($Apply) {
  if ($hadExistingConfig) {
    Set-Content -LiteralPath $wslConfigPath -Value $existingConfig -Encoding UTF8
  } else {
    Remove-Item -LiteralPath $wslConfigPath -ErrorAction SilentlyContinue
  }
  & wsl.exe --shutdown
}

Write-Output $summaryPath
