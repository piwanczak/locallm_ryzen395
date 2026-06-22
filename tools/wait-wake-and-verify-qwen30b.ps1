param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [double]$TargetTokensPerSecond = 121.5,
  [int]$PollSeconds = 10,
  [int]$TimeoutMinutes = 180,
  [int]$PostWakeSettleSeconds = 20,
  [int]$PowerRequestSeconds = 14400,
  [int]$AdlSamples = 12,
  [int]$AdlSampleIntervalSeconds = 2
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $root "logs"
$prepareScript = Join-Path $PSScriptRoot "prepare-qwen30b-3x.ps1"
$adlBenchmarkScript = Join-Path $PSScriptRoot "benchmark-lmstudio-concurrent-with-adl-pmlog.ps1"
$powerRequestHelper = Join-Path $PSScriptRoot "windows-power-request.exe"

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$transcriptPath = Join-Path $logsDir "${stamp}_wait-wake-and-verify-qwen30b.log"

function Write-Status {
  param([string]$Message)
  Write-Host ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}

function Get-ModernStandbyStatus {
  $events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=506,507} -MaxEvents 30 -ErrorAction Stop
  $lastEnter = $events | Where-Object { $_.Id -eq 506 } | Select-Object -First 1
  $lastExit = $events | Where-Object { $_.Id -eq 507 } | Select-Object -First 1
  $active = $lastEnter -and (-not $lastExit -or $lastEnter.TimeCreated -gt $lastExit.TimeCreated)

  [pscustomobject]@{
    ModernStandbyLikelyActive = [bool]$active
    LastEnter = if ($lastEnter) { $lastEnter.TimeCreated } else { $null }
    LastExit = if ($lastExit) { $lastExit.TimeCreated } else { $null }
    LastEnterReason = if ($lastEnter) { ($lastEnter.Message -replace "`r?`n", " ") } else { $null }
    LastExitReason = if ($lastExit) { ($lastExit.Message -replace "`r?`n", " ") } else { $null }
  }
}

function Start-PowerRequestHelper {
  if (-not (Test-Path -LiteralPath $powerRequestHelper)) {
    Write-Status "Power request helper not found: $powerRequestHelper"
    return
  }

  $existing = Get-Process -Name "windows-power-request" -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Status ("Existing power request helper process(es): {0}" -f (($existing | Select-Object -ExpandProperty Id) -join ","))
  }

  $process = Start-Process -FilePath $powerRequestHelper -ArgumentList $PowerRequestSeconds -WindowStyle Hidden -PassThru
  Write-Status "Started power request helper PID $($process.Id) for $PowerRequestSeconds seconds."
}

Start-Transcript -Path $transcriptPath -Force | Out-Null
try {
  Write-Status "Waiting for a real Modern Standby exit before verifying Qwen3 Coder 30B."
  Write-Status "Transcript: $transcriptPath"

  Start-PowerRequestHelper

  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  do {
    $status = Get-ModernStandbyStatus
    $status | Format-List

    if (-not $status.ModernStandbyLikelyActive) {
      Write-Status "Modern Standby appears inactive. Continuing to verification."
      break
    }

    if ((Get-Date) -ge $deadline) {
      throw "Timed out after $TimeoutMinutes minutes waiting for Modern Standby exit. Wake/unlock the console and rerun this script."
    }

    Write-Status "Still waiting for Windows event 507 newer than event 506. Polling again in $PollSeconds seconds."
    Start-Sleep -Seconds $PollSeconds
  } while ($true)

  if ($PostWakeSettleSeconds -gt 0) {
    Write-Status "Settling for $PostWakeSettleSeconds seconds after wake."
    Start-Sleep -Seconds $PostWakeSettleSeconds
  }

  Write-Status "Running prepared Qwen3 Coder verification."
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $prepareScript `
    -BaseUrl $BaseUrl `
    -Model $Model `
    -TargetTokensPerSecond $TargetTokensPerSecond `
    -PowerRequestSeconds $PowerRequestSeconds `
    -Verify

  Write-Status "Running ADL-clocked concurrent benchmark for proof of GPU state."
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $adlBenchmarkScript `
    -BaseUrl $BaseUrl `
    -Model $Model `
    -Concurrency 4 `
    -MaxTokens 320 `
    -UniquePrompt `
    -Samples $AdlSamples `
    -SampleIntervalSeconds $AdlSampleIntervalSeconds `
    -TimeoutSec 240

  Write-Status "Wake-and-verify run complete."
} finally {
  Stop-Transcript | Out-Null
}
