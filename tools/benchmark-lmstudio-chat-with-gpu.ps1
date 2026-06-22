param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$MaxTokens = 320,
  [string]$Prompt = "Count from 1 to 200, separated by spaces. Output only the numbers.",
  [int]$SampleSeconds = 23,
  [switch]$UniquePrompt
)

$ErrorActionPreference = "Continue"

$cwdPath = (Get-Location).Path
$benchmarkScript = Join-Path $cwdPath "tools\benchmark-lmstudio-chat.ps1"

$bench = Start-Job -ArgumentList $cwdPath, $benchmarkScript, $BaseUrl, $Model, $MaxTokens, $Prompt, $UniquePrompt.IsPresent -ScriptBlock {
  param($dir, $script, $baseUrl, $model, $maxTokens, $prompt, $uniquePrompt)
  Set-Location $dir
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    $script,
    "-BaseUrl",
    $baseUrl,
    "-Model",
    $model,
    "-MaxTokens",
    $maxTokens,
    "-Prompt",
    $prompt
  )
  if ($uniquePrompt) {
    $args += "-UniquePrompt"
  }
  powershell.exe @args | Out-String
}

Start-Sleep -Seconds 1
$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
$samples = Get-Counter "\GPU Engine(*)\Utilization Percentage" -SampleInterval 1 -MaxSamples $SampleSeconds -ErrorAction SilentlyContinue
$ErrorActionPreference = $oldErrorActionPreference
$benchmarkOutput = Receive-Job -Job $bench -Wait -AutoRemoveJob

$rows = foreach ($sample in $samples.CounterSamples) {
  if ($sample.CookedValue -gt 0.25) {
    $counterPath = $sample.Path
    $procId = if ($counterPath -match "pid_([0-9]+)") { [int]$Matches[1] } else { $null }
    $engine = if ($counterPath -match "engtype_([^\\)]+)") { $Matches[1] } else { "unknown" }
    [pscustomobject]@{
      Pid = $procId
      Engine = $engine
      Value = [double]$sample.CookedValue
    }
  }
}

$summary = $rows | Group-Object Pid, Engine | ForEach-Object {
  $values = $_.Group.Value
  $procId = $_.Group[0].Pid
  $name = try {
    (Get-Process -Id $procId -ErrorAction Stop).ProcessName
  } catch {
    "<exited>"
  }
  [pscustomobject]@{
    Pid = $procId
    Process = $name
    Engine = $_.Group[0].Engine
    Samples = $values.Count
    AvgPct = [math]::Round(($values | Measure-Object -Average).Average, 2)
    MaxPct = [math]::Round(($values | Measure-Object -Maximum).Maximum, 2)
  }
} | Sort-Object MaxPct -Descending

"BENCHMARK:"
$benchmarkOutput
"GPU SUMMARY:"
$summary | Format-Table -AutoSize
