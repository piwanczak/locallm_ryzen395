param(
  [string[]]$Models = @(
    "google/gemma-4-12b",
    "google/gemma-4-e4b",
    "qwen/qwen3-coder-30b",
    "unsloth/qwen3-coder-30b-a3b-instruct"
  ),
  [string[]]$Tasks = @("backend-api", "frontend-filter", "failing-command-recovery"),
  [string]$BaseUrl = "http://host.docker.internal:1234/v1",
  [string]$LmStudioBaseUrl = "http://127.0.0.1:1234/v1",
  [int]$ContextLength = 16384,
  [int]$TaskTimeoutSeconds = 900,
  [switch]$Build,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$piWrapper = Join-Path $scriptRoot "run-pi-real-usage.ps1"
$loadProfile = Join-Path $repoRoot "benchmarks\opencode-agent-benchmark\scripts\load-lmstudio-profile.ps1"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runId = "$stamp-lmstudio-pi-matrix"
$resultDir = Join-Path $benchRoot "results\$runId"
$logDir = Join-Path $benchRoot "logs\$runId"
$initialState = Join-Path $resultDir "initial-lms-state.json"
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

function Get-LmStudioApiRoot {
  $trimmed = $LmStudioBaseUrl.TrimEnd("/")
  if ($trimmed.EndsWith("/v1")) {
    return $trimmed.Substring(0, $trimmed.Length - 3)
  }
  return $trimmed
}

function Invoke-LmStudioJson {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][hashtable]$Body,
    [int]$TimeoutSec = 900
  )
  $json = $Body | ConvertTo-Json -Depth 12
  Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" -Body $json -TimeoutSec $TimeoutSec
}

function Load-CustomModel {
  param([string]$Model)
  $body = @{
    model = $Model
    context_length = $ContextLength
    eval_batch_size = 2048
    physical_batch_size = 512
    parallel = 1
    flash_attention = $true
    offload_kv_cache_to_gpu = $true
    echo_load_config = $true
  }
  if ($Model -like "*qwen3-coder*") {
    $body.num_experts = 4
  }
  Invoke-LmStudioJson -Uri "$((Get-LmStudioApiRoot).TrimEnd('/'))/api/v1/models/load" -Body $body -TimeoutSec 900
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

& "$env:USERPROFILE\.lmstudio\bin\lms.exe" ps --json | Set-Content -LiteralPath $initialState -Encoding UTF8
$selectedModels = @($Models | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$rows = New-Object System.Collections.ArrayList

foreach ($model in $selectedModels) {
  $safeModel = ConvertTo-SafeName $model
  $load = $null
  $restore = $null
  $stdoutPath = Join-Path $logDir "$safeModel-pi.stdout.txt"
  $stderrPath = Join-Path $logDir "$safeModel-pi.stderr.txt"
  try {
    if (-not $DryRun) {
      $swLoad = [Diagnostics.Stopwatch]::StartNew()
      $customLoad = Load-CustomModel -Model $model
      $swLoad.Stop()
      Write-Utf8NoBom -Path (Join-Path $logDir "$safeModel-lmstudio-load.json") -Value (($customLoad | ConvertTo-Json -Depth 20) + "`n")
      $load = [pscustomobject]@{
        mode = "custom"
        model = $model
        contextLength = $ContextLength
        elapsedMs = [math]::Round($swLoad.Elapsed.TotalMilliseconds, 1)
      }
    }
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      $piWrapper,
      "-Tasks",
      ($selectedTasks -join ","),
      "-BaseUrl",
      $BaseUrl,
      "-Model",
      $model,
      "-TaskTimeoutSeconds",
      "$TaskTimeoutSeconds"
    )
    if ($Build) { $args += "-Build" }
    if ($DryRun) { $args += "-DryRun" }
    $timeoutSeconds = [math]::Max(300, ($TaskTimeoutSeconds * [math]::Max(1, $selectedTasks.Count)) + 240)
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
      load = $load
      run = $run
      summaryPath = $summaryPath
      passed = if ($summary) { $summary.passed } else { $false }
      taskRows = if ($summary) { @($summary.tasks) } else { @() }
      restore = $null
    })
  } finally {
    if (-not $DryRun) {
      $restoreStdout = Join-Path $logDir "$safeModel-lmstudio-restore.out.txt"
      $restoreStderr = Join-Path $logDir "$safeModel-lmstudio-restore.err.txt"
      $restore = Invoke-Capture `
        -FileName "powershell.exe" `
        -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",$loadProfile,"-Profile","restore-initial","-InitialStateJson",$initialState) `
        -WorkingDirectory $repoRoot `
        -StdoutPath $restoreStdout `
        -StderrPath $restoreStderr `
        -TimeoutSeconds 1200
      if ($rows.Count -gt 0) {
        $rows[$rows.Count - 1].restore = $restore
      }
    }
  }
}

$overall = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  runner = "lmstudio-pi-matrix"
  dryRun = [bool]$DryRun
  runId = $runId
  baseUrl = $BaseUrl
  lmStudioBaseUrl = $LmStudioBaseUrl
  contextLength = $ContextLength
  taskTimeoutSeconds = $TaskTimeoutSeconds
  tasks = $selectedTasks
  resultDir = $resultDir
  logDir = $logDir
  initialState = $initialState
  rows = @($rows.ToArray())
  passed = if ($DryRun) { $null } else { @($rows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
}
$overallPath = Join-Path $resultDir "lmstudio-pi-matrix-summary.json"
Write-Utf8NoBom -Path $overallPath -Value (($overall | ConvertTo-Json -Depth 40) + "`n")
Write-Output $overallPath
if (-not $DryRun -and -not $overall.passed) { exit 1 }
