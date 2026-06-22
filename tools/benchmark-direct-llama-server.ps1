param(
  [string]$ServerExe = "$env:USERPROFILE\.lmstudio\extensions\backends\llama.cpp-win-x86_64-vulkan-avx2-2.22.0\llama-server.exe",
  [string]$ModelPath = "$env:USERPROFILE\.lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf",
  [string]$DraftModelPath = "",
  [int]$Port = 1235,
  [int]$ContextLength = 8192,
  [int]$Parallel = 1,
  [int]$NumExperts = 4,
  [string]$SpecType = "",
  [int]$SpecDraftMax = 4,
  [int]$SpecDraftMin = 0,
  [double]$SpecDraftPMin = 0.0,
  [int]$MaxTokens = 320,
  [string]$Prompt = "Count from 1 to 200, separated by spaces. Output only the numbers.",
  [int]$StartupTimeoutSec = 180,
  [string]$LogPrefix = "direct-llama-server"
)

$ErrorActionPreference = "Stop"

$baseUrl = "http://127.0.0.1:$Port"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stdoutPath = Join-Path (Resolve-Path ".\logs") "$LogPrefix-$stamp.out.log"
$stderrPath = Join-Path (Resolve-Path ".\logs") "$LogPrefix-$stamp.err.log"

$argsList = @(
  "--host", "127.0.0.1",
  "--port", "$Port",
  "--model", $ModelPath,
  "--ctx-size", "$ContextLength",
  "--batch-size", "2048",
  "--ubatch-size", "512",
  "--parallel", "$Parallel",
  "--gpu-layers", "all",
  "--flash-attn", "on",
  "--cache-type-k", "q4_0",
  "--cache-type-v", "q4_0",
  "--prio", "2",
  "--poll", "100",
  "--override-kv", "qwen3moe.expert_used_count=int:$NumExperts",
  "--log-file", $stderrPath,
  "--no-ui",
  "--no-webui"
)

if ($SpecType -ne "") {
  $argsList += @("--spec-type", $SpecType)
}

if ($DraftModelPath -ne "") {
  $argsList += @(
    "--model-draft", $DraftModelPath,
    "--spec-draft-n-max", "$SpecDraftMax",
    "--spec-draft-n-min", "$SpecDraftMin",
    "--spec-draft-p-min", "$SpecDraftPMin",
    "--cache-type-k-draft", "q4_0",
    "--cache-type-v-draft", "q4_0",
    "--gpu-layers-draft", "all"
  )
}

Set-Content -LiteralPath $stdoutPath -Value "" -Encoding UTF8

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $ServerExe
$startInfo.WorkingDirectory = Split-Path -Parent $ServerExe
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $false
$startInfo.RedirectStandardError = $false

function Quote-ProcessArgument {
  param([string]$Value)

  if ($Value -notmatch '[\s"]') {
    return $Value
  }

  return '"' + ($Value -replace '"', '\"') + '"'
}

$startInfo.Arguments = ($argsList | ForEach-Object { Quote-ProcessArgument $_ }) -join " "

$proc = [System.Diagnostics.Process]::new()
$proc.StartInfo = $startInfo

[void]$proc.Start()

try {
  $ready = $false
  $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSec)

  while ([DateTime]::UtcNow -lt $deadline) {
    if ($proc.HasExited) {
      throw "llama-server exited early with code $($proc.ExitCode). See $stderrPath"
    }

    try {
      $health = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get -TimeoutSec 2
      if ($health.status -eq "ok" -or $health.status -eq "loading model") {
        if ($health.status -eq "ok") {
          $ready = $true
          break
        }
      }
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }

  if (-not $ready) {
    throw "llama-server did not become ready within $StartupTimeoutSec seconds. See $stderrPath"
  }

  $body = @{
    model = "qwen/qwen3-coder-30b"
    messages = @(
      @{
        role = "user"
        content = $Prompt
      }
    )
    temperature = 0
    max_tokens = $MaxTokens
    stream = $false
  } | ConvertTo-Json -Depth 8

  $sw = [Diagnostics.Stopwatch]::StartNew()
  $resp = Invoke-RestMethod `
    -Uri "$baseUrl/v1/chat/completions" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body `
    -TimeoutSec 240
  $sw.Stop()

  $completionTokens = [int]$resp.usage.completion_tokens
  $wallTps = if ($sw.Elapsed.TotalSeconds -gt 0) {
    $completionTokens / $sw.Elapsed.TotalSeconds
  } else {
    0
  }

  [pscustomobject]@{
    BaseUrl = $baseUrl
    ServerExe = $ServerExe
    ContextLength = $ContextLength
    Parallel = $Parallel
    NumExperts = $NumExperts
    SpecType = $SpecType
    DraftModelPath = $DraftModelPath
    CompletionTokens = $completionTokens
    ElapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 3)
    WallTokensPerSecond = [math]::Round($wallTps, 2)
    TotalTokens = [int]$resp.usage.total_tokens
    StdoutLog = $stdoutPath
    StderrLog = $stderrPath
  }
} finally {
  if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force
    $proc.WaitForExit()
  }
}
