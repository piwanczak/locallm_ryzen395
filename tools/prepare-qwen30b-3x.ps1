param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [string]$RuntimeAlias = "llama.cpp-win-x86_64-vulkan-avx2@2.22.0",
  [string]$PerformanceSchemeGuid = "6fecc5ae-f350-48a5-b669-b472cb895ccf",
  [double]$TargetTokensPerSecond = 121.5,
  [int]$ContextLength = 8192,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [int]$Parallel = 4,
  [int]$NumExperts = 4,
  [int]$WarmupTokens = 160,
  [int]$Concurrency = 4,
  [int]$MaxTokens = 320,
  [int]$TimeoutSec = 240,
  [int]$PowerRequestSeconds = 3600,
  [switch]$SkipRuntimeSelect,
  [switch]$SkipReload,
  [switch]$SkipPowerRequest,
  [switch]$Verify
)

$ErrorActionPreference = "Stop"

$amdPowerSliderSubgroup = "c763b4ec-0e50-4b6b-9bed-2b92a6ee884e"
$amdOverlaySetting = "7ec1751b-60ed-4588-afb5-9819d3d77d90"
$amdPmfControllerSetting = "38cab4d5-db09-449f-9db5-1c91c909b6d4"

$lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"
$reloadScript = Join-Path $PSScriptRoot "reload-qwen30b-rest.ps1"
$singleBenchmarkScript = Join-Path $PSScriptRoot "benchmark-lmstudio-chat.ps1"
$concurrentBenchmarkScript = Join-Path $PSScriptRoot "benchmark-lmstudio-chat-concurrent.ps1"
$powerRequestHelper = Join-Path $PSScriptRoot "windows-power-request.exe"

if (-not (Test-Path -LiteralPath $lms)) {
  throw "LM Studio CLI not found: $lms"
}
foreach ($script in @($reloadScript, $singleBenchmarkScript, $concurrentBenchmarkScript)) {
  if (-not (Test-Path -LiteralPath $script)) {
    throw "Required helper script not found: $script"
  }
}

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host "== $Name =="
  & $Action
}

Invoke-Step "Power profile" {
  & powercfg /setactive $PerformanceSchemeGuid | Out-Null
  & powercfg /setacvalueindex SCHEME_CURRENT $amdPowerSliderSubgroup $amdOverlaySetting 3 | Out-Null
  & powercfg /setacvalueindex SCHEME_CURRENT $amdPowerSliderSubgroup $amdPmfControllerSetting 3 | Out-Null
  & powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0 | Out-Null
  & powercfg /setacvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 0 | Out-Null
  & powercfg /setacvalueindex SCHEME_CURRENT SUB_VIDEO 8ec4b3a5-6868-48c2-be75-4f3044be88a7 0 2>$null | Out-Null
  & powercfg /setactive SCHEME_CURRENT | Out-Null
  & powercfg /getactivescheme
  & powercfg /query SCHEME_CURRENT $amdPowerSliderSubgroup
  & powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
  & powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE
}

$script:modernStandbyLikelyActive = $false
$script:lastModernStandbyEnter = $null
$script:lastModernStandbyExit = $null
Invoke-Step "Modern Standby status" {
  try {
    $events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=506,507} -MaxEvents 20 -ErrorAction Stop
    $script:lastModernStandbyEnter = $events | Where-Object { $_.Id -eq 506 } | Select-Object -First 1
    $script:lastModernStandbyExit = $events | Where-Object { $_.Id -eq 507 } | Select-Object -First 1
    $script:modernStandbyLikelyActive = $script:lastModernStandbyEnter -and (
      -not $script:lastModernStandbyExit -or $script:lastModernStandbyEnter.TimeCreated -gt $script:lastModernStandbyExit.TimeCreated
    )
    [pscustomobject]@{
      ModernStandbyLikelyActive = $script:modernStandbyLikelyActive
      LastEnter = if ($script:lastModernStandbyEnter) { $script:lastModernStandbyEnter.TimeCreated } else { $null }
      LastExit = if ($script:lastModernStandbyExit) { $script:lastModernStandbyExit.TimeCreated } else { $null }
      Note = if ($script:modernStandbyLikelyActive) {
        "Wake the console with physical keyboard/touchpad input before benchmarking; the iGPU may stay capped until Windows logs a Modern Standby exit."
      } else {
        "No newer Modern Standby enter than exit was found."
      }
    }
  } catch {
    $script:modernStandbyLikelyActive = $null
    [pscustomobject]@{
      ModernStandbyLikelyActive = $null
      Error = $_.Exception.Message
    }
  }
}

if (-not $SkipPowerRequest) {
  Invoke-Step "Power request helper" {
    if (Test-Path -LiteralPath $powerRequestHelper) {
      $existing = Get-Process -Name "windows-power-request" -ErrorAction SilentlyContinue
      if ($existing) {
        $existing | Select-Object Id,ProcessName,StartTime
      } else {
        $process = Start-Process -FilePath $powerRequestHelper -ArgumentList $PowerRequestSeconds -WindowStyle Hidden -PassThru
        [pscustomobject]@{
          Started = $true
          ProcessId = $process.Id
          Seconds = $PowerRequestSeconds
        }
      }
    } else {
      [pscustomobject]@{
        Started = $false
        Reason = "Helper not found: $powerRequestHelper"
      }
    }
  }
}

if (-not $SkipRuntimeSelect) {
  Invoke-Step "LM Studio runtime" {
    & $lms runtime select $RuntimeAlias
    & $lms runtime ls
  }
}

if (-not $SkipReload) {
  Invoke-Step "Reload model" {
    & $reloadScript `
      -BaseUrl $BaseUrl `
      -Model $Model `
      -ContextLength $ContextLength `
      -EvalBatchSize $EvalBatchSize `
      -PhysicalBatchSize $PhysicalBatchSize `
      -Parallel $Parallel `
      -NumExperts $NumExperts
  }
}

$warmupResult = $null
Invoke-Step "Warmup decode" {
  $script:warmupResult = & $singleBenchmarkScript `
    -BaseUrl $BaseUrl `
    -Model $Model `
    -MaxTokens $WarmupTokens `
    -UniquePrompt
  $script:warmupResult
}

$throughputResult = $null
if ($Verify) {
  Invoke-Step "Throughput verification" {
    $script:throughputResult = & $concurrentBenchmarkScript `
      -BaseUrl $BaseUrl `
      -Model $Model `
      -Concurrency $Concurrency `
      -MaxTokens $MaxTokens `
      -TimeoutSec $TimeoutSec `
      -UniquePrompt
    $script:throughputResult
  }
}

$summary = [ordered]@{
  Model = $Model
  RuntimeAlias = $RuntimeAlias
  TargetTokensPerSecond = $TargetTokensPerSecond
  PowerSchemeGuid = $PerformanceSchemeGuid
  ContextLength = $ContextLength
  EvalBatchSize = $EvalBatchSize
  PhysicalBatchSize = $PhysicalBatchSize
  Parallel = $Parallel
  NumExperts = $NumExperts
  PowerRequestSeconds = if ($SkipPowerRequest) { 0 } else { $PowerRequestSeconds }
  ModernStandbyLikelyActive = $script:modernStandbyLikelyActive
  ModernStandbyLastEnter = if ($script:lastModernStandbyEnter) { $script:lastModernStandbyEnter.TimeCreated } else { $null }
  ModernStandbyLastExit = if ($script:lastModernStandbyExit) { $script:lastModernStandbyExit.TimeCreated } else { $null }
  WarmupTokens = $WarmupTokens
  WarmupTokensPerSecond = if ($warmupResult) { $warmupResult.WallTokensPerSecond } else { $null }
  VerificationTokensPerSecond = if ($throughputResult) { $throughputResult.AggregateWallTokensPerSecond } else { $null }
  VerificationTargetMet = if ($throughputResult) {
    [double]$throughputResult.AggregateWallTokensPerSecond -ge $TargetTokensPerSecond
  } else {
    $null
  }
}

Invoke-Step "Summary" {
  [pscustomobject]$summary | Format-List
}
