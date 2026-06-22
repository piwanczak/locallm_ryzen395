param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$PortBase = 8091,
  [int]$ContextSize = 8192,
  [string]$ModelAlias = "qwen/qwen3-coder-30b-q4",
  [string]$ModelPath = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-runner-comparison"
$summaryPath = Join-Path $runRoot "runner-comparison-summary.json"
$piWorkflowScript = Join-Path $scriptRoot "run-pi-jinja-q4-toolcall-workflow.ps1"
$dockerControlledScript = Join-Path $scriptRoot "run-docker-controlled-q4-workflow.ps1"
$recommendedScript = Join-Path $scriptRoot "run-recommended-q4-workflow.ps1"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

if (-not $ModelPath) {
  $ModelPath = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
}

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
  return $exitCode
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

function New-RunnerResult {
  param(
    [string]$Runner,
    [int]$ExitCode,
    [string]$StdoutPath,
    [string]$SummaryPath,
    [object]$ParsedSummary
  )
  $taskStatus = @()
  $passed = $false
  $notes = @()

  if ($Runner -eq "pi-docker" -and $ParsedSummary) {
    $passed = [bool]$ParsedSummary.passed
    $taskStatus = @($ParsedSummary.taskResults | ForEach-Object {
      $verifier = $_.verifierOutputPath
      if (-not $verifier) { $verifier = $_.afterVerifierOutputPath }
      [pscustomobject]@{ task = $_.task; passed = [bool]$_.passed; exitCode = $_.piExitCode; verifier = $verifier; sessionLog = $_.sessionLog }
    })
  } elseif ($Runner -eq "docker-controlled" -and $ParsedSummary) {
    $passed = [bool]$ParsedSummary.passed
    $taskStatus = @($ParsedSummary.tasks | ForEach-Object {
      [pscustomobject]@{ task = $_.task; passed = [bool]$_.passed; exitCode = $_.exitCode; verifier = $_.resultPath; sessionLog = $null }
    })
  } elseif ($Runner -eq "host-controlled" -and $ParsedSummary) {
    $jsResultPath = [string]$ParsedSummary.jsWindowResult
    $browserResultPath = [string]$ParsedSummary.browserStyleResult
    $jsResult = $null
    $browserResult = $null
    if ($jsResultPath -and (Test-Path -LiteralPath $jsResultPath)) {
      $jsResult = Get-Content -Raw -LiteralPath $jsResultPath | ConvertFrom-Json
    }
    if ($browserResultPath -and (Test-Path -LiteralPath $browserResultPath)) {
      $browserResult = Get-Content -Raw -LiteralPath $browserResultPath | ConvertFrom-Json
    }
    $jsPassed = if ($jsResult) { [bool]$jsResult.passed } else { $false }
    $browserPassed = if ($browserResult) { [bool]$browserResult.passed } else { $false }
    $passed = ($jsPassed -and $browserPassed -and $ExitCode -eq 0)
    $taskStatus = @(
      [pscustomobject]@{ task = "js-window"; passed = $jsPassed; exitCode = $null; verifier = $jsResultPath; sessionLog = $null },
      [pscustomobject]@{ task = "browser-style"; passed = $browserPassed; exitCode = $null; verifier = $browserResultPath; sessionLog = $null }
    )
  } else {
    $notes += "summary missing or unrecognized"
  }

  if ($ExitCode -ne 0) {
    $notes += "runner exit code $ExitCode"
  }

  return [pscustomobject]@{
    runner = $Runner
    exitCode = $ExitCode
    passed = ($ExitCode -eq 0 -and $passed)
    stdout = $StdoutPath
    summaryPath = $SummaryPath
    taskStatus = $taskStatus
    notes = $notes
  }
}

function Invoke-Runner {
  param(
    [Parameter(Mandatory = $true)][string]$Runner,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  $runnerDir = Join-Path $runRoot $Runner
  New-Item -ItemType Directory -Force -Path $runnerDir | Out-Null
  $stdoutPath = Join-Path $runnerDir "$Runner.out.txt"
  $exitPath = Join-Path $runnerDir "$Runner.exitcode.txt"
  $startedAt = Get-Date
  $exitCode = Invoke-Capture -OutputPath $stdoutPath -Command $Command
  $completedAt = Get-Date
  Set-Content -LiteralPath $exitPath -Encoding ASCII -Value $exitCode
  $candidateSummary = Find-SummaryPath -OutputPath $stdoutPath
  $parsed = $null
  if ($candidateSummary) {
    try { $parsed = Get-Content -Raw -LiteralPath $candidateSummary | ConvertFrom-Json } catch { $parsed = $null }
  }
  $result = New-RunnerResult -Runner $Runner -ExitCode $exitCode -StdoutPath $stdoutPath -SummaryPath $candidateSummary -ParsedSummary $parsed
  $result | Add-Member -NotePropertyName startedAt -NotePropertyValue $startedAt.ToString("o")
  $result | Add-Member -NotePropertyName completedAt -NotePropertyValue $completedAt.ToString("o")
  $result | Add-Member -NotePropertyName durationSeconds -NotePropertyValue ([math]::Round(($completedAt - $startedAt).TotalSeconds, 3))
  return $result
}

$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  distro = $Distro
  modelAlias = $ModelAlias
  modelPath = $ModelPath
  contextSize = $ContextSize
  runRoot = $runRoot
  runners = @()
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $ModelPath)) { throw "Missing model file: $ModelPath" }

$runnerResults = New-Object System.Collections.ArrayList

[void]$runnerResults.Add((Invoke-Runner -Runner "pi-docker" -Command {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $piWorkflowScript `
    -Distro $Distro `
    -Port $PortBase `
    -ContextSize $ContextSize `
    -ModelAlias $ModelAlias `
    -ModelPath $ModelPath `
    -Tasks file-create,js-edit,browser-style
}))

[void]$runnerResults.Add((Invoke-Runner -Runner "docker-controlled" -Command {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dockerControlledScript `
    -Distro $Distro `
    -Port ($PortBase + 1) `
    -ContextSize $ContextSize `
    -ModelAlias $ModelAlias `
    -ModelPath $ModelPath `
    -Tasks js-window,browser-style
}))

[void]$runnerResults.Add((Invoke-Runner -Runner "host-controlled" -Command {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $recommendedScript `
    -Distro $Distro `
    -Model qwen3-coder-30b-q4 `
    -AgentContextSize $ContextSize `
    -SkipThroughput
}))

$summary.runners = @($runnerResults.ToArray())
$summary.completedAt = (Get-Date).ToString("o")
$summary.passed = (
  @($summary.runners).Count -eq 3 -and
  @($summary.runners | Where-Object { -not $_.passed }).Count -eq 0
)

Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 18)
Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
