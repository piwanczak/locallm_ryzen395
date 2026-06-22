param(
  [string]$Distro = "Ubuntu-24.04",
  [string]$BenchmarkRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$ListOnline,
  [switch]$Install,
  [switch]$ConfirmInstall,
  [switch]$WebDownload,
  [switch]$NoLaunch,
  [int]$WslVersion = 2,
  [string]$LinuxUser = "root",
  [switch]$RunLinuxPreflight
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
    [int]$TimeoutSeconds = 120
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

function Get-DistroInstalled {
  param([string]$DistroName, [string]$ListOutput)

  $plain = Normalize-Output $ListOutput
  foreach ($line in ($plain -split "\r?\n")) {
    if ($line -match [regex]::Escape($DistroName)) {
      return $true
    }
  }
  return $false
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultDir = Join-Path $BenchmarkRoot "results\$stamp-wsl-distro-prepare"
New-Item -ItemType Directory -Force -Path $resultDir | Out-Null

if ($Install -and -not $ConfirmInstall) {
  throw "Refusing to install $Distro without -ConfirmInstall. This script is read-only by default."
}

$events = @()
$events += [pscustomobject]@{
  event = "wsl_status"
  result = Invoke-Capture "wsl.exe" @("--status") 120
}

$listVerbose = Invoke-Capture "wsl.exe" @("-l", "-v") 120
$events += [pscustomobject]@{
  event = "wsl_list_verbose"
  result = $listVerbose
}

if ($ListOnline) {
  $events += [pscustomobject]@{
    event = "wsl_list_online"
    result = Invoke-Capture "wsl.exe" @("--list", "--online") 120
  }
}

$installedBefore = Get-DistroInstalled -DistroName $Distro -ListOutput $listVerbose.stdout

if ($Install -and -not $installedBefore) {
  $installArgs = @("--install")
  if ($WebDownload) {
    $installArgs += "--web-download"
  }
  $installArgs += "-d"
  $installArgs += $Distro
  if ($NoLaunch) {
    $installArgs += "--no-launch"
  }
  if ($WslVersion -gt 0) {
    $installArgs += "--version"
    $installArgs += [string]$WslVersion
  }
  $events += [pscustomobject]@{
    event = "wsl_install"
    distro = $Distro
    webDownload = [bool]$WebDownload
    noLaunch = [bool]$NoLaunch
    wslVersion = $WslVersion
    result = Invoke-Capture "wsl.exe" $installArgs 3600
  }
  $listVerbose = Invoke-Capture "wsl.exe" @("-l", "-v") 120
  $events += [pscustomobject]@{
    event = "wsl_list_verbose_after_install"
    result = $listVerbose
  }
}

$installedAfter = Get-DistroInstalled -DistroName $Distro -ListOutput $listVerbose.stdout

if ($RunLinuxPreflight -and $installedAfter) {
  $repoInWsl = "/mnt/c/path/to/locallm_ryzen395"
  $preflightOut = "benchmarks/wsl-local-inference-benchmark/results/$stamp-linux-preflight"
  $command = "cd '$repoInWsl' && bash benchmarks/wsl-local-inference-benchmark/scripts/wsl-preflight.sh '$preflightOut'"
  $events += [pscustomobject]@{
    event = "linux_preflight"
    distro = $Distro
    linuxUser = $LinuxUser
    result = Invoke-Capture "wsl.exe" @("--distribution", $Distro, "--user", $LinuxUser, "--", "bash", "-lc", $command) 300
  }
} elseif ($RunLinuxPreflight) {
  $events += [pscustomobject]@{
    event = "linux_preflight_skipped"
    distro = $Distro
    reason = "Distro is not installed."
  }
}

$summary = [ordered]@{
  created = (Get-Date).ToString("o")
  distro = $Distro
  installRequested = [bool]$Install
  installConfirmed = [bool]$ConfirmInstall
  webDownload = [bool]$WebDownload
  noLaunch = [bool]$NoLaunch
  wslVersion = $WslVersion
  linuxUser = $LinuxUser
  listOnline = [bool]$ListOnline
  runLinuxPreflight = [bool]$RunLinuxPreflight
  installedBefore = $installedBefore
  installedAfter = $installedAfter
  resultDir = $resultDir
  events = $events
}

$jsonPath = Join-Path $resultDir "prepare-wsl-distro.json"
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

[pscustomobject]@{
  resultDir = $resultDir
  jsonPath = $jsonPath
  distro = $Distro
  installedBefore = $installedBefore
  installedAfter = $installedAfter
  installRequested = [bool]$Install
} | ConvertTo-Json -Depth 6
