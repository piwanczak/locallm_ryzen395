param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8103,
  [int]$ContextSize = 16384,
  [int]$OutputLimit = 2048,
  [int]$TimeoutMinutes = 8,
  [string]$ModelAlias = "qwen/qwen3-coder-30b-q4",
  [string]$ModelPath = "",
  [string[]]$Tasks = @("js-window", "browser-style"),
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$opencodeScript = Join-Path $scriptRoot "run-opencode-wsl-compatible-benchmark.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-16k-opencode-wsl-workflow"
$logRoot = Join-Path $benchRoot "logs\$timestamp-16k-opencode-wsl-workflow"
$summaryPath = Join-Path $runRoot "16k-opencode-wsl-workflow-summary.json"
New-Item -ItemType Directory -Force -Path $runRoot, $logRoot | Out-Null

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
  param([Parameter(Mandatory = $true)][scriptblock]$Command, [Parameter(Mandatory = $true)][string]$OutputPath)
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $Command 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  $output | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  return [pscustomobject]@{ exitCode = $exitCode; outputText = (($output | ForEach-Object { $_.ToString() }) -join "`n") }
}

function Read-JsonOrNull {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
  try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json } catch { return $null }
}

function Read-JsonObjectFromText {
  param([string]$Text)
  if (-not $Text) { return $null }
  $start = $Text.LastIndexOf("{")
  while ($start -ge 0) {
    $candidate = $Text.Substring($start).Trim()
    try { return $candidate | ConvertFrom-Json } catch { $start = $Text.LastIndexOf("{", $start - 1) }
  }
  return $null
}

function Read-JsonLines {
  param([string]$Path)
  $events = @()
  if (-not (Test-Path -LiteralPath $Path)) { return $events }
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $events += ($line | ConvertFrom-Json) } catch {}
  }
  return $events
}

function Get-TaskStatus {
  param($Event)
  $steps = @($Event.opencodeSummary.steps)
  $toolCalls = @($Event.opencodeSummary.toolCalls)
  $firstStep = if ($steps.Count -gt 0) { $steps[0] } else { $null }
  $gradePassed = $false
  if ($Event.grade -and $Event.grade.PSObject.Properties["passed"]) {
    $gradePassed = [bool]$Event.grade.passed
  } elseif ($Event.grade -and $Event.grade.PSObject.Properties["pass"]) {
    $gradePassed = [bool]$Event.grade.pass
  }
  return [pscustomobject]@{
    task = [string]$Event.task
    passed = ($gradePassed -and -not [bool]$Event.opencode.timedOut -and [bool]$Event.canary.unchanged)
    gradePassed = $gradePassed
    timedOut = [bool]$Event.opencode.timedOut
    exitCode = $Event.opencode.exitCode
    elapsedMs = $Event.opencode.elapsedMs
    firstStepInputTokens = $firstStep.inputTokens
    firstStepOutputTokens = $firstStep.outputTokens
    steps = $steps.Count
    toolCalls = $toolCalls.Count
    canaryUnchanged = [bool]$Event.canary.unchanged
    grade = $Event.grade
    stdout = [string]$Event.stdout
    stderr = [string]$Event.stderr
  }
}

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  distro = $Distro
  port = $Port
  contextSize = $ContextSize
  outputLimit = $OutputLimit
  timeoutMinutes = $TimeoutMinutes
  modelAlias = $ModelAlias
  modelPath = $ModelPath
  tasks = $selectedTasks
  runRoot = $runRoot
  logRoot = $logRoot
  serverStart = $null
  serverStop = $null
  opencode = $null
  taskStatus = @()
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $ModelPath)) { throw "Missing model file: $ModelPath" }

$benchRootWsl = ConvertTo-WslPath $benchRoot
$modelPathWsl = ConvertTo-WslPath $ModelPath
$logRootWsl = ConvertTo-WslPath $logRoot
$pidFileWsl = "$logRootWsl/llama-server.pid"
$logFileWsl = "$logRootWsl/llama-server.log"
$readyFileWsl = "$logRootWsl/llama-server.ready.json"
$baseUrl = "http://127.0.0.1:$Port"

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

$startOut = Join-Path $runRoot "llama-start.out.txt"
$stopOut = Join-Path $runRoot "llama-stop.out.txt"
$opencodeOut = Join-Path $runRoot "opencode-wrapper.out.txt"

try {
  $startCapture = Invoke-Capture -OutputPath $startOut -Command {
    & wsl.exe --distribution $Distro --user root -- bash -lc $serverCommand
  }
  $summary.serverStart = [pscustomobject]@{ exitCode = $startCapture.exitCode; outputPath = $startOut }
  if ($startCapture.exitCode -ne 0) { throw "llama-server start failed with exit code $($startCapture.exitCode)" }

  $opencodeCapture = Invoke-Capture -OutputPath $opencodeOut -Command {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $opencodeScript `
      -BaseUrl $baseUrl `
      -Model $ModelAlias `
      -Tasks ($selectedTasks -join ",") `
      -ContextLimit $ContextSize `
      -OutputLimit $OutputLimit `
      -PromptSourceMode thin `
      -PromptPaddingMode none `
      -TimeoutMinutes $TimeoutMinutes `
      -ProxyPort ($Port + 100)
  }
  $runInfo = Read-JsonObjectFromText -Text $opencodeCapture.outputText
  $summary.opencode = [pscustomobject]@{
    exitCode = $opencodeCapture.exitCode
    outputPath = $opencodeOut
    runInfo = $runInfo
  }

  if ($runInfo -and $runInfo.summaryJsonl) {
    $events = Read-JsonLines -Path ([string]$runInfo.summaryJsonl)
    $taskEvents = @($events | Where-Object { $_.event -eq "task_run" })
    $summary.taskStatus = @($taskEvents | ForEach-Object { Get-TaskStatus -Event $_ })
  }
} finally {
  $stopCapture = Invoke-Capture -OutputPath $stopOut -Command {
    & wsl.exe --distribution $Distro --user root -- bash -lc $stopCommand
  }
  $summary.serverStop = [pscustomobject]@{ exitCode = $stopCapture.exitCode; outputPath = $stopOut }
}

$summary.completedAt = (Get-Date).ToString("o")
$summary.passed = (
  $summary.serverStart.exitCode -eq 0 -and
  $summary.serverStop.exitCode -eq 0 -and
  $summary.opencode.exitCode -eq 0 -and
  @($summary.taskStatus).Count -eq $selectedTasks.Count -and
  @($summary.taskStatus | Where-Object { -not $_.passed }).Count -eq 0
)
Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 18)
Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
