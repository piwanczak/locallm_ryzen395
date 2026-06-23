param(
  [string]$Workspace = (Get-Location).Path,
  [string]$BaseUrl = "http://host.docker.internal:1234/v1",
  [string]$Model = "local/qwen3-coder-30b",
  [switch]$Browser,
  [switch]$Build,
  [switch]$DryRun,
  [switch]$NoTty,
  [switch]$ReadOnlyWorkspace,
  [string[]]$WritablePaths = @(),
  [string]$PlanOutput = "",
  [string]$Prompt = "",
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

function ConvertTo-ContainerRelativePath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $normalized = ($Path -replace '\\', '/').Trim("/")
  if ([string]::IsNullOrWhiteSpace($normalized) -or
      [System.IO.Path]::IsPathRooted($normalized) -or
      $normalized.Split("/") -contains "..") {
    throw "Writable path must be workspace-relative and safe: $Path"
  }
  return $normalized
}

$modelsPath = Join-Path $runtimeDir "models.generated.json"
$promptPath = Join-Path $runtimeDir "prompt.generated.md"
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
Write-Utf8NoBom -Path $promptPath -Value $Prompt

$env:PI_WORKSPACE = $workspacePath
$env:PI_MODELS_JSON = $modelsPath
$env:PI_PROMPT_FILE = $promptPath
$env:OPENAI_API_BASE = $BaseUrl
$env:OPENAI_API_KEY = if ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } else { "not-needed" }
$env:COMPOSE_STATUS_STDOUT = if ($env:COMPOSE_STATUS_STDOUT) { $env:COMPOSE_STATUS_STDOUT } else { "1" }
$forwardedPiArgs = if ($PiArgs) { @($PiArgs) } else { @() }
if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
  $forwardedPiArgs += @(
    "--model",
    "local-openai/$Model",
    "--thinking",
    "off",
    "--tools",
    "read,bash,edit,write,grep,find,ls",
    "--no-session",
    "--approve",
    "--offline",
    "--mode",
    "json",
    "-p",
    "@/root/.pi/agent/prompt.md"
  )
}

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

$image = if ($Browser) { "local/pi-agent:browser" } else { "local/pi-agent:base" }

if ($ReadOnlyWorkspace) {
  $agentPath = Join-Path $runnerRoot "agent\AGENTS.md"
  $runArgs = @(
    "run",
    "--rm",
    "--init",
    "--workdir",
    "/workspace",
    "--add-host",
    "host.docker.internal:host-gateway",
    "--security-opt",
    "no-new-privileges:true",
    "-e",
    "OPENAI_API_BASE=$($env:OPENAI_API_BASE)",
    "-e",
    "OPENAI_API_KEY=$($env:OPENAI_API_KEY)",
    "-e",
    "ANTHROPIC_API_KEY=$($env:ANTHROPIC_API_KEY)",
    "-e",
    "GEMINI_API_KEY=$($env:GEMINI_API_KEY)",
    "-e",
    "MISTRAL_API_KEY=$($env:MISTRAL_API_KEY)",
    "-e",
    "OPENROUTER_API_KEY=$($env:OPENROUTER_API_KEY)",
    "--mount",
    "type=bind,source=$workspacePath,target=/workspace,readonly",
    "--mount",
    "type=bind,source=$modelsPath,target=/root/.pi/agent/models.json,readonly",
    "--mount",
    "type=bind,source=$promptPath,target=/root/.pi/agent/prompt.md,readonly",
    "--mount",
    "type=bind,source=$agentPath,target=/root/.pi/agent/AGENTS.md,readonly",
    "--mount",
    "type=volume,source=pi-agent-sessions,target=/root/.pi/agent/sessions"
  )
  foreach ($writablePath in @($WritablePaths)) {
    $rel = ConvertTo-ContainerRelativePath -Path $writablePath
    $hostPath = Join-Path $workspacePath ($rel -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $hostPath -PathType Leaf)) {
      throw "Writable file does not exist for guarded mount: $hostPath"
    }
    $runArgs += @("--mount", "type=bind,source=$hostPath,target=/workspace/$rel")
  }
  $runArgs += $image
  $runArgs += $forwardedPiArgs
} else {
  $runArgs = $composeArgs + @("run", "--rm", $service) + $forwardedPiArgs
  if ($NoTty) {
    $runArgs = $composeArgs + @("run", "--rm", "-T", $service) + $forwardedPiArgs
  }
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
    readOnlyWorkspace = [bool]$ReadOnlyWorkspace
    writablePaths = @($WritablePaths)
    environment = [ordered]@{
      PI_WORKSPACE = $env:PI_WORKSPACE
      PI_MODELS_JSON = $env:PI_MODELS_JSON
      PI_PROMPT_FILE = $env:PI_PROMPT_FILE
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
