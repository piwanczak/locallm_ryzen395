param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8080,
  [int]$ContextSize = 8192,
  [int]$Parallel = 1,
  [int]$CalibrationMaxTokens = 128,
  [int]$CalibrationConcurrency = 1,
  [int]$AgentMaxTokens = 2048,
  [int]$AgentMaxAttempts = 2,
  [switch]$SkipAgent,
  [string[]]$AgentTasks = @("js-window"),
  [string[]]$Models = @("gemma-4-e4b-q4", "qwen25-coder-15b-q4")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-model-matrix"
$logRoot = Join-Path $benchRoot "logs\$timestamp-model-matrix"
New-Item -ItemType Directory -Force -Path $runRoot, $logRoot | Out-Null

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

function Invoke-WslBash {
  param([Parameter(Mandatory = $true)][string]$Command)
  & wsl.exe --distribution $Distro --user root -- bash -lc $Command
  if ($LASTEXITCODE -ne 0) {
    throw "WSL command failed with exit code ${LASTEXITCODE}: $Command"
  }
}

$modelCatalog = [ordered]@{
  "qwen3-coder-30b-q2" = [ordered]@{
    Alias = "qwen/qwen3-coder-30b-q2"
    Path = Join-Path $repoRoot "downloads\Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf"
  }
  "qwen3-coder-30b-q4" = [ordered]@{
    Alias = "qwen/qwen3-coder-30b-q4"
    Path = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
  }
  "gemma-4-e4b-q4" = [ordered]@{
    Alias = "google/gemma-4-e4b-it-q4"
    Path = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\gemma-4-E4B-it-GGUF\gemma-4-E4B-it-Q4_K_M.gguf"
  }
  "qwen25-coder-15b-q4" = [ordered]@{
    Alias = "qwen/qwen2.5-coder-1.5b-q4"
    Path = Join-Path $env:USERPROFILE ".lmstudio\models\bartowski\Qwen2.5-Coder-1.5B-Instruct-GGUF\Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf"
  }
  "qwen25-coder-15b-q8" = [ordered]@{
    Alias = "qwen/qwen2.5-coder-1.5b-q8"
    Path = Join-Path $env:USERPROFILE ".lmstudio\models\bartowski\Qwen2.5-Coder-1.5B-Instruct-GGUF\Qwen2.5-Coder-1.5B-Instruct-Q8_0.gguf"
  }
  "qwen3-06b-q4" = [ordered]@{
    Alias = "qwen/qwen3-0.6b-q4"
    Path = Join-Path $env:USERPROFILE ".lmstudio\models\unsloth\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q4_K_M.gguf"
  }
}

$benchRootWsl = ConvertTo-WslPath $benchRoot
$modelResults = @()
$selectedModels = @($Models | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedAgentTasks = @($AgentTasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

foreach ($modelKey in $selectedModels) {
  if (-not $modelCatalog.Contains($modelKey)) {
    throw "Unknown model key '$modelKey'. Known: $($modelCatalog.Keys -join ', ')"
  }

  $model = $modelCatalog[$modelKey]
  if (-not (Test-Path -LiteralPath $model.Path)) {
    throw "Model file missing for ${modelKey}: $($model.Path)"
  }

  $modelPathWsl = ConvertTo-WslPath $model.Path
  $modelLogDir = Join-Path $logRoot $modelKey
  New-Item -ItemType Directory -Force -Path $modelLogDir | Out-Null
  $modelLogDirWsl = ConvertTo-WslPath $modelLogDir
  $pidFileWsl = "$modelLogDirWsl/llama-server.pid"
  $logFileWsl = "$modelLogDirWsl/llama-server.log"
  $readyFileWsl = "$modelLogDirWsl/llama-server.ready.json"

  $serverEnv = @(
    "cd $(Quote-Bash $benchRootWsl)",
    "&&",
    "MODEL_PATH=$(Quote-Bash $modelPathWsl)",
    "MODEL_ALIAS=$(Quote-Bash $model.Alias)",
    "PORT=$Port",
    "CTX_SIZE=$ContextSize",
    "PARALLEL=$Parallel",
    "LOG_DIR=$(Quote-Bash $modelLogDirWsl)",
    "PID_FILE=$(Quote-Bash $pidFileWsl)",
    "LOG_FILE=$(Quote-Bash $logFileWsl)",
    "READY_FILE=$(Quote-Bash $readyFileWsl)",
    "bash scripts/start-wsl-llama-server-amd.sh"
  ) -join " "

  $stopCommand = @(
    "cd $(Quote-Bash $benchRootWsl)",
    "&&",
    "LOG_DIR=$(Quote-Bash $modelLogDirWsl)",
    "PID_FILE=$(Quote-Bash $pidFileWsl)",
    "bash scripts/stop-wsl-llama-server-amd.sh"
  ) -join " "

  $entry = [ordered]@{
    key = $modelKey
    alias = $model.Alias
    path = $model.Path
    contextSize = $ContextSize
    parallel = $Parallel
    port = $Port
    logDir = $modelLogDir
    calibration = $null
    agent = [ordered]@{}
    error = $null
  }

  try {
    Invoke-WslBash $serverEnv

    $calibrationShape = if ($CalibrationConcurrency -eq 1) { "single" } else { "${CalibrationConcurrency}way" }
    $calibrationOut = Join-Path $runRoot "$modelKey-calibration-$calibrationShape.json"
    & node (Join-Path $scriptRoot "run-openai-compatible-calibration.mjs") `
      --base-url "http://127.0.0.1:$Port/v1" `
      --model $model.Alias `
      --max-tokens $CalibrationMaxTokens `
      --concurrency $CalibrationConcurrency `
      --output $calibrationOut
    if ($LASTEXITCODE -ne 0) {
      throw "Calibration failed for $modelKey with exit code $LASTEXITCODE"
    }
    $entry.calibration = $calibrationOut

    if (-not $SkipAgent) {
      foreach ($task in $selectedAgentTasks) {
        $agentOutDir = Join-Path $runRoot "$modelKey-$task"
        & node (Join-Path $scriptRoot "run-controlled-edit-agent.mjs") `
          --base-url "http://127.0.0.1:$Port/v1" `
          --model $model.Alias `
          --task $task `
          --max-tokens $AgentMaxTokens `
          --max-attempts $AgentMaxAttempts `
          --run-id "controlled-$timestamp-$modelKey-$task" `
          --output-dir $agentOutDir
        if ($LASTEXITCODE -ne 0) {
          throw "Controlled agent task '$task' failed for $modelKey with exit code $LASTEXITCODE"
        }
        $entry.agent[$task] = Join-Path $agentOutDir "$task-result.json"
      }
    }
  } catch {
    $entry.error = $_.Exception.Message
  } finally {
    try {
      Invoke-WslBash $stopCommand
    } catch {
      $entry.stopError = $_.Exception.Message
    }
  }

  $modelResults += [pscustomobject]$entry
}

$summary = [ordered]@{
  runId = "$timestamp-model-matrix"
  createdAt = (Get-Date).ToString("o")
  distro = $Distro
  port = $Port
  contextSize = $ContextSize
  parallel = $Parallel
  calibrationMaxTokens = $CalibrationMaxTokens
  calibrationConcurrency = $CalibrationConcurrency
  agentMaxTokens = $AgentMaxTokens
  agentMaxAttempts = $AgentMaxAttempts
  agentTasks = $selectedAgentTasks
  skipAgent = [bool]$SkipAgent
  resultRoot = $runRoot
  logRoot = $logRoot
  models = $modelResults
}

$summaryPath = Join-Path $runRoot "model-matrix-summary.json"
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Output $summaryPath
