param(
  [string[]]$Tasks = @("backend-api"),
  [string]$Profile = "gemma12-16k",
  [string]$Model = "google/gemma-4-12b",
  [string]$BaseUrl = "http://127.0.0.1:1234/v1",
  [string]$ReasoningEffort = "",
  [int]$ContextLength = 16384,
  [int]$Parallel = 1,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
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
$node = if ($env:NODE_EXE) { $env:NODE_EXE } else { "node" }
$loadProfile = Join-Path $repoRoot "benchmarks\opencode-agent-benchmark\scripts\load-lmstudio-profile.ps1"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runId = "$stamp-lmstudio-api-real-usage"
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

function Invoke-Capture {
  param(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [string]$StdoutPath,
    [string]$StderrPath,
    [int]$TimeoutSeconds
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
  if (-not $exited) { try { $process.Kill($true) } catch {} }
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

function Get-LmStudioApiRoot {
  $trimmed = $BaseUrl.TrimEnd("/")
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
  $body = @{
    model = $Model
    context_length = $ContextLength
    eval_batch_size = $EvalBatchSize
    physical_batch_size = $PhysicalBatchSize
    parallel = $Parallel
    flash_attention = $true
    offload_kv_cache_to_gpu = $true
    echo_load_config = $true
  }
  if ($Model -like "*qwen3-coder*") {
    $body.num_experts = 4
  }
  Invoke-LmStudioJson -Uri "$((Get-LmStudioApiRoot).TrimEnd('/'))/api/v1/models/load" -Body $body -TimeoutSec 900
}

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
& "$env:USERPROFILE\.lmstudio\bin\lms.exe" ps --json | Set-Content -LiteralPath $initialState -Encoding UTF8

$load = $null
$restore = $null
$rows = New-Object System.Collections.ArrayList
try {
  if (-not $DryRun) {
    if ([string]::IsNullOrWhiteSpace($Profile) -or $Profile -eq "custom") {
      $swLoad = [Diagnostics.Stopwatch]::StartNew()
      try {
        $customLoad = Load-CustomModel
        $swLoad.Stop()
        Write-Utf8NoBom -Path (Join-Path $logDir "lmstudio-load.out.txt") -Value (($customLoad | ConvertTo-Json -Depth 20) + "`n")
        Write-Utf8NoBom -Path (Join-Path $logDir "lmstudio-load.err.txt") -Value ""
        $load = [pscustomobject]@{
          mode = "custom"
          model = $Model
          contextLength = $ContextLength
          parallel = $Parallel
          evalBatchSize = $EvalBatchSize
          physicalBatchSize = $PhysicalBatchSize
          exitCode = 0
          timedOut = $false
          elapsedMs = [math]::Round($swLoad.Elapsed.TotalMilliseconds, 1)
          stdout = (Join-Path $logDir "lmstudio-load.out.txt")
          stderr = (Join-Path $logDir "lmstudio-load.err.txt")
        }
      } catch {
        $swLoad.Stop()
        Write-Utf8NoBom -Path (Join-Path $logDir "lmstudio-load.out.txt") -Value ""
        Write-Utf8NoBom -Path (Join-Path $logDir "lmstudio-load.err.txt") -Value "$($_.Exception.Message)`n"
        throw "LM Studio custom model load failed for ${Model}: $($_.Exception.Message)"
      }
    } else {
      $load = Invoke-Capture `
        -FileName "powershell.exe" `
        -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",$loadProfile,"-Profile",$Profile) `
        -WorkingDirectory $repoRoot `
        -StdoutPath (Join-Path $logDir "lmstudio-load.out.txt") `
        -StderrPath (Join-Path $logDir "lmstudio-load.err.txt") `
        -TimeoutSeconds 1200
      if ($load.exitCode -ne 0 -or $load.timedOut) {
        throw "LM Studio profile load failed for $Profile"
      }
    }
  }

  foreach ($task in $selectedTasks) {
    $stdoutPath = Join-Path $logDir "$task-api.stdout.json"
    $stderrPath = Join-Path $logDir "$task-api.stderr.log"
    $args = @(
      (Join-Path $scriptRoot "real-usage-suite.mjs"),
      "run-api",
      "--task",
      $task,
      "--run-id",
      $runId,
      "--base-url",
      $BaseUrl,
      "--model",
      $Model,
      "--max-attempts",
      "$MaxAttempts",
      "--max-tokens",
      "$MaxTokens",
      "--timeout-ms",
      "$TaskTimeoutMs"
    )
    if (-not [string]::IsNullOrWhiteSpace($ReasoningEffort)) {
      $args += "--reasoning-effort"
      $args += $ReasoningEffort
    }
    if ($DryRun) {
      [void]$rows.Add([pscustomobject]@{
        task = $task
        dryRun = $true
        command = @($node) + $args
        passed = $null
      })
      continue
    }
    $run = Invoke-Capture -FileName $node -Arguments $args -WorkingDirectory $repoRoot -StdoutPath $stdoutPath -StderrPath $stderrPath -TimeoutSeconds ([math]::Ceiling($TaskTimeoutMs / 1000) + 60)
    $summary = $null
    if (Test-Path -LiteralPath $stdoutPath) {
      try { $summary = Get-Content -Raw -LiteralPath $stdoutPath | ConvertFrom-Json } catch {}
    }
    [void]$rows.Add([pscustomobject]@{
      task = $task
      dryRun = $false
      run = $run
      stdoutSummary = $stdoutPath
      passed = if ($summary) { [bool]$summary.passed } else { $false }
      attempts = if ($summary) { @($summary.attempts).Count } else { 0 }
    })
  }
} finally {
  if (-not $DryRun) {
    $restore = Invoke-Capture `
      -FileName "powershell.exe" `
      -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",$loadProfile,"-Profile","restore-initial","-InitialStateJson",$initialState) `
      -WorkingDirectory $repoRoot `
      -StdoutPath (Join-Path $logDir "lmstudio-restore.out.txt") `
      -StderrPath (Join-Path $logDir "lmstudio-restore.err.txt") `
      -TimeoutSeconds 1200
  }
}

$overall = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  runner = "lmstudio-direct-api"
  dryRun = [bool]$DryRun
  runId = $runId
  profile = $Profile
  model = $Model
  baseUrl = $BaseUrl
  reasoningEffort = if ([string]::IsNullOrWhiteSpace($ReasoningEffort)) { $null } else { $ReasoningEffort }
  contextLength = $ContextLength
  parallel = $Parallel
  evalBatchSize = $EvalBatchSize
  physicalBatchSize = $PhysicalBatchSize
  resultDir = $resultDir
  logDir = $logDir
  initialState = $initialState
  load = $load
  tasks = @($rows.ToArray())
  restore = $restore
  passed = if ($DryRun) { $null } else { @($rows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
}
$overallPath = Join-Path $resultDir "lmstudio-real-usage-api-summary.json"
Write-Utf8NoBom -Path $overallPath -Value (($overall | ConvertTo-Json -Depth 20) + "`n")
Write-Output $overallPath
if (-not $DryRun -and -not $overall.passed) { exit 1 }
