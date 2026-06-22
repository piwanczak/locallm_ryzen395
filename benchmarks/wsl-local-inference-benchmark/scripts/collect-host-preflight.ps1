param(
  [string]$BenchmarkRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function ConvertTo-ArgumentString {
  param([string[]]$Arguments)

  (($Arguments | ForEach-Object {
    if ($_ -match '[\s"]') {
      '"' + ($_ -replace '\\', '\\' -replace '"', '\"') + '"'
    } else {
      $_
    }
  }) -join " ")
}

function Normalize-Output {
  param([string]$Text)

  if ($null -eq $Text) {
    return ""
  }
  return ($Text -replace [string][char]0, "")
}

function Invoke-Capture {
  param(
    [string]$FileName,
    [string[]]$Arguments,
    [int]$TimeoutSeconds = 30
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FileName
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = ConvertTo-ArgumentString $Arguments

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $exited = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $exited) {
      try { $process.Kill($true) } catch {}
    }
    $stdout = Normalize-Output ($stdoutTask.GetAwaiter().GetResult())
    $stderr = Normalize-Output ($stderrTask.GetAwaiter().GetResult())
    [pscustomobject]@{
      command = "$FileName $($Arguments -join ' ')"
      exitCode = if ($exited) { $process.ExitCode } else { $null }
      timedOut = -not $exited
      elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
      stdout = $stdout
      stderr = $stderr
    }
  } catch {
    [pscustomobject]@{
      command = "$FileName $($Arguments -join ' ')"
      exitCode = $null
      timedOut = $false
      elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
      stdout = ""
      stderr = $_.Exception.Message
    }
  } finally {
    $sw.Stop()
  }
}

function Get-ReportMeta {
  param([string]$Path)

  $exists = Test-Path -LiteralPath $Path
  [pscustomobject]@{
    path = $Path
    exists = $exists
    sha256 = if ($exists) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash } else { $null }
  }
}

$workspaceRoot = (Resolve-Path (Join-Path $BenchmarkRoot "..\..")).Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultDir = Join-Path $BenchmarkRoot "results\$stamp-preflight"
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null

$baselineReports = @(
  "reports\2026-06-19_optimization-summary-11-b9728-hip-rocm-retest.md",
  "reports\2026-06-19_optimization-summary-12-vulkan-223-experts.md",
  "reports\2026-06-20_optimization-summary-28-long-context-final-report.md",
  "reports\2026-06-20_optimization-summary-29-opencode-agent-benchmark-final.md",
  "reports\2026-06-20_optimization-summary-30-opencode-ttft-practical-profile.md",
  "reports\2026-06-20_optimization-summary-31-opencode-thin-prompt-ttft-sweep.md"
) | ForEach-Object {
  Get-ReportMeta (Join-Path $workspaceRoot $_)
}

$gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,DriverDate,AdapterRAM,PNPDeviceID)

$preflight = [ordered]@{
  created = (Get-Date).ToString("o")
  benchmarkRoot = $BenchmarkRoot
  workspaceRoot = $workspaceRoot
  wsl = [ordered]@{
    status = Invoke-Capture "wsl.exe" @("--status")
    distributions = Invoke-Capture "wsl.exe" @("-l", "-v")
  }
  windowsGpu = $gpu
  baselineReports = $baselineReports
  interpretation = "If distributions.exitCode is nonzero with 'no installed distributions', WSL2 execution is blocked until a distro is installed with explicit approval."
}

$jsonPath = Join-Path $resultDir "host-preflight.json"
$preflight | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

[pscustomobject]@{
  resultDir = $resultDir
  jsonPath = $jsonPath
  distroListExitCode = $preflight.wsl.distributions.exitCode
} | ConvertTo-Json -Depth 4
