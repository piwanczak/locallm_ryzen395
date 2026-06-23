param(
  [string]$Model = "google/gemma-4-12b",
  [string[]]$Contexts = @("16384", "65536", "262144"),
  [string[]]$Tasks = @("js-window", "browser-style"),
  [int]$Iterations = 3,
  [string]$ReasoningEffort = "none",
  [int]$AgentMaxTokens = 2048,
  [int]$AgentTimeoutMs = 300000,
  [switch]$StopOnFirstFailure,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$ladderScript = Join-Path $scriptRoot "run-windows-lmstudio-controlled-context-ladder.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-gemma12-controlled-reliability-sweep"
$summaryPath = Join-Path $runRoot "gemma12-controlled-reliability-sweep-summary.json"
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

function ConvertTo-ArgumentString {
  param([string[]]$Arguments)
  (($Arguments | ForEach-Object {
    if ($_ -match '[\s"]') {
      '"' + ($_ -replace '\\', '\\' -replace '"', '\"') + '"'
    } else {
      $_
    }
  }) -join " ")
}

function Invoke-ProcessCapture {
  param(
    [Parameter(Mandatory = $true)][string]$FileName,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$StdoutPath,
    [Parameter(Mandatory = $true)][string]$StderrPath,
    [int]$TimeoutSeconds = 1800
  )

  $argumentString = ConvertTo-ArgumentString $Arguments
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $process = Start-Process `
    -FilePath $FileName `
    -ArgumentList $argumentString `
    -WorkingDirectory $WorkingDirectory `
    -RedirectStandardOutput $StdoutPath `
    -RedirectStandardError $StderrPath `
    -WindowStyle Hidden `
    -PassThru
  $exited = $process.WaitForExit($TimeoutSeconds * 1000)
  if (-not $exited) {
    try { $process.Kill($true) } catch {}
  }
  $sw.Stop()

  [pscustomobject]@{
    exitCode = if ($exited) { $process.ExitCode } else { $null }
    timedOut = -not $exited
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    stdout = $StdoutPath
    stderr = $StderrPath
  }
}

function Read-JsonOrNull {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

$selectedContexts = @(
  $Contexts |
    ForEach-Object { $_ -split "," } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ } |
    ForEach-Object { [int]$_ }
)
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  model = $Model
  contexts = $selectedContexts
  tasks = $selectedTasks
  iterations = $Iterations
  reasoningEffort = $ReasoningEffort
  agentMaxTokens = $AgentMaxTokens
  agentTimeoutMs = $AgentTimeoutMs
  runRoot = $runRoot
  runs = @()
  aggregate = $null
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 20) + "`n")
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $ladderScript)) { throw "Missing ladder script: $ladderScript" }
if ($Iterations -lt 1) { throw "Iterations must be >= 1" }

$runs = New-Object System.Collections.ArrayList
for ($iteration = 1; $iteration -le $Iterations; $iteration += 1) {
  $iterationDir = Join-Path $runRoot ("iteration-{0:D2}" -f $iteration)
  New-Item -ItemType Directory -Force -Path $iterationDir | Out-Null
  $stdoutPath = Join-Path $iterationDir "ladder.out.txt"
  $stderrPath = Join-Path $iterationDir "ladder.err.txt"
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $ladderScript,
    "-Model",
    $Model,
    "-Contexts",
    ($selectedContexts -join ","),
    "-Tasks",
    ($selectedTasks -join ","),
    "-AgentMaxTokens",
    "$AgentMaxTokens",
    "-AgentTimeoutMs",
    "$AgentTimeoutMs",
    "-ReasoningEffort",
    $ReasoningEffort,
    "-StopOnFailure"
  )
  $run = Invoke-ProcessCapture `
    -FileName "powershell.exe" `
    -Arguments $args `
    -WorkingDirectory $benchRoot `
    -StdoutPath $stdoutPath `
    -StderrPath $stderrPath `
    -TimeoutSeconds 2400
  $summaryFile = $null
  if (Test-Path -LiteralPath $stdoutPath) {
    $summaryFile = Get-Content -LiteralPath $stdoutPath |
      Where-Object { $_ -like "*windows-lmstudio-controlled-context-ladder-summary.json" } |
      Select-Object -Last 1
  }
  $json = Read-JsonOrNull -Path $summaryFile
  $row = [ordered]@{
    iteration = $iteration
    run = $run
    summary = $summaryFile
    passed = if ($json) { [bool]$json.passed } else { $false }
    contexts = if ($json) { $json.contextResults } else { @() }
  }
  [void]$runs.Add([pscustomobject]$row)
  $summary.runs = @($runs.ToArray())
  Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 28) + "`n")
  if ($StopOnFirstFailure -and -not $row.passed) {
    break
  }
}

$flatTasks = @()
foreach ($run in @($runs.ToArray())) {
  foreach ($context in @($run.contexts)) {
    foreach ($task in @($context.taskStatus)) {
      $flatTasks += [pscustomobject]@{
        iteration = $run.iteration
        contextSize = $context.contextSize
        task = $task.task
        passed = [bool]$task.passed
        firstByteMs = $task.firstByteMs
        firstContentMs = $task.firstContentMs
        wallMs = $task.wallMs
        promptTokens = $task.promptTokens
        completionTokens = $task.completionTokens
      }
    }
  }
}

$summary.aggregate = [ordered]@{
  runCount = @($runs).Count
  passedRuns = @($runs | Where-Object { $_.passed }).Count
  taskCount = @($flatTasks).Count
  passedTasks = @($flatTasks | Where-Object { $_.passed }).Count
  failedTasks = @($flatTasks | Where-Object { -not $_.passed })
  taskRows = $flatTasks
}
$summary.completedAt = (Get-Date).ToString("o")
$summary.passed = (
  @($runs).Count -eq $Iterations -and
  @($runs | Where-Object { -not $_.passed }).Count -eq 0
)
Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 28) + "`n")
Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
