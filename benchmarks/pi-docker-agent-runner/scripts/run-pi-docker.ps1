param(
  [string]$Workspace = (Get-Location).Path,
  [string]$BaseUrl = "http://host.docker.internal:1234/v1",
  [string]$Model = "local/qwen3-coder-30b",
  [switch]$Browser,
  [switch]$Build,
  [switch]$DryRun,
  [switch]$NoTty,
  [string]$PlanOutput = "",
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$PiArgs
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$runnerRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$composeFile = Join-Path $runnerRoot "docker-compose.yml"
$workspacePath = (Resolve-Path -LiteralPath $Workspace).Path
$runtimeDir = Join-Path $runnerRoot ".runtime"
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Value
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

$modelsPath = Join-Path $runtimeDir "models.generated.json"
$modelConfig = [ordered]@{
  providers = [ordered]@{
    "local-openai" = [ordered]@{
      baseUrl = $BaseUrl
      api = "openai-completions"
      apiKey = "not-needed"
      compat = [ordered]@{
        supportsStore = $false
        supportsDeveloperRole = $false
        supportsReasoningEffort = $false
        supportsUsageInStreaming = $false
        maxTokensField = "max_tokens"
        supportsStrictMode = $false
      }
      models = @(
        [ordered]@{
          id = $Model
          name = "Local $Model"
          input = @("text")
          contextWindow = 32768
          maxTokens = 4096
          cost = [ordered]@{
            input = 0
            output = 0
            cacheRead = 0
            cacheWrite = 0
          }
        }
      )
    }
  }
}

Write-Utf8NoBom -Path $modelsPath -Value ($modelConfig | ConvertTo-Json -Depth 12)

$env:PI_WORKSPACE = $workspacePath
$env:PI_MODELS_JSON = $modelsPath
$env:OPENAI_API_BASE = $BaseUrl
$env:OPENAI_API_KEY = if ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } else { "not-needed" }
$env:COMPOSE_STATUS_STDOUT = if ($env:COMPOSE_STATUS_STDOUT) { $env:COMPOSE_STATUS_STDOUT } else { "1" }
$forwardedPiArgs = if ($PiArgs) { @($PiArgs) } else { @() }

$service = if ($Browser) { "pi-browser" } else { "pi" }
$composeArgs = @("compose", "--project-directory", $runnerRoot, "-f", $composeFile)
if ($Browser) {
  $composeArgs += @("--profile", "browser")
}

if ($Build) {
  $buildArgs = $composeArgs + @("build", $service)
} else {
  $buildArgs = @()
}

$runArgs = $composeArgs + @("run", "--rm", $service) + $forwardedPiArgs
if ($NoTty) {
  $runArgs = $composeArgs + @("run", "--rm", "-T", $service) + $forwardedPiArgs
}

if ($DryRun) {
  $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
  $plan = [ordered]@{
    createdAt = (Get-Date).ToString("o")
    dryRun = $true
    dockerAvailable = [bool]$dockerCommand
    dockerSource = if ($dockerCommand) { $dockerCommand.Source } else { $null }
    runnerRoot = $runnerRoot
    composeFile = $composeFile
    workspace = $workspacePath
    modelsPath = $modelsPath
    baseUrl = $BaseUrl
    model = $Model
    service = $service
    browser = [bool]$Browser
    build = [bool]$Build
    noTty = [bool]$NoTty
    environment = [ordered]@{
      PI_WORKSPACE = $env:PI_WORKSPACE
      PI_MODELS_JSON = $env:PI_MODELS_JSON
      OPENAI_API_BASE = $env:OPENAI_API_BASE
      OPENAI_API_KEY = $env:OPENAI_API_KEY
    }
    buildCommand = if ($Build) { [object[]](@("docker") + $buildArgs) } else { $null }
    runCommand = [object[]](@("docker") + $runArgs)
  }
  $json = $plan | ConvertTo-Json -Depth 12
  if ($PlanOutput) {
    $planDir = Split-Path -Parent $PlanOutput
    if ($planDir) {
      New-Item -ItemType Directory -Force -Path $planDir | Out-Null
    }
    Write-Utf8NoBom -Path $PlanOutput -Value $json
  }
  Write-Output $json
  exit 0
}

if ($Build) {
  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & docker @buildArgs 2>&1
  $dockerExitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldErrorActionPreference
  if ($dockerExitCode -ne 0) {
    exit $dockerExitCode
  }
}

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& docker @runArgs 2>&1
$dockerExitCode = $LASTEXITCODE
$ErrorActionPreference = $oldErrorActionPreference
exit $dockerExitCode
