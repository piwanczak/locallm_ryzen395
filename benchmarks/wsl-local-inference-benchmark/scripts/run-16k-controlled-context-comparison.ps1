param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8101,
  [string[]]$Contexts = @("8192", "16384"),
  [string[]]$Models = @("qwen3-coder-30b-q4"),
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
$matrixScript = Join-Path $scriptRoot "run-wsl-model-matrix.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-16k-controlled-context-comparison"
$summaryPath = Join-Path $runRoot "16k-controlled-context-comparison-summary.json"
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
  return [pscustomobject]@{ exitCode = $exitCode; output = @($output) }
}

function Find-SummaryPath {
  param([Parameter(Mandatory = $true)][string]$OutputPath)
  if (-not (Test-Path -LiteralPath $OutputPath)) { return $null }
  $lines = @(Get-Content -LiteralPath $OutputPath)
  for ($i = $lines.Count - 1; $i -ge 0; $i -= 1) {
    $candidate = [string]$lines[$i]
    if ($candidate.Trim() -and (Test-Path -LiteralPath $candidate.Trim())) {
      return $candidate.Trim()
    }
  }
  return $null
}

function Read-JsonOrNull {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

function Get-AgentTaskRow {
  param([string]$Task, [string]$ResultPath)
  $result = Read-JsonOrNull -Path $ResultPath
  if (-not $result) {
    return [pscustomobject]@{
      task = $Task
      resultPath = $ResultPath
      passed = $false
      firstByteMs = $null
      firstContentMs = $null
      wallMs = $null
      verifierElapsedMs = $null
      verifierExitCode = $null
      failureClass = "missing-result"
    }
  }

  $metrics = $result.metrics
  $verification = $result.verification
  return [pscustomobject]@{
    task = $Task
    resultPath = $ResultPath
    passed = [bool]$result.passed
    firstByteMs = $metrics.firstByteMs
    firstContentMs = $metrics.firstContentMs
    wallMs = $metrics.wallMs
    verifierElapsedMs = $verification.elapsedMs
    verifierExitCode = $verification.exitCode
    failureClass = if ([bool]$result.passed) { "none" } else { "task-failed" }
  }
}

$selectedContexts = @($Contexts | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedModels = @($Models | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  distro = $Distro
  port = $Port
  contexts = $selectedContexts
  models = $selectedModels
  tasks = $selectedTasks
  calibrationMaxTokens = $CalibrationMaxTokens
  agentMaxTokens = $AgentMaxTokens
  agentMaxAttempts = $AgentMaxAttempts
  runRoot = $runRoot
  rows = @()
  passed = $false
  recommendation = $null
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

$rows = New-Object System.Collections.ArrayList

foreach ($context in $selectedContexts) {
  $contextDir = Join-Path $runRoot "ctx-$context"
  New-Item -ItemType Directory -Force -Path $contextDir | Out-Null
  $stdoutPath = Join-Path $contextDir "model-matrix.out.txt"
  $exitPath = Join-Path $contextDir "model-matrix.exitcode.txt"

  $matrixArgs = @(
    "-Distro", $Distro,
    "-Port", "$Port",
    "-ContextSize", "$context",
    "-Parallel", "1",
    "-CalibrationConcurrency", "1",
    "-CalibrationMaxTokens", "$CalibrationMaxTokens",
    "-AgentMaxTokens", "$AgentMaxTokens",
    "-AgentMaxAttempts", "$AgentMaxAttempts",
    "-Models", ($selectedModels -join ","),
    "-AgentTasks", ($selectedTasks -join ",")
  )

  $startedAt = Get-Date
  $capture = Invoke-Capture -OutputPath $stdoutPath -Command {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $matrixScript @matrixArgs
  }
  $completedAt = Get-Date
  Set-Content -LiteralPath $exitPath -Encoding ASCII -Value $capture.exitCode
  $matrixSummaryPath = Find-SummaryPath -OutputPath $stdoutPath
  $matrixSummary = Read-JsonOrNull -Path $matrixSummaryPath

  if ($matrixSummary -and $matrixSummary.models) {
    foreach ($model in @($matrixSummary.models)) {
      $calibration = Read-JsonOrNull -Path ([string]$model.calibration)
      $taskRows = @()
      foreach ($task in $selectedTasks) {
        $resultPath = $null
        if ($model.agent -and $model.agent.PSObject.Properties[$task]) {
          $resultPath = [string]$model.agent.PSObject.Properties[$task].Value
        }
        $taskRows += Get-AgentTaskRow -Task $task -ResultPath $resultPath
      }

      [void]$rows.Add([pscustomobject]@{
        contextSize = [int]$context
        modelKey = [string]$model.key
        modelAlias = [string]$model.alias
        startedAt = $startedAt.ToString("o")
        completedAt = $completedAt.ToString("o")
        durationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
        matrixExitCode = $capture.exitCode
        matrixSummaryPath = $matrixSummaryPath
        calibrationPath = [string]$model.calibration
        calibrationOk = if ($calibration) { [bool]$calibration.ok } else { $false }
        calibrationFirstByteMsMin = $calibration.firstByteMsMin
        calibrationFirstContentMsMin = $calibration.firstContentMsMin
        calibrationDecodeTokPerSecAggregateEstimate = $calibration.decodeTokPerSecAggregateEstimate
        taskStatus = $taskRows
        passed = ($capture.exitCode -eq 0 -and $null -eq $model.error -and $taskRows.Count -eq $selectedTasks.Count -and @($taskRows | Where-Object { -not $_.passed }).Count -eq 0)
        error = $model.error
      })
    }
  } else {
    [void]$rows.Add([pscustomobject]@{
      contextSize = [int]$context
      modelKey = $null
      modelAlias = $null
      startedAt = $startedAt.ToString("o")
      completedAt = $completedAt.ToString("o")
      durationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
      matrixExitCode = $capture.exitCode
      matrixSummaryPath = $matrixSummaryPath
      calibrationPath = $null
      calibrationOk = $false
      calibrationFirstByteMsMin = $null
      calibrationFirstContentMsMin = $null
      calibrationDecodeTokPerSecAggregateEstimate = $null
      taskStatus = @()
      passed = $false
      error = "matrix summary missing or unreadable"
    })
  }

  $summary.rows = @($rows.ToArray())
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 18)
}

$summary.rows = @($rows.ToArray())
$summary.completedAt = (Get-Date).ToString("o")
$summary.passed = (
  @($summary.rows).Count -ge ($selectedContexts.Count * $selectedModels.Count) -and
  @($summary.rows | Where-Object { -not $_.passed }).Count -eq 0
)
$q4Rows = @($summary.rows | Where-Object { $_.modelKey -eq "qwen3-coder-30b-q4" })
$q4_16 = $q4Rows | Where-Object { $_.contextSize -eq 16384 } | Select-Object -First 1
$q4_8 = $q4Rows | Where-Object { $_.contextSize -eq 8192 } | Select-Object -First 1
if ($q4_16 -and $q4_16.passed) {
  $summary.recommendation = "16k is viable for the controlled WSL ROCm Qwen3 Coder Q4 edit/browser lane; compare latency against 8k before promoting it as default."
} elseif ($q4_8 -and $q4_8.passed) {
  $summary.recommendation = "Keep 8k as the controlled WSL ROCm Qwen3 Coder Q4 default; 16k did not pass this comparison."
} elseif (@($summary.rows).Count -gt 0 -and @($summary.rows | Where-Object { -not $_.passed }).Count -eq 0) {
  $summary.recommendation = "All selected non-Q4 controlled context rows passed; compare quality and latency against the Qwen3 Coder Q4 baseline before promotion."
} else {
  $summary.recommendation = "At least one selected controlled context row failed; inspect task status and model-specific errors before promotion."
}

Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 18)
Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
