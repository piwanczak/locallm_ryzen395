param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int[]]$Contexts = @(32768, 65536, 131072, 196608, 229376, 262144),
  [int]$RunsPerContext = 2,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [int]$Parallel = 1,
  [int]$MaxTokens = 240,
  [int]$ReserveTokens = 1536,
  [int]$LoadTimeoutSec = 600,
  [switch]$StopOnFailure,
  [switch]$NoRestoreThroughput
)

$ErrorActionPreference = "Stop"

$workspace = Split-Path -Parent $PSScriptRoot
$reloadLong = Join-Path $PSScriptRoot "reload-qwen30b-long-context.ps1"
$benchmark = Join-Path $PSScriptRoot "benchmark-lmstudio-long-context.ps1"
$restoreThroughput = Join-Path $PSScriptRoot "reload-qwen30b-throughput.ps1"
$outputDir = Join-Path $workspace "logs\long-context"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$ladderJsonl = Join-Path $outputDir ("long-context-ladder-{0}.jsonl" -f (Get-Date -Format "yyyyMMdd"))

function Get-ProcessSnapshot {
  $os = Get-CimInstance Win32_OperatingSystem
  $procs = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue
  [pscustomobject]@{
    Timestamp = (Get-Date).ToString("o")
    FreePhysicalBytes = [int64]$os.FreePhysicalMemory * 1024
    FreeVirtualBytes = [int64]$os.FreeVirtualMemory * 1024
    LmStudioProcessCount = @($procs).Count
    LmStudioWorkingSetBytes = [int64](($procs | Measure-Object WorkingSet64 -Sum).Sum)
    LmStudioPrivateBytes = [int64](($procs | Measure-Object PrivateMemorySize64 -Sum).Sum)
  }
}

function Get-StabilityEvents {
  param([datetime]$Since)

  try {
    Get-WinEvent -FilterHashtable @{ LogName = "System"; StartTime = $Since; Level = 1, 2, 3 } -ErrorAction Stop |
      Where-Object {
        $_.ProviderName -match "Display|amdkmdag|amdwddmg|amduw|Kernel-Power|WHEA|Resource-Exhaustion|LiveKernel" -or
        $_.Message -match "display driver|stopped responding|reset|resource exhaustion|out of memory|LiveKernel"
      } |
      Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, @{ Name = "Message"; Expression = {
        $msg = ($_.Message -replace "\s+", " ").Trim()
        if ($msg.Length -gt 500) { $msg.Substring(0, 500) } else { $msg }
      }}
  } catch {
    @([pscustomobject]@{
      TimeCreated = Get-Date
      Id = $null
      ProviderName = "Get-WinEvent"
      LevelDisplayName = "Error"
      Message = $_.Exception.Message
    })
  }
}

function Add-LadderRecord {
  param([pscustomobject]$Record)

  $Record | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath $ladderJsonl
  $Record
}

$allRecords = @()

try {
  foreach ($ctx in $Contexts) {
    Write-Host "=== Loading long-context profile ctx=$ctx parallel=$Parallel ==="
    $phaseStart = Get-Date
    $before = Get-ProcessSnapshot
    $loadSw = [Diagnostics.Stopwatch]::StartNew()
    $loadOutput = $null
    $loadError = $null

    try {
      $loadOutput = & $reloadLong `
        -BaseUrl $BaseUrl `
        -Model $Model `
        -ContextLength $ctx `
        -EvalBatchSize $EvalBatchSize `
        -PhysicalBatchSize $PhysicalBatchSize `
        -Parallel $Parallel `
        -NumExperts 4 `
        -FlashAttention $true `
        -OffloadKvCacheToGpu $true `
        -TimeoutSec $LoadTimeoutSec 2>&1
    } catch {
      $loadError = $_.Exception.Message
    }

    $loadSw.Stop()
    Start-Sleep -Seconds 2
    $after = Get-ProcessSnapshot
    $psOutput = try {
      & "$env:USERPROFILE\.lmstudio\bin\lms.exe" ps | Out-String
    } catch {
      $_.Exception.Message
    }

    $loadRecord = [pscustomobject]@{
      Timestamp = (Get-Date).ToString("o")
      Phase = "load"
      ContextLength = $ctx
      Parallel = $Parallel
      EvalBatchSize = $EvalBatchSize
      PhysicalBatchSize = $PhysicalBatchSize
      LoadSucceeded = [string]::IsNullOrWhiteSpace($loadError)
      LoadElapsedSeconds = [math]::Round($loadSw.Elapsed.TotalSeconds, 3)
      LoadError = $loadError
      Before = $before
      After = $after
      LmsPs = $psOutput
      LoadOutputPreview = if ($loadOutput) { (($loadOutput | Out-String).Trim()) } else { "" }
    }
    $allRecords += Add-LadderRecord -Record $loadRecord

    if ($loadError) {
      Write-Host "Load failed at ctx=${ctx}: $loadError"
      if ($StopOnFailure) {
        break
      }
      continue
    }

    Write-Host "=== Benchmarking ctx=$ctx runs=$RunsPerContext ==="
    $benchError = $null
    $benchRecords = $null
    try {
      $benchRecords = & $benchmark `
        -BaseUrl $BaseUrl `
        -Model $Model `
        -ContextLength $ctx `
        -Runs $RunsPerContext `
        -ReserveTokens $ReserveTokens `
        -MaxTokens $MaxTokens `
        -OutputDir $outputDir `
        -KeepPromptFiles
    } catch {
      $benchError = $_.Exception.Message
    }

    $benchPassed = $false
    if ($benchRecords) {
      $benchPassed = @($benchRecords | Where-Object { $_.RetrievalPassed -eq $true }).Count -eq $RunsPerContext
    }

    $benchRecord = [pscustomobject]@{
      Timestamp = (Get-Date).ToString("o")
      Phase = "benchmark"
      ContextLength = $ctx
      RunsRequested = $RunsPerContext
      BenchmarkSucceeded = [string]::IsNullOrWhiteSpace($benchError)
      RetrievalPassedAllRuns = $benchPassed
      BenchmarkError = $benchError
      RunIds = if ($benchRecords) { @($benchRecords | Select-Object -ExpandProperty RunId) } else { @() }
      ResultSummary = if ($benchRecords) {
        @($benchRecords | Select-Object RunId, TokenizerPromptTokens, TimeToFirstTokenMs, LlamaPromptEvalMs, LlamaPromptEvalTokensPerSecond, LlamaEvalTokensPerSecond, RetrievalPassed)
      } else {
        @()
      }
      StabilityEventsSinceContextStart = @(Get-StabilityEvents -Since $phaseStart)
    }
    $allRecords += Add-LadderRecord -Record $benchRecord

    if (($benchError -or -not $benchPassed) -and $StopOnFailure) {
      Write-Host "Benchmark did not pass at ctx=$ctx."
      break
    }
  }
} finally {
  if (-not $NoRestoreThroughput) {
    Write-Host "Restoring 8k throughput profile."
    try {
      & $restoreThroughput -BaseUrl $BaseUrl -Model $Model | Out-String
    } catch {
      Write-Warning "Failed to restore throughput profile: $($_.Exception.Message)"
    }
  }
}

$allRecords
