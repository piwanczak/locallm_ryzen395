param(
  [string[]]$Models = @("qwen3-coder:30b", "gemma3n:e4b", "gemma3:12b"),
  [string[]]$Tasks = @("backend-api", "multi-file-cart", "frontend-filter", "failing-command-recovery"),
  [string]$BaseUrl = "http://127.0.0.1:11434/v1",
  [string]$EndpointName = "windows",
  [int]$TimeoutMinutes = 12,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$opencodeWrapper = Join-Path $scriptRoot "run-opencode-real-usage.ps1"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$safeEndpoint = $EndpointName -replace '[^A-Za-z0-9_.-]', '_'
$runId = "$stamp-ollama-$safeEndpoint-opencode-matrix"
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
  $startedAtUnixMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $sw = [Diagnostics.Stopwatch]::StartNew()
  [void]$process.Start()
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $exited = $process.WaitForExit($TimeoutSeconds * 1000)
  if (-not $exited) {
    try { $process.Kill($true) } catch {}
  }
  $sw.Stop()
  $endedAtUnixMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  Write-Utf8NoBom -Path $StdoutPath -Value $stdoutTask.GetAwaiter().GetResult()
  Write-Utf8NoBom -Path $StderrPath -Value $stderrTask.GetAwaiter().GetResult()
  [pscustomobject]@{
    exitCode = if ($exited) { $process.ExitCode } else { $null }
    timedOut = -not $exited
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    startedAtUnixMs = $startedAtUnixMs
    endedAtUnixMs = $endedAtUnixMs
    stdout = $StdoutPath
    stderr = $StderrPath
  }
}

$selectedModels = @($Models | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$rows = New-Object System.Collections.ArrayList

foreach ($model in $selectedModels) {
  $safeModel = ConvertTo-SafeName $model
  $stdoutPath = Join-Path $logDir "$safeModel-opencode.stdout.txt"
  $stderrPath = Join-Path $logDir "$safeModel-opencode.stderr.txt"
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $opencodeWrapper,
    "-Tasks",
    ($selectedTasks -join ","),
    "-BaseUrl",
    $BaseUrl,
    "-Model",
    $model,
    "-TimeoutMinutes",
    "$TimeoutMinutes"
  )
  if ($DryRun) { $args += "-DryRun" }
  $timeoutSeconds = [math]::Max(300, ($TimeoutMinutes * 60 * [math]::Max(1, $selectedTasks.Count)) + 180)
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
    run = $run
    summaryPath = $summaryPath
    passed = if ($summary) { $summary.passed } else { $false }
    taskRows = if ($summary) { @($summary.tasks) } else { @() }
  })
}

$overall = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  runner = "ollama-opencode-matrix"
  dryRun = [bool]$DryRun
  runId = $runId
  endpointName = $EndpointName
  baseUrl = $BaseUrl
  timeoutMinutes = $TimeoutMinutes
  tasks = $selectedTasks
  resultDir = $resultDir
  logDir = $logDir
  rows = @($rows.ToArray())
  passed = if ($DryRun) { $null } else { @($rows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
}
$overallPath = Join-Path $resultDir "ollama-opencode-matrix-summary.json"
Write-Utf8NoBom -Path $overallPath -Value (($overall | ConvertTo-Json -Depth 40) + "`n")
Write-Output $overallPath
if (-not $DryRun -and -not $overall.passed) { exit 1 }
