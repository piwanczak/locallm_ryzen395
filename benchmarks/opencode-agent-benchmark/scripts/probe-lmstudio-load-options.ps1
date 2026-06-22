param(
  [string]$Profile = "qwen-8k",
  [string]$KvCacheType = "q4_0",
  [string]$DraftModel = "",
  [int]$TimeoutSeconds = 1200
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ResultsDir = Join-Path $Root "results\$Stamp-load-option-probe"
$LogsDir = Join-Path $Root "logs\$Stamp-load-option-probe"
$InitialState = Join-Path $ResultsDir "initial-lms-state.json"
$SummaryJson = Join-Path $ResultsDir "load-option-probe.json"

New-Item -ItemType Directory -Force -Path $ResultsDir,$LogsDir | Out-Null

function Invoke-ProcessCapture {
  param(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [string]$StdoutPath,
    [string]$StderrPath,
    [int]$TimeoutSeconds
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FileName
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = ConvertTo-ArgumentString $Arguments

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  $sw = [Diagnostics.Stopwatch]::StartNew()
  [void]$process.Start()
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $exited = $process.WaitForExit($TimeoutSeconds * 1000)
  if (-not $exited) {
    try { $process.Kill($true) } catch {}
  }
  $sw.Stop()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  Set-Content -LiteralPath $StdoutPath -Value $stdout -Encoding UTF8
  Set-Content -LiteralPath $StderrPath -Value $stderr -Encoding UTF8

  [pscustomobject]@{
    exitCode = if ($exited) { $process.ExitCode } else { $null }
    timedOut = -not $exited
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    stdout = $StdoutPath
    stderr = $StderrPath
    stdoutPreview = if ($stdout.Length -gt 2000) { $stdout.Substring(0, 2000) } else { $stdout }
    stderrPreview = if ($stderr.Length -gt 2000) { $stderr.Substring(0, 2000) } else { $stderr }
  }
}

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

function Get-LmStudioState {
  try {
    $raw = & lms ps --json
    if ([string]::IsNullOrWhiteSpace($raw)) {
      return @()
    }
    return @($raw | ConvertFrom-Json)
  } catch {
    return @([pscustomobject]@{ error = $_.Exception.Message })
  }
}

& lms ps --json | Set-Content -LiteralPath $InitialState -Encoding UTF8

$candidates = @(
  [pscustomobject]@{ name = "kv-snake"; args = @("-KvCacheType", $KvCacheType, "-AdvancedKeyStyle", "snake") },
  [pscustomobject]@{ name = "kv-camel"; args = @("-KvCacheType", $KvCacheType, "-AdvancedKeyStyle", "camel") },
  [pscustomobject]@{ name = "mtp-snake"; args = @("-SpeculativeDraftMtp", "-AdvancedKeyStyle", "snake") },
  [pscustomobject]@{ name = "mtp-camel"; args = @("-SpeculativeDraftMtp", "-AdvancedKeyStyle", "camel") }
)

if (-not [string]::IsNullOrWhiteSpace($DraftModel)) {
  $candidates += [pscustomobject]@{ name = "draft-snake"; args = @("-DraftModel", $DraftModel, "-AdvancedKeyStyle", "snake") }
  $candidates += [pscustomobject]@{ name = "draft-camel"; args = @("-DraftModel", $DraftModel, "-AdvancedKeyStyle", "camel") }
}

$results = @()
try {
  foreach ($candidate in $candidates) {
    $stdoutPath = Join-Path $LogsDir "$($candidate.name).out.log"
    $stderrPath = Join-Path $LogsDir "$($candidate.name).err.log"
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      (Join-Path $PSScriptRoot "load-lmstudio-profile.ps1"),
      "-Profile",
      $Profile,
      "-Parallel",
      "1",
      "-EvalBatchSize",
      "2048",
      "-PhysicalBatchSize",
      "512"
    ) + $candidate.args

    $run = Invoke-ProcessCapture `
      -FileName "powershell.exe" `
      -Arguments $args `
      -WorkingDirectory $Root `
      -StdoutPath $stdoutPath `
      -StderrPath $stderrPath `
      -TimeoutSeconds $TimeoutSeconds

    $results += [pscustomobject]@{
      name = $candidate.name
      profile = $Profile
      args = $candidate.args
      run = $run
      loadedState = Get-LmStudioState
    }
  }
} finally {
  $restoreOut = Join-Path $LogsDir "restore-initial.out.log"
  $restoreErr = Join-Path $LogsDir "restore-initial.err.log"
  $restore = Invoke-ProcessCapture `
    -FileName "powershell.exe" `
    -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $PSScriptRoot "load-lmstudio-profile.ps1"),"-Profile","restore-initial","-InitialStateJson",$InitialState) `
    -WorkingDirectory $Root `
    -StdoutPath $restoreOut `
    -StderrPath $restoreErr `
    -TimeoutSeconds $TimeoutSeconds
}

$summary = [pscustomobject]@{
  stamp = $Stamp
  profile = $Profile
  initialState = $InitialState
  resultsDir = $ResultsDir
  logsDir = $LogsDir
  candidates = $results
  restore = $restore
  finalState = Get-LmStudioState
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $SummaryJson -Encoding UTF8
$summary | ConvertTo-Json -Depth 20
