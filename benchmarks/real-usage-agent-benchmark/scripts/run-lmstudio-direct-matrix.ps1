param(
  [string[]]$Models = @(
    "google/gemma-4-12b",
    "google/gemma-4-e4b",
    "qwen/qwen3-coder-30b",
    "unsloth/qwen3-coder-30b-a3b-instruct",
    "qwen2.5-coder-1.5b-instruct@q4_k_m",
    "qwen2.5-coder-1.5b-instruct@q8_0",
    "qwen3-0.6b"
  ),
  [string[]]$Tasks = @("backend-api", "schema-validation", "frontend-filter"),
  [string]$BaseUrl = "http://127.0.0.1:1234/v1",
  [int]$ContextLength = 16384,
  [int]$MaxAttempts = 2,
  [int]$MaxTokens = 4096,
  [int]$TaskTimeoutMs = 300000,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$wrapper = Join-Path $scriptRoot "run-lmstudio-real-usage-api.ps1"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runId = "$stamp-lmstudio-direct-matrix"
$resultDir = Join-Path $benchRoot "results\$runId"
$logDir = Join-Path $benchRoot "logs\$runId"
New-Item -ItemType Directory -Force -Path $resultDir,$logDir | Out-Null

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

function ConvertTo-SafeName {
  param([string]$Value)
  return ($Value -replace '[^A-Za-z0-9_.-]', '_')
}

function Invoke-Capture {
  param(
    [Parameter(Mandatory = $true)][string]$FileName,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$StdoutPath,
    [Parameter(Mandatory = $true)][string]$StderrPath,
    [int]$TimeoutSeconds = 1800
  )
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FileName
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = ConvertTo-ArgumentString $Arguments
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  $sw = [Diagnostics.Stopwatch]::StartNew()
  [void]$process.Start()
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $exited = $process.WaitForExit($TimeoutSeconds * 1000)
  if (-not $exited) {
    try { $process.Kill($true) } catch {}
  }
  $sw.Stop()
  Write-Utf8NoBom -Path $StdoutPath -Value $stdoutTask.GetAwaiter().GetResult()
  Write-Utf8NoBom -Path $StderrPath -Value $stderrTask.GetAwaiter().GetResult()
  [pscustomobject]@{
    exitCode = if ($exited) { $process.ExitCode } else { $null }
    timedOut = -not $exited
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    stdout = $StdoutPath
    stderr = $StderrPath
  }
}

$selectedModels = @($Models | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$rows = New-Object System.Collections.ArrayList

foreach ($model in $selectedModels) {
  $safeModel = ConvertTo-SafeName $model
  $stdoutPath = Join-Path $logDir "$safeModel.stdout.txt"
  $stderrPath = Join-Path $logDir "$safeModel.stderr.txt"
  $reasoning = if ($model -like "google/gemma-4-*") { "none" } else { "" }
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $wrapper,
    "-Tasks",
    ($selectedTasks -join ","),
    "-Profile",
    "custom",
    "-Model",
    $model,
    "-BaseUrl",
    $BaseUrl,
    "-ContextLength",
    "$ContextLength",
    "-MaxAttempts",
    "$MaxAttempts",
    "-MaxTokens",
    "$MaxTokens",
    "-TaskTimeoutMs",
    "$TaskTimeoutMs"
  )
  if (-not [string]::IsNullOrWhiteSpace($reasoning)) {
    $args += "-ReasoningEffort"
    $args += $reasoning
  }
  if ($DryRun) { $args += "-DryRun" }
  $timeoutSeconds = [math]::Ceiling(($TaskTimeoutMs / 1000 + 60) * [math]::Max(1, $selectedTasks.Count) + 1500)
  $run = Invoke-Capture -FileName "powershell.exe" -Arguments $args -WorkingDirectory $repoRoot -StdoutPath $stdoutPath -StderrPath $stderrPath -TimeoutSeconds $timeoutSeconds
  $summaryPath = $null
  $summary = $null
  if (Test-Path -LiteralPath $stdoutPath) {
    $lines = @(Get-Content -LiteralPath $stdoutPath | Where-Object { $_.Trim() })
    if ($lines.Count -gt 0) {
      $candidate = $lines[-1].Trim()
      if (Test-Path -LiteralPath $candidate) {
        $summaryPath = $candidate
        try { $summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json } catch {}
      }
    }
  }
  [void]$rows.Add([pscustomobject]@{
    model = $model
    dryRun = [bool]$DryRun
    reasoningEffort = if ([string]::IsNullOrWhiteSpace($reasoning)) { $null } else { $reasoning }
    run = $run
    summaryPath = $summaryPath
    passed = if ($summary) { $summary.passed } else { $false }
    taskRows = if ($summary) { @($summary.tasks) } else { @() }
  })
}

$overall = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  runner = "lmstudio-direct-api-matrix"
  dryRun = [bool]$DryRun
  runId = $runId
  baseUrl = $BaseUrl
  contextLength = $ContextLength
  maxAttempts = $MaxAttempts
  maxTokens = $MaxTokens
  taskTimeoutMs = $TaskTimeoutMs
  tasks = $selectedTasks
  resultDir = $resultDir
  logDir = $logDir
  rows = @($rows.ToArray())
  passed = if ($DryRun) { $null } else { @($rows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
}
$overallPath = Join-Path $resultDir "lmstudio-direct-api-matrix-summary.json"
Write-Utf8NoBom -Path $overallPath -Value (($overall | ConvertTo-Json -Depth 30) + "`n")
Write-Output $overallPath
if (-not $DryRun -and -not $overall.passed) { exit 1 }
