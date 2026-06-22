param(
  [string]$Distro = "Ubuntu-24.04",
  [string]$Model = "qwen3-coder-30b-q4",
  [int]$AgentContextSize = 8192,
  [int]$ThroughputContextSize = 4096,
  [int]$ThroughputParallel = 4,
  [int]$ThroughputConcurrency = 4,
  [switch]$SkipThroughput,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-recommended-q4-workflow"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$matrixScript = Join-Path $scriptRoot "run-wsl-model-matrix.ps1"

function Invoke-Matrix {
  param(
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$StdoutPath
  )
  if ($DryRun) {
    $plan = @("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $matrixScript) + $Arguments
    $plan | Set-Content -LiteralPath $StdoutPath -Encoding UTF8
    return $null
  }

  $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $matrixScript @Arguments
  $output | Set-Content -LiteralPath $StdoutPath -Encoding UTF8
  if ($LASTEXITCODE -ne 0) {
    throw "Matrix command failed with exit code $LASTEXITCODE. See $StdoutPath"
  }
  return ($output | Select-Object -Last 1)
}

$agentStdout = Join-Path $runRoot "agent-matrix.stdout.txt"
$throughputStdout = Join-Path $runRoot "throughput-matrix.stdout.txt"

$agentArgs = @(
  "-Distro", $Distro,
  "-Models", $Model,
  "-ContextSize", "$AgentContextSize",
  "-Parallel", "1",
  "-CalibrationConcurrency", "1",
  "-CalibrationMaxTokens", "128",
  "-AgentTasks", "js-window,browser-style"
)

$throughputArgs = @(
  "-Distro", $Distro,
  "-Models", $Model,
  "-ContextSize", "$ThroughputContextSize",
  "-Parallel", "$ThroughputParallel",
  "-CalibrationConcurrency", "$ThroughputConcurrency",
  "-CalibrationMaxTokens", "128",
  "-SkipAgent"
)

$agentSummaryPath = Invoke-Matrix -Arguments $agentArgs -StdoutPath $agentStdout
$throughputSummaryPath = $null
if (-not $SkipThroughput) {
  $throughputSummaryPath = Invoke-Matrix -Arguments $throughputArgs -StdoutPath $throughputStdout
}

$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  dryRun = [bool]$DryRun
  model = $Model
  distro = $Distro
  agentContextSize = $AgentContextSize
  throughputContextSize = $ThroughputContextSize
  throughputParallel = $ThroughputParallel
  throughputConcurrency = $ThroughputConcurrency
  agentMatrixSummary = $agentSummaryPath
  throughputMatrixSummary = $throughputSummaryPath
  agentStdout = $agentStdout
  throughputStdout = if ($SkipThroughput) { $null } else { $throughputStdout }
  agentCalibration = $null
  jsWindowResult = $null
  browserStyleResult = $null
  throughputCalibration = $null
}

if (-not $DryRun -and $agentSummaryPath) {
  $agentSummary = Get-Content -Raw -LiteralPath $agentSummaryPath | ConvertFrom-Json
  $agentModel = $agentSummary.models | Select-Object -First 1
  $summary.agentCalibration = $agentModel.calibration
  $summary.jsWindowResult = $agentModel.agent.'js-window'
  $summary.browserStyleResult = $agentModel.agent.'browser-style'
}

if (-not $DryRun -and $throughputSummaryPath) {
  $throughputSummary = Get-Content -Raw -LiteralPath $throughputSummaryPath | ConvertFrom-Json
  $throughputModel = $throughputSummary.models | Select-Object -First 1
  $summary.throughputCalibration = $throughputModel.calibration
}

$summaryPath = Join-Path $runRoot "recommended-q4-workflow-summary.json"
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output $summaryPath
