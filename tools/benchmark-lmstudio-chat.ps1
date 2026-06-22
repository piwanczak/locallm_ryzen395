param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$MaxTokens = 320,
  [string]$Prompt = "Count from 1 to 200, separated by spaces. Output only the numbers.",
  [switch]$UniquePrompt
)

$ErrorActionPreference = "Stop"

if ($UniquePrompt) {
  $nonce = [guid]::NewGuid().ToString("N")
  $Prompt = "$Prompt Ignore this benchmark nonce: $nonce"
}

$body = @{
  model = $Model
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
  -Uri "$($BaseUrl.TrimEnd('/'))/v1/chat/completions" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body `
  -TimeoutSec 180
$sw.Stop()

$completionTokens = $resp.usage.completion_tokens
$wallTps = if ($sw.Elapsed.TotalSeconds -gt 0) {
  $completionTokens / $sw.Elapsed.TotalSeconds
} else {
  0
}

[pscustomobject]@{
  BaseUrl = $BaseUrl.TrimEnd('/')
  Model = $Model
  CompletionTokens = $completionTokens
  ElapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 3)
  WallTokensPerSecond = [math]::Round($wallTps, 2)
  TotalTokens = $resp.usage.total_tokens
}
