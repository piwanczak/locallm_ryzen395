param(
  [string]$Distro = "Ubuntu-24.04",
  [string[]]$MemoryCaps = @("DEFAULT", "48GB", "32GB"),
  [int]$Port = 8091,
  [int]$ContextSize = 8192,
  [string]$ModelAlias = "qwen/qwen3-coder-30b-q4",
  [string]$ModelPath = "",
  [string[]]$Tasks = @("file-create", "js-edit", "browser-style"),
  [switch]$Apply,
  [switch]$ConfirmWslShutdown,
  [switch]$ConfirmWslConfigWrite
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not $Apply) {
  Write-Output "Dry run only. Re-run with -Apply -ConfirmWslShutdown -ConfirmWslConfigWrite to edit .wslconfig and restart WSL."
}

if ($Apply -and (-not $ConfirmWslShutdown -or -not $ConfirmWslConfigWrite)) {
  throw "Refusing to run. The Pi memory sweep requires -Apply -ConfirmWslShutdown -ConfirmWslConfigWrite."
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$workflowScript = Join-Path $scriptRoot "run-pi-jinja-q4-toolcall-workflow.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-pi-memory-cap-sweep"
$summaryPath = Join-Path $runRoot "pi-memory-cap-sweep-summary.json"
$wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
$backupPath = Join-Path $runRoot "wslconfig-before.txt"
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

function Restore-OriginalWslConfig {
  if ($hadExistingConfig) {
    Write-Utf8NoBom -Path $wslConfigPath -Value $existingConfig
  } else {
    Remove-Item -LiteralPath $wslConfigPath -ErrorAction SilentlyContinue
  }
}

function Set-WslMemoryCap {
  param([Parameter(Mandatory = $true)][string]$MemoryCap)
  $normalized = $MemoryCap.Trim().ToUpperInvariant()
  if ($normalized -eq "DEFAULT" -or $normalized -eq "CURRENT") {
    Restore-OriginalWslConfig
    return "original"
  }

  $config = @"
[wsl2]
memory=$MemoryCap
swap=16GB
"@
  Set-Content -LiteralPath $wslConfigPath -Value $config -Encoding ASCII
  return "memory=$MemoryCap; swap=16GB"
}

function Stop-WslVm {
  $output = & wsl.exe --shutdown 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    throw "wsl.exe --shutdown failed with exit code $exitCode`: $($output -join "`n")"
  }
  Start-Sleep -Seconds 5
}

function Get-MemoryProbe {
  param([Parameter(Mandatory = $true)][string]$OutputPath)
  return Invoke-Capture -OutputPath $OutputPath -Command {
    & wsl.exe --distribution $Distro --user root -- bash -lc "printf 'free -h\n'; free -h; printf '\nfree -b\n'; free -b; printf '\nmeminfo\n'; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo"
  }
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

function Sanitize-Name {
  param([Parameter(Mandatory = $true)][string]$Value)
  return ($Value -replace '[^A-Za-z0-9_.-]', '_')
}

function Normalize-MemoryCap {
  param([Parameter(Mandatory = $true)][string]$Value)
  $trimmed = $Value.Trim()
  if ($trimmed -eq "") { return $null }
  $upper = $trimmed.ToUpperInvariant()
  if ($upper -eq "DEFAULT" -or $upper -eq "CURRENT") { return "DEFAULT" }
  if ($upper -match '^\d+$') {
    $bytes = [double]$upper
    $gib = $bytes / 1GB
    $rounded = [math]::Round($gib)
    if ([math]::Abs($gib - $rounded) -lt 0.001) {
      return "$rounded`GB"
    }
  }
  if ($upper -match '^\d+\s*(GB|MB)$') {
    return ($upper -replace '\s+', '')
  }
  return $trimmed
}

$hadExistingConfig = Test-Path -LiteralPath $wslConfigPath
$existingConfig = if ($hadExistingConfig) { [string](Get-Content -Raw -LiteralPath $wslConfigPath) } else { "" }
Write-Utf8NoBom -Path $backupPath -Value $existingConfig

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$selectedMemoryCaps = @($MemoryCaps | ForEach-Object { $_ -split "," } | ForEach-Object { Normalize-MemoryCap $_ } | Where-Object { $_ })
$rows = New-Object System.Collections.ArrayList
$summaryBase = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  apply = [bool]$Apply
  distro = $Distro
  port = $Port
  contextSize = $ContextSize
  modelAlias = $ModelAlias
  modelPath = $ModelPath
  tasks = $selectedTasks
  memoryCaps = $selectedMemoryCaps
  wslConfigPath = $wslConfigPath
  hadExistingWslConfig = $hadExistingConfig
  backupPath = $backupPath
  runRoot = $runRoot
  rows = @()
  restoredOriginalConfig = $false
  finalWslShutdown = $false
  passed = $false
}

if (-not (Test-Path -LiteralPath $workflowScript)) {
  throw "Missing workflow script: $workflowScript"
}
if (-not (Test-Path -LiteralPath $ModelPath)) {
  throw "Missing model file: $ModelPath"
}

try {
  foreach ($memoryCap in $selectedMemoryCaps) {
    $safeName = Sanitize-Name $memoryCap
    $capDir = Join-Path $runRoot $safeName
    New-Item -ItemType Directory -Force -Path $capDir | Out-Null
    $row = [ordered]@{
      memoryCap = $memoryCap
      status = "planned"
      appliedConfig = $null
      memoryProbe = $null
      memoryProbeExitCode = $null
      workflowOutputPath = $null
      workflowExitPath = $null
      workflowExitCode = $null
      workflowSummaryPath = $null
      workflowRunRoot = $null
      taskStatus = @()
      error = $null
    }

    try {
      if ($Apply) {
        $row.appliedConfig = Set-WslMemoryCap -MemoryCap $memoryCap
        Stop-WslVm

        $probePath = Join-Path $capDir "wsl-memory-probe.txt"
        $probeExit = Get-MemoryProbe -OutputPath $probePath
        $row.memoryProbe = $probePath
        $row.memoryProbeExitCode = $probeExit
        if ($probeExit -ne 0) {
          throw "WSL memory probe failed with exit code $probeExit"
        }

        $workflowOut = Join-Path $capDir "pi-workflow.out.txt"
        $workflowExit = Join-Path $capDir "pi-workflow.exitcode.txt"
        $workflowArgs = @(
          "-Distro", $Distro,
          "-Port", $Port,
          "-ContextSize", $ContextSize,
          "-ModelAlias", $ModelAlias,
          "-ModelPath", $ModelPath,
          "-Tasks", ($selectedTasks -join ",")
        )
        $workflowCode = Invoke-Capture -OutputPath $workflowOut -Command {
          & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $workflowScript @workflowArgs
        }
        Set-Content -LiteralPath $workflowExit -Encoding ASCII -Value $workflowCode
        $row.workflowOutputPath = $workflowOut
        $row.workflowExitPath = $workflowExit
        $row.workflowExitCode = $workflowCode
        $workflowSummaryPath = Find-SummaryPath -OutputPath $workflowOut
        $row.workflowSummaryPath = $workflowSummaryPath

        if ($workflowSummaryPath) {
          $workflowSummary = Get-Content -Raw -LiteralPath $workflowSummaryPath | ConvertFrom-Json
          $row.workflowRunRoot = [string]$workflowSummary.runRoot
          $row.taskStatus = @($workflowSummary.taskResults | ForEach-Object {
            [pscustomobject]@{
              task = [string]$_.task
              passed = [bool]$_.passed
              piExitCode = $_.piExitCode
              sessionLog = [string]$_.sessionLog
              sessionLogExists = if ($_.sessionLog) { Test-Path -LiteralPath $_.sessionLog } else { $false }
            }
          })
          if ($workflowCode -ne 0 -or -not [bool]$workflowSummary.passed) {
            throw "Pi workflow failed under cap $memoryCap with exit code $workflowCode"
          }
        } else {
          throw "Pi workflow did not produce a summary under cap $memoryCap"
        }
        $row.status = "completed"
      }
    } catch {
      $row.status = "failed"
      $row.error = $_.Exception.Message
    }

    [void]$rows.Add([pscustomobject]$row)
    $summaryBase.rows = @($rows.ToArray())
    $summaryBase.completedAt = (Get-Date).ToString("o")
    $summaryBase.passed = (
      $Apply -and
      @($summaryBase.rows).Count -eq @($selectedMemoryCaps).Count -and
      @($summaryBase.rows | Where-Object { $_.status -ne "completed" }).Count -eq 0
    )
    Write-Utf8NoBom -Path $summaryPath -Value ($summaryBase | ConvertTo-Json -Depth 14)
  }
} finally {
  if ($Apply) {
    Restore-OriginalWslConfig
    $summaryBase.restoredOriginalConfig = $true
    Stop-WslVm
    $summaryBase.finalWslShutdown = $true
  }
  $summaryBase.rows = @($rows.ToArray())
  $summaryBase.completedAt = (Get-Date).ToString("o")
  $summaryBase.passed = (
    $Apply -and
    @($summaryBase.rows).Count -eq @($selectedMemoryCaps).Count -and
    @($summaryBase.rows | Where-Object { $_.status -ne "completed" }).Count -eq 0 -and
    $summaryBase.restoredOriginalConfig -and
    $summaryBase.finalWslShutdown
  )
  Write-Utf8NoBom -Path $summaryPath -Value ($summaryBase | ConvertTo-Json -Depth 14)
}

Write-Output $summaryPath
if ($Apply -and -not $summaryBase.passed) {
  exit 1
}
