param(
  [string[]]$Tasks = @("backend-api"),
  [string]$BaseUrl = "http://host.docker.internal:8080/v1",
  [string]$Model = "qwen/qwen3-coder-30b-q4",
  [int]$TaskTimeoutSeconds = 900,
  [bool]$GuardWorkspace = $true,
  [string]$AppendSystemPrompt = "",
  [string[]]$PiArgs = @(),
  [switch]$Build,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$node = if ($env:NODE_EXE) { $env:NODE_EXE } else { "node" }
$piRunner = Join-Path $repoRoot "benchmarks\pi-docker-agent-runner\scripts\run-pi-docker.ps1"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runId = "$stamp-pi-real-usage"
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

function Quote-PowerShellSingle {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
  return "'" + ($Value -replace "'", "''") + "'"
}

function Invoke-Capture {
  param(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [string]$StdoutPath,
    [string]$StderrPath,
    [int]$TimeoutSeconds,
    [scriptblock]$OnTimeout = $null
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
    try {
      $taskkill = Join-Path $env:SystemRoot "System32\taskkill.exe"
      if (Test-Path -LiteralPath $taskkill) {
        & $taskkill /PID $process.Id /T /F | Out-Null
      } else {
        $process.Kill($true)
      }
    } catch {
      try { $process.Kill($true) } catch {}
    }
    if ($OnTimeout) {
      try { & $OnTimeout } catch {}
    }
    try { [void]$process.WaitForExit(10000) } catch {}
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

function Get-RunningPiContainerIds {
  try {
    @(docker ps --filter "name=pi-docker-agent-runner-pi" --format "{{.ID}}" 2>$null)
  } catch {
    @()
  }
}

function Stop-NewPiContainers {
  param([string[]]$BeforeIds)
  $before = New-Object "System.Collections.Generic.HashSet[string]"
  foreach ($id in @($BeforeIds)) { [void]$before.Add($id) }
  foreach ($id in @(Get-RunningPiContainerIds)) {
    if (-not $before.Contains($id)) {
      try { docker stop $id | Out-Null } catch {}
    }
  }
}

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$rows = New-Object System.Collections.ArrayList

foreach ($task in $selectedTasks) {
  $prepareJson = & $node (Join-Path $scriptRoot "real-usage-suite.mjs") prepare --task $task --run-id $runId --result-dir $resultDir
  if ($LASTEXITCODE -ne 0) { throw "prepare failed for $task" }
  $prepared = $prepareJson | ConvertFrom-Json
  $planPath = Join-Path $resultDir "$task-pi-plan.json"
  $agentPromptPath = Join-Path $resultDir "$task-pi-agent-prompt.md"
  $stdoutPath = Join-Path $logDir "$task-pi.out.txt"
  $stderrPath = Join-Path $logDir "$task-pi.err.txt"
  $verifyPath = Join-Path $resultDir "$task-pi-verification.json"
  $summaryPath = Join-Path $resultDir "$task-pi-summary.json"
  $invokeScriptPath = Join-Path $resultDir "$task-pi-invoke.ps1"
  $browser = $task -eq "frontend-filter"
  & $node (Join-Path $scriptRoot "real-usage-suite.mjs") agent-prompt --task $task --workspace $prepared.workspace --output $agentPromptPath | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "agent prompt generation failed for $task" }
  if (-not [string]::IsNullOrWhiteSpace($AppendSystemPrompt)) {
    $basePrompt = Get-Content -Raw -LiteralPath $agentPromptPath
    $promptWithCompatibilityNote = "Local endpoint tool-call compatibility note:`r`n$AppendSystemPrompt`r`n`r`n---`r`n`r`n$basePrompt"
    Write-Utf8NoBom -Path $agentPromptPath -Value $promptWithCompatibilityNote
  }
  $runnerArgs = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $piRunner,
    "-Workspace",
    $prepared.workspace,
    "-BaseUrl",
    $BaseUrl,
    "-Model",
    $Model,
    "-NoTty",
    "-PlanOutput",
    $planPath,
    "-PromptFile",
    $agentPromptPath
  )
  $editablePaths = @()
  if ($prepared.PSObject.Properties.Name -contains "editable" -and $null -ne $prepared.editable) {
    $editablePaths = @($prepared.editable | Where-Object { $_ })
  }
  $allowedGenerated = @()
  if ($prepared.PSObject.Properties.Name -contains "allowedGenerated" -and $null -ne $prepared.allowedGenerated) {
    $allowedGenerated = @($prepared.allowedGenerated | Where-Object { $_ })
  }
  $guardEnabledForTask = $GuardWorkspace -and ($allowedGenerated.Count -eq 0)
  if ($guardEnabledForTask) {
    $runnerArgs += "-ReadOnlyWorkspace"
    foreach ($editablePath in $editablePaths) {
      $runnerArgs += @("-WritablePaths", [string]$editablePath)
    }
  }
  if ($browser) { $runnerArgs += "-Browser" }
  if ($Build) { $runnerArgs += "-Build" }
  if ($DryRun) { $runnerArgs += "-DryRun" }
  if ($PiArgs.Count -gt 0) {
    $runnerArgs += "-PiArgs"
    $runnerArgs += $PiArgs
  }

  $beforePiContainers = @(Get-RunningPiContainerIds)
  $piArgsLiteral = ($runnerArgs | ForEach-Object { "  $(Quote-PowerShellSingle $_)" }) -join ",`r`n"
  Write-Utf8NoBom -Path $invokeScriptPath -Value @"
`$ErrorActionPreference = "Stop"
`$runnerArgs = @(
$piArgsLiteral
)
& powershell.exe @runnerArgs
exit `$LASTEXITCODE
"@
  $run = Invoke-Capture -FileName "powershell.exe" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $invokeScriptPath) -WorkingDirectory $repoRoot -StdoutPath $stdoutPath -StderrPath $stderrPath -TimeoutSeconds $TaskTimeoutSeconds -OnTimeout {
    Stop-NewPiContainers -BeforeIds $beforePiContainers
  }
  if (-not $DryRun) {
    & $node (Join-Path $scriptRoot "real-usage-suite.mjs") verify --task $task --workspace $prepared.workspace --manifest-before $prepared.manifestBefore --output $verifyPath | Out-Null
    & $node (Join-Path $scriptRoot "real-usage-suite.mjs") summarize-pi --stdout $stdoutPath --verification $verifyPath --run-start-ms "$($run.startedAtUnixMs)" --run-end-ms "$($run.endedAtUnixMs)" --output $summaryPath | Out-Null
  }
  $verify = if ((-not $DryRun) -and (Test-Path -LiteralPath $verifyPath)) { Get-Content -Raw -LiteralPath $verifyPath | ConvertFrom-Json } else { $null }
  $summary = if ((-not $DryRun) -and (Test-Path -LiteralPath $summaryPath)) { Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json } else { $null }
  $verifierPassed = if ($DryRun -or -not $verify) { $null } else { $verify.passed -eq $true }
  [void]$rows.Add([pscustomobject]@{
    task = $task
    dryRun = [bool]$DryRun
    browser = $browser
    workspace = $prepared.workspace
    promptPath = $prepared.promptPath
    agentPromptPath = $agentPromptPath
    invokeScript = $invokeScriptPath
    plan = $planPath
    guardWorkspace = $guardEnabledForTask
    run = $run
    runnerCompleted = if ($DryRun) { $null } else { $run.exitCode -eq 0 }
    runnerTimedOut = if ($DryRun) { $null } else { $run.timedOut -eq $true }
    verifierPassed = $verifierPassed
    verification = $verifyPath
    summary = $summaryPath
    metrics = if ($summary) { $summary.metrics } else { $null }
    toolCallCount = if ($summary) { $summary.toolCallCount } else { $null }
    failedToolCalls = if ($summary) { $summary.failedToolCalls } else { $null }
    passed = if ($DryRun) { $null } else { $verifierPassed }
  })
}

$overall = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  runner = "pi-docker"
  dryRun = [bool]$DryRun
  runId = $runId
  baseUrl = $BaseUrl
  model = $Model
  appendSystemPrompt = $AppendSystemPrompt
  piArgs = @($PiArgs)
  resultDir = $resultDir
  logDir = $logDir
  tasks = @($rows.ToArray())
  passed = if ($DryRun) { $null } else { @($rows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
}
$overallPath = Join-Path $resultDir "pi-real-usage-summary.json"
Write-Utf8NoBom -Path $overallPath -Value (($overall | ConvertTo-Json -Depth 20) + "`n")
Write-Output $overallPath
if (-not $DryRun -and -not $overall.passed) { exit 1 }
