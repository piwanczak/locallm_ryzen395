param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8080,
  [int]$ContextSize = 8192,
  [string]$ModelAlias = "qwen/qwen3-coder-30b-q4",
  [string]$ModelPath = "",
  [string[]]$Tasks = @("js-window", "browser-style"),
  [string]$Image = "local/controlled-edit-agent:node24",
  [switch]$Build,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$runnerRoot = Join-Path $repoRoot "benchmarks\docker-controlled-agent-runner"
$dockerfile = Join-Path $runnerRoot "Dockerfile"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-docker-controlled-q4-workflow"
$logRoot = Join-Path $benchRoot "logs\$timestamp-docker-controlled-q4-workflow"
New-Item -ItemType Directory -Force -Path $runRoot, $logRoot | Out-Null

if (-not $ModelPath) {
  $ModelPath = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Value
  )
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

function ConvertTo-ContainerPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  $root = (Resolve-Path -LiteralPath $repoRoot).Path.TrimEnd("\")
  if ($resolved -eq $root) {
    return "/workspace"
  }
  if (-not $resolved.StartsWith($root + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside mounted repo root: $resolved"
  }
  $relative = $resolved.Substring($root.Length + 1) -replace '\\', '/'
  return "/workspace/$relative"
}

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)
  return "'" + ($Value -replace "'", "'\''") + "'"
}

function Invoke-WslBash {
  param([Parameter(Mandatory = $true)][string]$Command)
  & wsl.exe --distribution $Distro --user root -- bash -lc $Command
  if ($LASTEXITCODE -ne 0) {
    throw "WSL command failed with exit code ${LASTEXITCODE}: $Command"
  }
}

function Invoke-DockerCapture {
  param(
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$StdoutPath,
    [Parameter(Mandatory = $true)][string]$StderrPath
  )
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & docker @Arguments 1> $StdoutPath 2> $StderrPath
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  return $exitCode
}

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$repoRootContainer = ConvertTo-ContainerPath $repoRoot
$baseUrl = "http://host.docker.internal:$Port/v1"
$summaryPath = Join-Path $runRoot "docker-controlled-q4-workflow-summary.json"

$imageExists = $false
$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& docker image inspect $Image *> $null
if ($LASTEXITCODE -eq 0) {
  $imageExists = $true
}
$ErrorActionPreference = $oldPreference

$plan = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  dryRun = [bool]$DryRun
  image = $Image
  imageExistsBeforeRun = $imageExists
  buildRequested = [bool]$Build
  distro = $Distro
  port = $Port
  contextSize = $ContextSize
  modelAlias = $ModelAlias
  modelPath = $ModelPath
  baseUrlFromContainer = $baseUrl
  repoRoot = $repoRoot
  runnerRoot = $runnerRoot
  runRoot = $runRoot
  logRoot = $logRoot
  tasks = $selectedTasks
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($plan | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $ModelPath)) {
  throw "Model file missing: $ModelPath"
}

$dockerBuild = [ordered]@{
  attempted = $false
  exitCode = $null
  stdout = $null
  stderr = $null
}

if ($Build -or -not $imageExists) {
  $buildOut = Join-Path $runRoot "docker-build.out.txt"
  $buildErr = Join-Path $runRoot "docker-build.err.txt"
  $dockerBuild.attempted = $true
  $dockerBuild.stdout = $buildOut
  $dockerBuild.stderr = $buildErr
  $dockerBuild.exitCode = Invoke-DockerCapture -Arguments @("build", "-t", $Image, "-f", $dockerfile, $runnerRoot) -StdoutPath $buildOut -StderrPath $buildErr
  if ($dockerBuild.exitCode -ne 0) {
    $plan.dockerBuild = $dockerBuild
    Write-Utf8NoBom -Path $summaryPath -Value ($plan | ConvertTo-Json -Depth 12)
    throw "Docker build failed with exit code $($dockerBuild.exitCode). See $buildOut and $buildErr"
  }
}

$benchRootWsl = ConvertTo-WslPath $benchRoot
$modelPathWsl = ConvertTo-WslPath $ModelPath
$logRootWsl = ConvertTo-WslPath $logRoot
$pidFileWsl = "$logRootWsl/llama-server.pid"
$logFileWsl = "$logRootWsl/llama-server.log"
$readyFileWsl = "$logRootWsl/llama-server.ready.json"

$serverCommand = @(
  "cd $(Quote-Bash $benchRootWsl)",
  "&&",
  "MODEL_PATH=$(Quote-Bash $modelPathWsl)",
  "MODEL_ALIAS=$(Quote-Bash $ModelAlias)",
  "PORT=$Port",
  "CTX_SIZE=$ContextSize",
  "PARALLEL=1",
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

$startedAt = Get-Date
$taskResults = @()
$startOutputPath = Join-Path $runRoot "llama-start.out.txt"
$stopOutputPath = Join-Path $runRoot "llama-stop.out.txt"
$startExitCode = $null
$stopExitCode = $null

try {
  $startOutput = & wsl.exe --distribution $Distro --user root -- bash -lc $serverCommand 2>&1
  $startExitCode = $LASTEXITCODE
  $startOutput | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $startOutputPath -Encoding UTF8
  if ($startExitCode -ne 0) {
    throw "llama-server start failed with exit code $startExitCode"
  }

  foreach ($task in $selectedTasks) {
    $taskOutDir = Join-Path $runRoot $task
    New-Item -ItemType Directory -Force -Path $taskOutDir | Out-Null
    $taskOutDirContainer = ConvertTo-ContainerPath $taskOutDir
    $stdoutPath = Join-Path $runRoot "docker-$task.out.txt"
    $stderrPath = Join-Path $runRoot "docker-$task.err.txt"
    $runId = "docker-controlled-$timestamp-$task"

    $dockerArgs = @(
      "run", "--rm", "--init",
      "--add-host", "host.docker.internal:host-gateway",
      "-v", "${repoRoot}:/workspace",
      "-w", $repoRootContainer,
      $Image,
      "--base-url", $baseUrl,
      "--model", $ModelAlias,
      "--task", $task,
      "--max-attempts", "2",
      "--run-id", $runId,
      "--output-dir", $taskOutDirContainer
    )

    $exitCode = Invoke-DockerCapture -Arguments $dockerArgs -StdoutPath $stdoutPath -StderrPath $stderrPath
    $resultPath = Join-Path $taskOutDir "$task-result.json"
    $passed = $false
    $metrics = $null
    $verification = $null
    if (Test-Path -LiteralPath $resultPath) {
      $parsed = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
      $passed = [bool]$parsed.passed
      $metrics = $parsed.metrics
      $verification = $parsed.verification
    }

    $taskResults += [pscustomobject][ordered]@{
      task = $task
      exitCode = $exitCode
      passed = $passed
      resultPath = $resultPath
      outputDir = $taskOutDir
      stdout = $stdoutPath
      stderr = $stderrPath
      metrics = $metrics
      verification = $verification
    }
  }
} finally {
  $stopOutput = & wsl.exe --distribution $Distro --user root -- bash -lc $stopCommand 2>&1
  $stopExitCode = $LASTEXITCODE
  $stopOutput | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $stopOutputPath -Encoding UTF8
}

$endedAt = Get-Date
$summary = [ordered]@{
  createdAt = $endedAt.ToString("o")
  startedAt = $startedAt.ToString("o")
  dryRun = $false
  image = $Image
  dockerBuild = $dockerBuild
  distro = $Distro
  port = $Port
  contextSize = $ContextSize
  modelAlias = $ModelAlias
  modelPath = $ModelPath
  baseUrlFromContainer = $baseUrl
  repoRoot = $repoRoot
  runnerRoot = $runnerRoot
  runRoot = $runRoot
  logRoot = $logRoot
  startExitCode = $startExitCode
  stopExitCode = $stopExitCode
  startOutput = $startOutputPath
  stopOutput = $stopOutputPath
  serverLog = Join-Path $logRoot "llama-server.log"
  tasks = $taskResults
  passed = ($taskResults.Count -gt 0 -and -not ($taskResults | Where-Object { -not $_.passed -or $_.exitCode -ne 0 }))
}

Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 14)
Write-Output $summaryPath
if (-not $summary.passed) {
  exit 1
}
