param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$ContextSize = 16384,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [int]$Parallel = 1,
  [int]$NumExperts = 4,
  [string[]]$Tasks = @("js-window", "browser-style"),
  [int]$CalibrationMaxTokens = 128,
  [int]$AgentMaxTokens = 2048,
  [int]$AgentMaxAttempts = 2,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$reloadScript = Join-Path $repoRoot "tools\reload-qwen30b-long-context.ps1"
$calibrationScript = Join-Path $scriptRoot "run-openai-compatible-calibration.mjs"
$agentScript = Join-Path $scriptRoot "run-controlled-edit-agent.mjs"
$lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-windows-lmstudio-16k-controlled"
$summaryPath = Join-Path $runRoot "windows-lmstudio-16k-controlled-summary.json"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

function Write-Utf8NoBom {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function Invoke-Capture {
  param([Parameter(Mandatory = $true)][scriptblock]$Command, [Parameter(Mandatory = $true)][string]$OutputPath)
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $Command 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  $output | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  return [pscustomobject]@{ exitCode = $exitCode; outputText = (($output | ForEach-Object { $_.ToString() }) -join "`n") }
}

function Read-JsonOrNull {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

function Invoke-LmStudioUnload {
  param([string]$Root, [string]$ModelName)
  try {
    Invoke-RestMethod `
      -Uri "$($Root.TrimEnd('/'))/api/v1/models/unload" `
      -Method Post `
      -ContentType "application/json" `
      -Body (@{ instance_id = $ModelName } | ConvertTo-Json -Depth 5) `
      -TimeoutSec 90 | Out-Null
    return [pscustomobject]@{ attempted = $true; ok = $true; error = $null }
  } catch {
    return [pscustomobject]@{ attempted = $true; ok = $false; error = $_.Exception.Message }
  }
}

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  baseUrl = $BaseUrl
  model = $Model
  contextSize = $ContextSize
  evalBatchSize = $EvalBatchSize
  physicalBatchSize = $PhysicalBatchSize
  parallel = $Parallel
  numExperts = $NumExperts
  tasks = $selectedTasks
  runRoot = $runRoot
  serverStatusBefore = $null
  lmsPsBefore = $null
  load = $null
  calibration = $null
  taskStatus = @()
  unload = $null
  lmsPsAfter = $null
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $lms)) { throw "Missing LM Studio CLI: $lms" }

$serverStatusPath = Join-Path $runRoot "lms-server-status-before.txt"
$lmsPsBeforePath = Join-Path $runRoot "lms-ps-before.txt"
$lmsPsAfterPath = Join-Path $runRoot "lms-ps-after.txt"
$loadOutPath = Join-Path $runRoot "lmstudio-load.out.txt"
$calibrationPath = Join-Path $runRoot "windows-lmstudio-calibration.json"

$statusCapture = Invoke-Capture -OutputPath $serverStatusPath -Command { & $lms server status }
$psBeforeCapture = Invoke-Capture -OutputPath $lmsPsBeforePath -Command { & $lms ps }
$summary.serverStatusBefore = [pscustomobject]@{ exitCode = $statusCapture.exitCode; outputPath = $serverStatusPath; output = $statusCapture.outputText }
$summary.lmsPsBefore = [pscustomobject]@{ exitCode = $psBeforeCapture.exitCode; outputPath = $lmsPsBeforePath; output = $psBeforeCapture.outputText }

try {
  $loadCapture = Invoke-Capture -OutputPath $loadOutPath -Command {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $reloadScript `
      -BaseUrl $BaseUrl `
      -Model $Model `
      -ContextLength $ContextSize `
      -EvalBatchSize $EvalBatchSize `
      -PhysicalBatchSize $PhysicalBatchSize `
      -Parallel $Parallel `
      -NumExperts $NumExperts
  }
  $summary.load = [pscustomobject]@{ exitCode = $loadCapture.exitCode; outputPath = $loadOutPath }
  if ($loadCapture.exitCode -ne 0) { throw "LM Studio load failed with exit code $($loadCapture.exitCode)" }

  & node $calibrationScript `
    --base-url "$($BaseUrl.TrimEnd('/'))/v1" `
    --model $Model `
    --max-tokens $CalibrationMaxTokens `
    --concurrency 1 `
    --output $calibrationPath
  $calibrationExit = $LASTEXITCODE
  $calibrationJson = Read-JsonOrNull -Path $calibrationPath
  $summary.calibration = [pscustomobject]@{
    exitCode = $calibrationExit
    path = $calibrationPath
    ok = if ($calibrationJson) { [bool]$calibrationJson.ok } else { $false }
    firstContentMsMin = $calibrationJson.firstContentMsMin
    decodeTokPerSecAggregateEstimate = $calibrationJson.decodeTokPerSecAggregateEstimate
  }

  $taskRows = @()
  foreach ($task in $selectedTasks) {
    $taskDir = Join-Path $runRoot $task
    New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
    & node $agentScript `
      --base-url "$($BaseUrl.TrimEnd('/'))/v1" `
      --model $Model `
      --task $task `
      --max-tokens $AgentMaxTokens `
      --max-attempts $AgentMaxAttempts `
      --run-id "windows-lmstudio-16k-$timestamp-$task" `
      --output-dir $taskDir
    $agentExit = $LASTEXITCODE
    $resultPath = Join-Path $taskDir "$task-result.json"
    $resultJson = Read-JsonOrNull -Path $resultPath
    $taskRows += [pscustomobject]@{
      task = $task
      exitCode = $agentExit
      passed = if ($resultJson) { [bool]$resultJson.passed } else { $false }
      resultPath = $resultPath
      firstByteMs = $resultJson.metrics.firstByteMs
      firstContentMs = $resultJson.metrics.firstContentMs
      wallMs = $resultJson.metrics.wallMs
      verifierElapsedMs = $resultJson.verification.elapsedMs
      verifierExitCode = $resultJson.verification.exitCode
    }
  }
  $summary.taskStatus = $taskRows
} finally {
  $summary.unload = Invoke-LmStudioUnload -Root $BaseUrl -ModelName $Model
  $psAfterCapture = Invoke-Capture -OutputPath $lmsPsAfterPath -Command { & $lms ps }
  $summary.lmsPsAfter = [pscustomobject]@{ exitCode = $psAfterCapture.exitCode; outputPath = $lmsPsAfterPath; output = $psAfterCapture.outputText }
}

$summary.completedAt = (Get-Date).ToString("o")
$summary.passed = (
  $summary.load.exitCode -eq 0 -and
  $summary.calibration.exitCode -eq 0 -and
  $summary.calibration.ok -eq $true -and
  @($summary.taskStatus).Count -eq $selectedTasks.Count -and
  @($summary.taskStatus | Where-Object { -not $_.passed }).Count -eq 0
)
Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 14)
Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
