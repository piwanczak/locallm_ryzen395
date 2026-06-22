param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$Concurrency = 2,
  [int]$MaxTokens = 320,
  [string]$Prompt = "Count from 1 to 200, separated by spaces. Output only the numbers.",
  [int]$TimeoutSec = 240,
  [switch]$UniquePrompt
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Net.Http

$uri = "$($BaseUrl.TrimEnd('/'))/v1/chat/completions"
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)

try {
  $tasks = New-Object System.Collections.Generic.List[object]
  $sw = [Diagnostics.Stopwatch]::StartNew()

  for ($i = 0; $i -lt $Concurrency; $i++) {
    $requestPrompt = $Prompt
    if ($UniquePrompt) {
      $nonce = [guid]::NewGuid().ToString("N")
      $requestPrompt = "$Prompt Ignore this benchmark nonce: $nonce"
    }

    $body = @{
      model = $Model
      messages = @(
        @{
          role = "user"
          content = $requestPrompt
        }
      )
      temperature = 0
      max_tokens = $MaxTokens
      stream = $false
    } | ConvertTo-Json -Depth 8

    $content = [System.Net.Http.StringContent]::new(
      $body,
      [Text.Encoding]::UTF8,
      "application/json"
    )
    $tasks.Add($client.PostAsync($uri, $content)) | Out-Null
  }

  [Threading.Tasks.Task]::WaitAll($tasks.ToArray())
  $sw.Stop()

  $completionTokens = 0
  $totalTokens = 0
  $statusCodes = @()

  foreach ($task in $tasks) {
    $resp = $task.Result
    $statusCodes += [int]$resp.StatusCode
    $text = $resp.Content.ReadAsStringAsync().Result

    if (-not $resp.IsSuccessStatusCode) {
      throw "Request failed with HTTP $([int]$resp.StatusCode): $text"
    }

    $json = $text | ConvertFrom-Json
    $completionTokens += [int]$json.usage.completion_tokens
    $totalTokens += [int]$json.usage.total_tokens
  }

  $wallTps = if ($sw.Elapsed.TotalSeconds -gt 0) {
    $completionTokens / $sw.Elapsed.TotalSeconds
  } else {
    0
  }

  [pscustomobject]@{
    BaseUrl = $BaseUrl.TrimEnd("/")
    Model = $Model
    Concurrency = $Concurrency
    CompletionTokens = $completionTokens
    ElapsedSeconds = [math]::Round($sw.Elapsed.TotalSeconds, 3)
    AggregateWallTokensPerSecond = [math]::Round($wallTps, 2)
    AverageTokensPerRequest = [math]::Round(($completionTokens / $Concurrency), 2)
    TotalTokens = $totalTokens
    StatusCodes = ($statusCodes -join ",")
  }
} finally {
  $client.Dispose()
}
