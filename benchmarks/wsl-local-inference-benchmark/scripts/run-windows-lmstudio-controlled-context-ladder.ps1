param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "google/gemma-4-e4b",
  [string[]]$Contexts = @("16384", "32768"),
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [int]$Parallel = 1,
  [int]$NumExperts = 0,
  [string[]]$Tasks = @("js-window", "browser-style"),
  [int]$CalibrationMaxTokens = 128,
  [int]$AgentMaxTokens = 2048,
  [int]$AgentMaxAttempts = 2,
  [int]$CalibrationTimeoutMs = 300000,
  [int]$AgentTimeoutMs = 300000,
  [switch]$StopOnFailure,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$calibrationScript = Join-Path $scriptRoot "run-openai-compatible-calibration.mjs"
$agentScript = Join-Path $scriptRoot "run-controlled-edit-agent.mjs"
$lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runId = "$timestamp-windows-lmstudio-controlled-context-ladder"
$runRoot = Join-Path $benchRoot "results\$runId"
$summaryPath = Join-Path $runRoot "windows-lmstudio-controlled-context-ladder-summary.json"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
  )
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function Invoke-Capture {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Command,
    [Parameter(Mandatory = $true)][string]$OutputPath
  )
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $Command 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  $lines = @($output | ForEach-Object { $_.ToString() })
  Write-Utf8NoBom -Path $OutputPath -Value (($lines -join "`n") + $(if ($lines.Count -gt 0) { "`n" } else { "" }))
  return [pscustomobject]@{
    exitCode = $exitCode
    outputPath = $OutputPath
    outputText = ($lines -join "`n")
  }
}

function Read-JsonOrNull {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

function Invoke-LmStudioJson {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][hashtable]$Body,
    [int]$TimeoutSec = 600
  )
  $json = $Body | ConvertTo-Json -Depth 12
  Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" -Body $json -TimeoutSec $TimeoutSec
}

function Get-LoadedModels {
  if (-not (Test-Path -LiteralPath $lms)) { return @() }
  $raw = & $lms ps --json 2>$null
  if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
  try {
    $parsed = $raw | ConvertFrom-Json
    if ($null -eq $parsed) { return @() }
    return @($parsed)
  } catch { return @() }
}

function Unload-ModelInstances {
  param([Parameter(Mandatory = $true)][string]$ModelName)
  $rows = @(Get-LoadedModels | Where-Object {
    if ($null -eq $_) { return $false }
    $properties = @($_.PSObject.Properties.Name)
    $modelKey = if ($properties -contains "modelKey") { $_.modelKey } else { $null }
    $identifier = if ($properties -contains "identifier") { $_.identifier } else { $null }
    $modelKey -eq $ModelName -or $identifier -eq $ModelName
  })
  $results = @()
  foreach ($loaded in $rows) {
    $instanceId = if ($loaded.identifier) { $loaded.identifier } else { $ModelName }
    try {
      Invoke-LmStudioJson `
        -Uri "$($BaseUrl.TrimEnd('/'))/api/v1/models/unload" `
        -Body @{ instance_id = $instanceId } `
        -TimeoutSec 180 | Out-Null
      $results += [pscustomobject]@{ instanceId = $instanceId; ok = $true; error = $null }
    } catch {
      $results += [pscustomobject]@{ instanceId = $instanceId; ok = $false; error = $_.Exception.Message }
    }
  }
  return $results
}

function Load-Model {
  param([Parameter(Mandatory = $true)][int]$ContextSize)

  $body = @{
    model = $Model
    context_length = $ContextSize
    eval_batch_size = $EvalBatchSize
    physical_batch_size = $PhysicalBatchSize
    parallel = $Parallel
    flash_attention = $true
    offload_kv_cache_to_gpu = $true
    echo_load_config = $true
  }
  if ($NumExperts -gt 0) {
    $body.num_experts = $NumExperts
  }
  Invoke-LmStudioJson -Uri "$($BaseUrl.TrimEnd('/'))/api/v1/models/load" -Body $body -TimeoutSec 1200
}

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedContexts = @(
  $Contexts |
    ForEach-Object { $_ -split "," } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ } |
    ForEach-Object { [int]$_ } |
    Where-Object { $_ -gt 0 }
)
if ($selectedContexts.Count -eq 0) { throw "No valid contexts supplied" }
if ($selectedTasks.Count -eq 0) { throw "No valid tasks supplied" }

$summary = [ordered]@{
  runId = $runId
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  baseUrl = $BaseUrl
  model = $Model
  contexts = $selectedContexts
  evalBatchSize = $EvalBatchSize
  physicalBatchSize = $PhysicalBatchSize
  parallel = $Parallel
  numExperts = if ($NumExperts -gt 0) { $NumExperts } else { $null }
  tasks = $selectedTasks
  runRoot = $runRoot
  serverStatusBefore = $null
  lmsPsBefore = $null
  contextResults = @()
  lmsPsAfter = $null
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 12) + "`n")
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $lms)) { throw "Missing LM Studio CLI: $lms" }

$serverStatusPath = Join-Path $runRoot "lms-server-status-before.txt"
$lmsPsBeforePath = Join-Path $runRoot "lms-ps-before.txt"
$lmsPsAfterPath = Join-Path $runRoot "lms-ps-after.txt"
$statusCapture = Invoke-Capture -OutputPath $serverStatusPath -Command { & $lms server status }
$psBeforeCapture = Invoke-Capture -OutputPath $lmsPsBeforePath -Command { & $lms ps }
$summary.serverStatusBefore = [pscustomobject]@{ exitCode = $statusCapture.exitCode; outputPath = $serverStatusPath; output = $statusCapture.outputText }
$summary.lmsPsBefore = [pscustomobject]@{ exitCode = $psBeforeCapture.exitCode; outputPath = $lmsPsBeforePath; output = $psBeforeCapture.outputText }

foreach ($contextSize in $selectedContexts) {
  $contextRoot = Join-Path $runRoot "ctx-$contextSize"
  New-Item -ItemType Directory -Force -Path $contextRoot | Out-Null
  $loadOutPath = Join-Path $contextRoot "lmstudio-load.json"
  $loadErrorPath = Join-Path $contextRoot "lmstudio-load-error.txt"
  $calibrationPath = Join-Path $contextRoot "calibration.json"

  $row = [ordered]@{
    contextSize = $contextSize
    root = $contextRoot
    load = $null
    calibration = $null
    taskStatus = @()
    unload = @()
    error = $null
    passed = $false
  }

  try {
    [void](Unload-ModelInstances -ModelName $Model)
    $loadResponse = Load-Model -ContextSize $contextSize
    Write-Utf8NoBom -Path $loadOutPath -Value (($loadResponse | ConvertTo-Json -Depth 14) + "`n")
    $row.load = [pscustomobject]@{ ok = $true; path = $loadOutPath }

    & node $calibrationScript `
      --base-url "$($BaseUrl.TrimEnd('/'))/v1" `
      --model $Model `
      --max-tokens $CalibrationMaxTokens `
      --concurrency 1 `
      --timeout-ms $CalibrationTimeoutMs `
      --output $calibrationPath
    $calibrationExit = $LASTEXITCODE
    $calibrationJson = Read-JsonOrNull -Path $calibrationPath
    $row.calibration = [pscustomobject]@{
      exitCode = $calibrationExit
      path = $calibrationPath
      ok = if ($calibrationJson) { [bool]$calibrationJson.ok } else { $false }
      firstByteMsMin = if ($calibrationJson) { $calibrationJson.firstByteMsMin } else { $null }
      firstContentMsMin = if ($calibrationJson) { $calibrationJson.firstContentMsMin } else { $null }
      decodeTokPerSecAggregateEstimate = if ($calibrationJson) { $calibrationJson.decodeTokPerSecAggregateEstimate } else { $null }
      promptTokenEstimate = if ($calibrationJson) { $calibrationJson.promptTokenEstimate } else { $null }
    }
    if ($calibrationExit -ne 0 -or -not $row.calibration.ok) {
      throw "Calibration failed for context $contextSize with exit code $calibrationExit"
    }

    $taskRows = @()
    foreach ($task in $selectedTasks) {
      $taskDir = Join-Path $contextRoot $task
      New-Item -ItemType Directory -Force -Path $taskDir | Out-Null
      & node $agentScript `
        --base-url "$($BaseUrl.TrimEnd('/'))/v1" `
        --model $Model `
        --task $task `
        --max-tokens $AgentMaxTokens `
        --max-attempts $AgentMaxAttempts `
        --timeout-ms $AgentTimeoutMs `
        --run-id "windows-lmstudio-ladder-$timestamp-ctx$contextSize-$task" `
        --output-dir $taskDir
      $agentExit = $LASTEXITCODE
      $resultPath = Join-Path $taskDir "$task-result.json"
      $resultJson = Read-JsonOrNull -Path $resultPath
      $taskRows += [pscustomobject]@{
        task = $task
        exitCode = $agentExit
        passed = if ($resultJson) { [bool]$resultJson.passed } else { $false }
        resultPath = $resultPath
        firstByteMs = if ($resultJson -and $resultJson.metrics) { $resultJson.metrics.firstByteMs } else { $null }
        firstContentMs = if ($resultJson -and $resultJson.metrics) { $resultJson.metrics.firstContentMs } else { $null }
        wallMs = if ($resultJson -and $resultJson.metrics) { $resultJson.metrics.wallMs } else { $null }
        promptTokens = if ($resultJson -and $resultJson.metrics -and $resultJson.metrics.usage) { $resultJson.metrics.usage.prompt_tokens } else { $null }
        completionTokens = if ($resultJson -and $resultJson.metrics -and $resultJson.metrics.usage) { $resultJson.metrics.usage.completion_tokens } else { $null }
        verifierElapsedMs = if ($resultJson -and $resultJson.verification) { $resultJson.verification.elapsedMs } else { $null }
        verifierExitCode = if ($resultJson -and $resultJson.verification) { $resultJson.verification.exitCode } else { $null }
      }
      if ($agentExit -ne 0) {
        throw "Controlled agent task '$task' failed for context $contextSize with exit code $agentExit"
      }
    }
    $row.taskStatus = $taskRows
    $row.passed = (
      $row.load.ok -eq $true -and
      $row.calibration.ok -eq $true -and
      @($row.taskStatus).Count -eq $selectedTasks.Count -and
      @($row.taskStatus | Where-Object { -not $_.passed }).Count -eq 0
    )
  } catch {
    $row.error = $_.Exception.Message
    if (-not $row.load) {
      Write-Utf8NoBom -Path $loadErrorPath -Value ($_.Exception.ToString() + "`n")
      $row.load = [pscustomobject]@{ ok = $false; path = $loadErrorPath }
    }
  } finally {
    $row.unload = @(Unload-ModelInstances -ModelName $Model)
    $summary.contextResults += [pscustomobject]$row
    Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 16) + "`n")
  }

  if ($StopOnFailure -and -not $row.passed) {
    break
  }
}

$psAfterCapture = Invoke-Capture -OutputPath $lmsPsAfterPath -Command { & $lms ps }
$summary.lmsPsAfter = [pscustomobject]@{ exitCode = $psAfterCapture.exitCode; outputPath = $lmsPsAfterPath; output = $psAfterCapture.outputText }
$summary.completedAt = (Get-Date).ToString("o")
$summary.passed = (
  @($summary.contextResults).Count -gt 0 -and
  @($summary.contextResults | Where-Object { -not $_.passed }).Count -eq 0
)
Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 16) + "`n")
Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
