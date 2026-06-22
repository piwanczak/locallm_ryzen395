param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$WarmupTokens = 160,
  [int]$Concurrency = 4,
  [int]$MaxTokens = 320,
  [string]$Prompt = "Count from 1 to 200, separated by spaces. Output only the numbers.",
  [int]$TimeoutSec = 240,
  [switch]$UniquePrompt
)

$ErrorActionPreference = "Stop"

$singleScript = Join-Path $PSScriptRoot "benchmark-lmstudio-chat.ps1"
$concurrentScript = Join-Path $PSScriptRoot "benchmark-lmstudio-chat-concurrent.ps1"

if (-not (Test-Path -LiteralPath $singleScript)) {
  throw "Single benchmark script not found: $singleScript"
}
if (-not (Test-Path -LiteralPath $concurrentScript)) {
  throw "Concurrent benchmark script not found: $concurrentScript"
}

$commonArgs = @{
  BaseUrl = $BaseUrl
  Model = $Model
  Prompt = $Prompt
}
if ($UniquePrompt) {
  $commonArgs.UniquePrompt = $true
}

"WARMUP:"
& $singleScript @commonArgs -MaxTokens $WarmupTokens

"THROUGHPUT:"
& $concurrentScript @commonArgs -Concurrency $Concurrency -MaxTokens $MaxTokens -TimeoutSec $TimeoutSec
