param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8091,
  [string[]]$Variants = @("q4-ctx8192", "q4-ctx4096", "q2-ctx8192"),
  [string[]]$Tasks = @("file-create", "js-edit", "browser-style"),
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$workflowScript = Join-Path $scriptRoot "run-pi-jinja-q4-toolcall-workflow.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-pi-endpoint-comparison"
$summaryPath = Join-Path $runRoot "pi-endpoint-comparison-summary.json"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

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

function Get-VariantConfig {
  param([Parameter(Mandatory = $true)][string]$Variant)
  $q4Path = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
  $q2Path = Join-Path $repoRoot "downloads\Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf"
  if (-not (Test-Path -LiteralPath $q2Path)) {
    $q2Path = Join-Path $env:USERPROFILE ".lmstudio\models\unsloth\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf"
  }

  if ($Variant -eq "q4-ctx8192") {
    return [pscustomobject]@{ key = $Variant; modelAlias = "qwen/qwen3-coder-30b-q4"; modelPath = $q4Path; contextSize = 8192; note = "baseline Q4, 8k context" }
  }
  if ($Variant -eq "q4-ctx4096") {
    return [pscustomobject]@{ key = $Variant; modelAlias = "qwen/qwen3-coder-30b-q4"; modelPath = $q4Path; contextSize = 4096; note = "same Q4 quant, lower 4k context" }
  }
  if ($Variant -eq "q2-ctx8192") {
    return [pscustomobject]@{ key = $Variant; modelAlias = "qwen/qwen3-coder-30b-q2"; modelPath = $q2Path; contextSize = 8192; note = "Q2 quant, 8k context" }
  }
  throw "Unknown endpoint variant '$Variant'. Known variants: q4-ctx8192, q4-ctx4096, q2-ctx8192"
}

$selectedVariants = @($Variants | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$variantRows = New-Object System.Collections.ArrayList

$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  distro = $Distro
  port = $Port
  variants = $selectedVariants
  tasks = $selectedTasks
  runRoot = $runRoot
  rows = @()
  comparisonCompleted = $false
  promotedVariant = $null
  recommendation = $null
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

foreach ($variant in $selectedVariants) {
  $config = Get-VariantConfig -Variant $variant
  $variantDir = Join-Path $runRoot $config.key
  New-Item -ItemType Directory -Force -Path $variantDir | Out-Null
  $stdoutPath = Join-Path $variantDir "pi-workflow.out.txt"
  $exitPath = Join-Path $variantDir "pi-workflow.exitcode.txt"
  $startedAt = Get-Date
  $row = [ordered]@{
    variant = $config.key
    note = $config.note
    modelAlias = $config.modelAlias
    modelPath = $config.modelPath
    contextSize = $config.contextSize
    startedAt = $startedAt.ToString("o")
    completedAt = $null
    durationSeconds = $null
    exitCode = $null
    passed = $false
    workflowOutputPath = $stdoutPath
    workflowExitPath = $exitPath
    workflowSummaryPath = $null
    workflowRunRoot = $null
    taskStatus = @()
    rawProbeStatus = @()
    error = $null
  }

  try {
    if (-not (Test-Path -LiteralPath $config.modelPath)) {
      throw "Model path missing: $($config.modelPath)"
    }
    $workflowArgs = @(
      "-Distro", $Distro,
      "-Port", $Port,
      "-ContextSize", $config.contextSize,
      "-ModelAlias", $config.modelAlias,
      "-ModelPath", $config.modelPath,
      "-Tasks", ($selectedTasks -join ",")
    )
    $exitCode = Invoke-Capture -OutputPath $stdoutPath -Command {
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $workflowScript @workflowArgs
    }
    Set-Content -LiteralPath $exitPath -Encoding ASCII -Value $exitCode
    $row.exitCode = $exitCode
    $summaryCandidate = Find-SummaryPath -OutputPath $stdoutPath
    $row.workflowSummaryPath = $summaryCandidate
    if ($summaryCandidate) {
      $workflow = Get-Content -Raw -LiteralPath $summaryCandidate | ConvertFrom-Json
      $row.workflowRunRoot = [string]$workflow.runRoot
      $row.taskStatus = @($workflow.taskResults | ForEach-Object {
        [pscustomobject]@{ task = [string]$_.task; passed = [bool]$_.passed; piExitCode = $_.piExitCode; sessionLog = [string]$_.sessionLog; sessionLogExists = if ($_.sessionLog) { Test-Path -LiteralPath $_.sessionLog } else { $false } }
      })
      $row.rawProbeStatus = @($workflow.rawProbes | ForEach-Object {
        [pscustomobject]@{ stream = [bool]$_.stream; exitCode = $_.exitCode; output = [string]$_.output }
      })
      $row.passed = ($exitCode -eq 0 -and [bool]$workflow.passed)
    } else {
      throw "Workflow summary missing for variant $variant"
    }
  } catch {
    $row.error = $_.Exception.Message
  } finally {
    $completedAt = Get-Date
    $row.completedAt = $completedAt.ToString("o")
    $row.durationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
  }

  [void]$variantRows.Add([pscustomobject]$row)
  $summary.rows = @($variantRows.ToArray())
  $summary.completedAt = (Get-Date).ToString("o")
  $summary.comparisonCompleted = (@($summary.rows).Count -eq @($selectedVariants).Count)
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 14)
}

$summary.rows = @($variantRows.ToArray())
$passingRows = @($summary.rows | Where-Object { $_.passed })
$baseline = @($summary.rows | Where-Object { $_.variant -eq "q4-ctx8192" } | Select-Object -First 1)
$summary.comparisonCompleted = (@($summary.rows).Count -eq @($selectedVariants).Count)
$summary.promotedVariant = if ($baseline -and $baseline.passed) { "q4-ctx8192" } elseif ($passingRows.Count -gt 0) { [string]$passingRows[0].variant } else { $null }
$summary.recommendation = if ($summary.promotedVariant -eq "q4-ctx8192") {
  "Keep WSL ROCm llama.cpp Qwen3 Coder 30B Q4 at 8k context as the promoted endpoint."
} elseif ($summary.promotedVariant) {
  "Use $($summary.promotedVariant) only if its task reliability and operational cost are acceptable; baseline did not pass in this run."
} else {
  "No endpoint variant passed; keep prior Phase 16 baseline until investigated."
}
$summary.completedAt = (Get-Date).ToString("o")
Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 14)
Write-Output $summaryPath
