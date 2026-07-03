param(
  [string[]]$Models = @("qwen3-coder:30b", "gemma3n:e4b", "gemma3:12b"),
  [string[]]$Tasks = @("backend-api", "schema-validation", "frontend-filter"),
  [string]$BaseUrl = "http://127.0.0.1:11434/v1",
  [string]$EndpointName = "windows",
  [int]$MaxAttempts = 2,
  [int]$MaxTokens = 4096,
  [int]$ContextLength = 0,
  [int]$TaskTimeoutMs = 300000,
  [string]$Transport = "openai",
  [double]$Temperature = 0,
  [double]$TopP = 1,
  [int]$TopK = 0,
  [string]$Think = "",
  [string]$PromptExtra = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$node = if ($env:NODE_EXE) { $env:NODE_EXE } else { "node" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$safeEndpoint = $EndpointName -replace '[^A-Za-z0-9_.-]', '_'
$runId = "$stamp-ollama-$safeEndpoint-direct-matrix"
$resultDir = Join-Path $benchRoot "results\$runId"
$logDir = Join-Path $benchRoot "logs\$runId"
New-Item -ItemType Directory -Force -Path $resultDir,$logDir | Out-Null

function ConvertTo-LongPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  if ($full.StartsWith("\\?\")) { return $full }
  if ($full.StartsWith("\\")) { return "\\?\UNC\" + $full.Substring(2) }
  return "\\?\" + $full
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
  )
  $dir = Split-Path -Parent $Path
  if ($dir) { [System.IO.Directory]::CreateDirectory((ConvertTo-LongPath $dir)) | Out-Null }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((ConvertTo-LongPath $Path), $Value, $utf8NoBom)
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
    [int]$TimeoutSeconds = 600
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

function Get-AttemptForMetrics {
  param($Summary)
  $attempts = @($Summary.attempts)
  if ($attempts.Count -eq 0) { return $null }
  $passed = @($attempts | Where-Object { $_.passed -eq $true })
  if ($passed.Count -gt 0) { return $passed[-1] }
  return $attempts[-1]
}

$selectedModels = @($Models | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$rows = New-Object System.Collections.ArrayList

foreach ($model in $selectedModels) {
  $safeModel = ConvertTo-SafeName $model
  $modelRunId = "$runId-$safeModel"
  $taskRows = New-Object System.Collections.ArrayList
  foreach ($task in $selectedTasks) {
    $stdoutPath = Join-Path $logDir "$safeModel-$task-api.stdout.json"
    $stderrPath = Join-Path $logDir "$safeModel-$task-api.stderr.log"
    $args = @(
      (Join-Path $scriptRoot "real-usage-suite.mjs"),
      "run-api",
      "--task",
      $task,
      "--run-id",
      $modelRunId,
      "--base-url",
      $BaseUrl,
      "--model",
      $model,
      "--max-attempts",
      "$MaxAttempts",
      "--max-tokens",
      "$MaxTokens",
      "--context-length",
      "$ContextLength",
      "--timeout-ms",
      "$TaskTimeoutMs"
    )
    if (-not [string]::IsNullOrWhiteSpace($Transport)) {
      $args += @("--transport", $Transport)
    }
    $args += @("--temperature", "$Temperature")
    $args += @("--top-p", "$TopP")
    if ($TopK -gt 0) {
      $args += @("--top-k", "$TopK")
    }
    if (-not [string]::IsNullOrWhiteSpace($Think)) {
      $args += @("--think", $Think)
    }
    if (-not [string]::IsNullOrWhiteSpace($PromptExtra)) {
      $args += @("--prompt-extra", $PromptExtra)
    }
    if ($DryRun) {
      [void]$taskRows.Add([pscustomobject]@{
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
    $attemptForMetrics = if ($summary) { Get-AttemptForMetrics -Summary $summary } else { $null }
    $attemptNo = if ($attemptForMetrics) { [int]$attemptForMetrics.attempt } else { 0 }
    $verificationPath = if ($summary -and $attemptNo -gt 0) {
      Join-Path $summary.resultDir ("{0}-api-attempt{1}-verification.json" -f $task, $attemptNo.ToString().PadLeft(2, "0"))
    } else {
      $null
    }
    [void]$taskRows.Add([pscustomobject]@{
      task = $task
      dryRun = $false
      run = $run
      stdoutSummary = $stdoutPath
      verification = $verificationPath
      passed = if ($summary) { [bool]$summary.passed } else { $false }
      attempts = if ($summary) { @($summary.attempts).Count } else { 0 }
      metrics = if ($attemptForMetrics) { $attemptForMetrics.metrics } else { $null }
    })
  }
  [void]$rows.Add([pscustomobject]@{
    model = $model
    dryRun = [bool]$DryRun
    summaryPath = $null
    passed = if ($DryRun) { $null } else { @($taskRows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
    taskRows = @($taskRows.ToArray())
  })
}

$overall = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  runner = "ollama-direct-api-matrix"
  dryRun = [bool]$DryRun
  runId = $runId
  endpointName = $EndpointName
  baseUrl = $BaseUrl
  maxAttempts = $MaxAttempts
  maxTokens = $MaxTokens
  contextLength = $ContextLength
  taskTimeoutMs = $TaskTimeoutMs
  tasks = $selectedTasks
  resultDir = $resultDir
  logDir = $logDir
  rows = @($rows.ToArray())
  passed = if ($DryRun) { $null } else { @($rows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
}
$overallPath = Join-Path $resultDir "ollama-direct-api-matrix-summary.json"
Write-Utf8NoBom -Path $overallPath -Value (($overall | ConvertTo-Json -Depth 40) + "`n")
Write-Output $overallPath
if (-not $DryRun -and -not $overall.passed) { exit 1 }
