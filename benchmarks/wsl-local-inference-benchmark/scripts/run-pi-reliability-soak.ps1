param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8091,
  [int]$ContextSize = 8192,
  [string]$ModelAlias = "qwen/qwen3-coder-30b-q4",
  [string]$ModelPath = "",
  [int]$Iterations = 3,
  [string[]]$Tasks = @("file-create", "js-edit", "browser-style"),
  [switch]$UseExistingServer,
  [switch]$KeepServer,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$workflowScript = Join-Path $scriptRoot "run-pi-jinja-q4-toolcall-workflow.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-pi-reliability-soak"
$logRoot = Join-Path $benchRoot "logs\$timestamp-pi-reliability-soak"
$summaryPath = Join-Path $runRoot "pi-reliability-soak-summary.json"

if (-not $ModelPath) {
  $ModelPath = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Value
  )
  $dir = Split-Path -Parent $Path
  if ($dir) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function ConvertTo-WslPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  if ($resolved -notmatch '^([A-Za-z]):\\(.*)$') {
    throw "Only local drive paths are supported for WSL conversion: $resolved"
  }
  $drive = $Matches[1].ToLowerInvariant()
  $rest = $Matches[2] -replace '\\', '/'
  return "/mnt/$drive/$rest"
}

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)
  return "'" + ($Value -replace "'", "'\''") + "'"
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
  $output | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  return $exitCode
}

function Find-SummaryPath {
  param([Parameter(Mandatory = $true)][string]$OutputPath)
  if (-not (Test-Path -LiteralPath $OutputPath)) {
    return $null
  }
  $lines = @(Get-Content -LiteralPath $OutputPath)
  for ($i = $lines.Count - 1; $i -ge 0; $i -= 1) {
    $candidate = [string]$lines[$i]
    if ($candidate.Trim() -and (Test-Path -LiteralPath $candidate.Trim())) {
      return $candidate.Trim()
    }
  }
  return $null
}

function Classify-WorkflowFailure {
  param(
    [int]$ExitCode,
    [object]$WorkflowSummary,
    [int]$ExpectedTaskCount
  )
  if ($ExitCode -ne 0 -and $null -eq $WorkflowSummary) {
    return "workflow-no-summary"
  }
  if ($null -eq $WorkflowSummary) {
    return "missing-summary"
  }
  if (-not [bool]$WorkflowSummary.passed) {
    $failedTasks = @($WorkflowSummary.taskResults | Where-Object { -not $_.passed })
    $failedProbes = @($WorkflowSummary.rawProbes | Where-Object { $_.exitCode -ne 0 })
    if ($failedProbes.Count -gt 0) {
      return "raw-probe-failure"
    }
    if ($failedTasks.Count -gt 0) {
      return "task-failure"
    }
    return "summary-failed"
  }
  if (@($WorkflowSummary.taskResults).Count -ne $ExpectedTaskCount) {
    return "task-count-mismatch"
  }
  if ($ExitCode -ne 0) {
    return "exit-code-after-pass"
  }
  return "none"
}

New-Item -ItemType Directory -Force -Path $runRoot, $logRoot | Out-Null
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  distro = $Distro
  port = $Port
  contextSize = $ContextSize
  modelAlias = $ModelAlias
  modelPath = $ModelPath
  iterationsRequested = $Iterations
  tasks = $selectedTasks
  useExistingServer = [bool]$UseExistingServer
  keepServer = [bool]$KeepServer
  runRoot = $runRoot
  logRoot = $logRoot
  workflowScript = $workflowScript
  serverStart = $null
  serverStop = $null
  iterations = @()
  passedIterations = 0
  failedIterations = 0
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

if ($Iterations -lt 1) {
  throw "Iterations must be at least 1."
}
if (-not (Test-Path -LiteralPath $workflowScript)) {
  throw "Missing workflow script: $workflowScript"
}
if (-not (Test-Path -LiteralPath $ModelPath)) {
  throw "Missing model file: $ModelPath"
}

$benchRootWsl = ConvertTo-WslPath $benchRoot
$modelPathWsl = ConvertTo-WslPath $ModelPath
$logRootWsl = ConvertTo-WslPath $logRoot
$pidFileWsl = "$logRootWsl/llama-server.pid"
$logFileWsl = "$logRootWsl/llama-server.log"
$readyFileWsl = "$logRootWsl/llama-server.ready.json"
$startedServer = $false

$serverCommand = @(
  "cd $(Quote-Bash $benchRootWsl)",
  "&&",
  "MODEL_PATH=$(Quote-Bash $modelPathWsl)",
  "MODEL_ALIAS=$(Quote-Bash $ModelAlias)",
  "PORT=$Port",
  "CTX_SIZE=$ContextSize",
  "PARALLEL=1",
  "LLAMA_JINJA=1",
  "LOG_DIR=$(Quote-Bash $logRootWsl)",
  "PID_FILE=$(Quote-Bash $pidFileWsl)",
  "LOG_FILE=$(Quote-Bash $logFileWsl)",
  "READY_FILE=$(Quote-Bash $readyFileWsl)",
  "bash scripts/start-wsl-llama-server-amd.sh"
) -join " "

$stopCommand = @(
  "cd $(Quote-Bash $benchRootWsl)",
  "&&",
  "LOG_DIR=$(Quote-Bash $logRootWsl)",
  "PID_FILE=$(Quote-Bash $pidFileWsl)",
  "bash scripts/stop-wsl-llama-server-amd.sh"
) -join " "

try {
  if (-not $UseExistingServer) {
    $startOut = Join-Path $runRoot "llama-start.out.txt"
    $startCode = Invoke-Capture -OutputPath $startOut -Command {
      & wsl.exe --distribution $Distro --user root -- bash -lc $serverCommand
    }
    $summary.serverStart = [pscustomobject]@{
      exitCode = $startCode
      outputPath = $startOut
    }
    if ($startCode -ne 0) {
      throw "llama-server start failed with exit code $startCode"
    }
    $startedServer = $true
  }

  $iterationResults = New-Object System.Collections.ArrayList
  for ($iteration = 1; $iteration -le $Iterations; $iteration += 1) {
    $iterationDir = Join-Path $runRoot ("iteration-{0:000}" -f $iteration)
    New-Item -ItemType Directory -Force -Path $iterationDir | Out-Null
    $outPath = Join-Path $iterationDir "workflow.out.txt"
    $exitPath = Join-Path $iterationDir "workflow.exitcode.txt"
    $startedAt = Get-Date

    $workflowArgs = @(
      "-UseExistingServer",
      "-Port", $Port,
      "-ContextSize", $ContextSize,
      "-ModelAlias", $ModelAlias,
      "-ModelPath", $ModelPath,
      "-Tasks", ($selectedTasks -join ",")
    )

    $exitCode = Invoke-Capture -OutputPath $outPath -Command {
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $workflowScript @workflowArgs
    }
    Set-Content -LiteralPath $exitPath -Encoding ASCII -Value $exitCode
    $completedAt = Get-Date
    $summaryCandidate = Find-SummaryPath -OutputPath $outPath
    $workflowSummary = $null
    if ($summaryCandidate) {
      try {
        $workflowSummary = Get-Content -Raw -LiteralPath $summaryCandidate | ConvertFrom-Json
      } catch {
        $workflowSummary = $null
      }
    }

    $taskStatus = @()
    if ($workflowSummary) {
      $taskStatus = @($workflowSummary.taskResults | ForEach-Object {
        [pscustomobject]@{
          task = [string]$_.task
          passed = [bool]$_.passed
          piExitCode = $_.piExitCode
          sessionLog = [string]$_.sessionLog
          sessionLogExists = if ($_.sessionLog) { Test-Path -LiteralPath $_.sessionLog } else { $false }
        }
      })
    }

    $taskCountMatches = ($workflowSummary -and @($workflowSummary.taskResults).Count -eq @($selectedTasks).Count)
    $passed = ($exitCode -eq 0 -and $workflowSummary -and [bool]$workflowSummary.passed -and $taskCountMatches)
    $classification = Classify-WorkflowFailure -ExitCode $exitCode -WorkflowSummary $workflowSummary -ExpectedTaskCount @($selectedTasks).Count
    [void]$iterationResults.Add([pscustomobject]@{
      iteration = $iteration
      startedAt = $startedAt.ToString("o")
      completedAt = $completedAt.ToString("o")
      durationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
      exitCode = $exitCode
      passed = [bool]$passed
      failureClass = $classification
      workflowOutputPath = $outPath
      workflowExitPath = $exitPath
      workflowSummaryPath = $summaryCandidate
      workflowRunRoot = if ($workflowSummary) { [string]$workflowSummary.runRoot } else { $null }
      taskStatus = $taskStatus
    })
  }

  $summary.iterations = @($iterationResults.ToArray())
} finally {
  if ($startedServer -and -not $KeepServer) {
    $stopOut = Join-Path $runRoot "llama-stop.out.txt"
    $stopCode = Invoke-Capture -OutputPath $stopOut -Command {
      & wsl.exe --distribution $Distro --user root -- bash -lc $stopCommand
    }
    $summary.serverStop = [pscustomobject]@{
      exitCode = $stopCode
      outputPath = $stopOut
    }
  }
  $summary.completedAt = (Get-Date).ToString("o")
  $summary.passedIterations = @($summary.iterations | Where-Object { $_.passed }).Count
  $summary.failedIterations = @($summary.iterations | Where-Object { -not $_.passed }).Count
  $summary.passed = (
    $summary.iterations.Count -eq $Iterations -and
    $summary.failedIterations -eq 0 -and
    ($UseExistingServer -or $summary.serverStart.exitCode -eq 0) -and
    ($KeepServer -or $UseExistingServer -or $summary.serverStop.exitCode -eq 0)
  )
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 16)
}

Write-Output $summaryPath
if (-not $summary.passed) {
  exit 1
}
