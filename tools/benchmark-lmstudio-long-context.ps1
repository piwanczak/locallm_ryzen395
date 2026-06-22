param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$ContextLength = 32768,
  [int]$Runs = 1,
  [int]$ReserveTokens = 1536,
  [int]$MaxTokens = 240,
  [int]$SamplerIntervalSeconds = 1,
  [string]$TokenizerPath = "",
  [string]$ModelPath = "",
  [string]$OutputDir = "",
  [switch]$Stream,
  [switch]$KeepPromptFiles
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http

$workspace = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($TokenizerPath)) {
  $TokenizerPath = Join-Path $workspace "downloads\llama-vulkan\b9728-vulkan\llama-tokenize.exe"
}
if ([string]::IsNullOrWhiteSpace($ModelPath)) {
  $ModelPath = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
  $OutputDir = Join-Path $workspace "logs\long-context"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$promptDir = Join-Path $OutputDir "prompts"
$sampleDir = Join-Path $OutputDir "samples"
New-Item -ItemType Directory -Force -Path $promptDir | Out-Null
New-Item -ItemType Directory -Force -Path $sampleDir | Out-Null

if (-not (Test-Path -LiteralPath $TokenizerPath)) {
  throw "Tokenizer not found: $TokenizerPath"
}
if (-not (Test-Path -LiteralPath $ModelPath)) {
  throw "Model file not found: $ModelPath"
}

function New-RunId {
  param([int]$ContextLength, [int]$RunIndex)

  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $rand = [guid]::NewGuid().ToString("N").Substring(0, 8)
  "ctx$ContextLength-run$RunIndex-$stamp-$rand"
}

function New-NeedlePromptText {
  param(
    [int]$LineCount,
    [string]$RunId
  )

  $beginCode = "BEGIN-$RunId"
  $middleCode = "MIDDLE-$RunId"
  $endCode = "END-$RunId"
  $firstHalf = [math]::Floor($LineCount / 2)
  $secondHalf = $LineCount - $firstHalf
  $sb = [System.Text.StringBuilder]::new()

  [void]$sb.AppendLine("Long-context retrieval benchmark corpus.")
  [void]$sb.AppendLine("Most lines are distractors. The answer is contained only in the explicit NEEDLE_CODE lines.")
  [void]$sb.AppendLine("NEEDLE_BEGIN_CODE: $beginCode")

  for ($i = 1; $i -le $firstHalf; $i++) {
    $route = [int]($i % 997)
    $checksum = [int](($i * 7919 + 17) % 100000)
    [void]$sb.AppendLine(("FILLER RECORD {0:D6}: module amber route {1:D5}; checksum {2:D5}; no requested code is present here." -f [int]$i, $route, $checksum))
  }

  [void]$sb.AppendLine("NEEDLE_MIDDLE_CODE: $middleCode")

  for ($i = 1; $i -le $secondHalf; $i++) {
    $n = $firstHalf + $i
    $route = [int]($n % 991)
    $checksum = [int](($n * 3571 + 29) % 100000)
    [void]$sb.AppendLine(("FILLER RECORD {0:D6}: module cobalt route {1:D5}; checksum {2:D5}; no requested code is present here." -f [int]$n, $route, $checksum))
  }

  [void]$sb.AppendLine("NEEDLE_END_CODE: $endCode")
  [void]$sb.AppendLine("End of corpus.")
  [void]$sb.AppendLine("Return the three codes exactly as compact JSON with keys begin, middle, and end. After the JSON, write the word tick exactly 120 times separated by single spaces.")

  [pscustomobject]@{
    Prompt = $sb.ToString()
    BeginCode = $beginCode
    MiddleCode = $middleCode
    EndCode = $endCode
  }
}

function Get-TokenCount {
  param([string]$Text)

  $tmp = [System.IO.Path]::GetTempFileName()
  try {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($tmp, $Text, $utf8NoBom)
    $output = & $TokenizerPath -m $ModelPath -f $tmp --show-count --log-disable 2>&1
    $match = $output | Select-String -Pattern "Total number of tokens:\s+([0-9]+)" | Select-Object -Last 1
    if (-not $match) {
      throw "Could not parse tokenizer output: $($output -join "`n")"
    }
    [int]$match.Matches[0].Groups[1].Value
  } finally {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
}

function New-CalibratedPrompt {
  param(
    [int]$ContextLength,
    [int]$ReserveTokens,
    [string]$RunId
  )

  $target = [math]::Max(1024, $ContextLength - $ReserveTokens)
  $low = 0
  $high = 512
  $best = $null

  while ($true) {
    $candidate = New-NeedlePromptText -LineCount $high -RunId $RunId
    $tokens = Get-TokenCount -Text $candidate.Prompt
    if ($tokens -gt $target) {
      break
    }
    $best = [pscustomobject]@{
      PromptData = $candidate
      Tokens = $tokens
      Lines = $high
    }
    $low = $high + 1
    $high = $high * 2
  }

  while ($low -le $high) {
    $mid = [int][math]::Floor(($low + $high) / 2)
    $candidate = New-NeedlePromptText -LineCount $mid -RunId $RunId
    $tokens = Get-TokenCount -Text $candidate.Prompt
    if ($tokens -le $target) {
      $best = [pscustomobject]@{
        PromptData = $candidate
        Tokens = $tokens
        Lines = $mid
      }
      $low = $mid + 1
    } else {
      $high = $mid - 1
    }
  }

  if (-not $best) {
    throw "Could not build a prompt under target token count $target"
  }

  [pscustomobject]@{
    Prompt = $best.PromptData.Prompt
    BeginCode = $best.PromptData.BeginCode
    MiddleCode = $best.PromptData.MiddleCode
    EndCode = $best.PromptData.EndCode
    TokenizerPromptTokens = $best.Tokens
    FillerLines = $best.Lines
    TargetPromptTokens = $target
  }
}

function Get-ServerLogPath {
  $logRoot = Join-Path $env:USERPROFILE ".lmstudio\server-logs"
  Get-ChildItem -LiteralPath $logRoot -Recurse -Filter "*.log" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName
}

function Get-LineCount {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return 0
  }
  (Get-Content -LiteralPath $Path | Measure-Object -Line).Lines
}

function Get-LlamaTimings {
  param(
    [string]$Path,
    [int]$StartLine
  )

  $promptEvalMs = $null
  $promptEvalTokens = $null
  $promptEvalTps = $null
  $evalMs = $null
  $evalTokens = $null
  $evalTps = $null
  $totalMs = $null
  $totalTokens = $null

  if (Test-Path -LiteralPath $Path) {
    $lines = Get-Content -LiteralPath $Path | Select-Object -Skip $StartLine
    foreach ($line in $lines) {
      if ($line -match "prompt eval time =\s+([0-9.]+) ms\s+/\s+([0-9]+) tokens.*?([0-9.]+) tokens per second") {
        $promptEvalMs = [double]$Matches[1]
        $promptEvalTokens = [int]$Matches[2]
        $promptEvalTps = [double]$Matches[3]
      }
      if ($line -match "\beval time =\s+([0-9.]+) ms\s+/\s+([0-9]+) tokens.*?([0-9.]+) tokens per second") {
        $evalMs = [double]$Matches[1]
        $evalTokens = [int]$Matches[2]
        $evalTps = [double]$Matches[3]
      }
      if ($line -match "total time =\s+([0-9.]+) ms\s+/\s+([0-9]+) tokens") {
        $totalMs = [double]$Matches[1]
        $totalTokens = [int]$Matches[2]
      }
    }
  }

  [pscustomobject]@{
    PromptEvalMs = $promptEvalMs
    PromptEvalTokens = $promptEvalTokens
    PromptEvalTokensPerSecond = $promptEvalTps
    EvalMs = $evalMs
    EvalTokens = $evalTokens
    EvalTokensPerSecond = $evalTps
    TotalMs = $totalMs
    TotalTokens = $totalTokens
  }
}

function Start-MemorySampler {
  param(
    [string]$StopFile,
    [int]$IntervalSeconds
  )

  Start-Job -ArgumentList $StopFile, $IntervalSeconds -ScriptBlock {
    param($stopFile, $intervalSeconds)

    function Get-BytesFromCounters {
      param(
        [string[]]$Paths,
        [int[]]$PidFilter
      )

      $result = @{
        Dedicated = 0.0
        Shared = 0.0
        TotalCommitted = 0.0
      }

      try {
        $samples = (Get-Counter $Paths -ErrorAction Stop).CounterSamples
      } catch {
        return $result
      }

      foreach ($sample in $samples) {
        if ($PidFilter -and $PidFilter.Count -gt 0) {
          if ($sample.Path -notmatch "pid_([0-9]+)") {
            continue
          }
          if ($PidFilter -notcontains [int]$Matches[1]) {
            continue
          }
        }

        if ($sample.Path -match "dedicated usage") {
          $result.Dedicated += [double]$sample.CookedValue
        } elseif ($sample.Path -match "shared usage") {
          $result.Shared += [double]$sample.CookedValue
        } elseif ($sample.Path -match "total committed") {
          $result.TotalCommitted += [double]$sample.CookedValue
        }
      }

      $result
    }

    while (-not (Test-Path -LiteralPath $stopFile)) {
      $os = Get-CimInstance Win32_OperatingSystem
      $procs = Get-Process -Name "LM Studio" -ErrorAction SilentlyContinue
      $pids = @($procs | Select-Object -ExpandProperty Id)
      $workingSet = ($procs | Measure-Object WorkingSet64 -Sum).Sum
      $privateMem = ($procs | Measure-Object PrivateMemorySize64 -Sum).Sum

      $adapter = Get-BytesFromCounters `
        -Paths @("\GPU Adapter Memory(*)\Dedicated Usage", "\GPU Adapter Memory(*)\Shared Usage", "\GPU Adapter Memory(*)\Total Committed") `
        -PidFilter @()
      $procGpu = Get-BytesFromCounters `
        -Paths @("\GPU Process Memory(*)\Dedicated Usage", "\GPU Process Memory(*)\Shared Usage", "\GPU Process Memory(*)\Total Committed") `
        -PidFilter $pids

      [pscustomobject]@{
        Timestamp = (Get-Date).ToString("o")
        FreePhysicalBytes = [int64]$os.FreePhysicalMemory * 1024
        FreeVirtualBytes = [int64]$os.FreeVirtualMemory * 1024
        LmStudioProcessCount = @($procs).Count
        LmStudioWorkingSetBytes = [int64]$workingSet
        LmStudioPrivateBytes = [int64]$privateMem
        GpuAdapterDedicatedBytes = [int64]$adapter.Dedicated
        GpuAdapterSharedBytes = [int64]$adapter.Shared
        GpuAdapterTotalCommittedBytes = [int64]$adapter.TotalCommitted
        GpuLmStudioDedicatedBytes = [int64]$procGpu.Dedicated
        GpuLmStudioSharedBytes = [int64]$procGpu.Shared
        GpuLmStudioTotalCommittedBytes = [int64]$procGpu.TotalCommitted
      }

      Start-Sleep -Seconds $intervalSeconds
    }
  }
}

function Invoke-StreamingChat {
  param(
    [string]$BaseUrl,
    [string]$Model,
    [string]$Prompt,
    [int]$MaxTokens
  )

  $uri = "$($BaseUrl.TrimEnd('/'))/v1/chat/completions"
  $client = [System.Net.Http.HttpClient]::new()
  $client.Timeout = [TimeSpan]::FromMinutes(90)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $firstTokenMs = $null
  $completion = [System.Text.StringBuilder]::new()
  $usage = $null

  try {
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
      stream = $true
      stream_options = @{
        include_usage = $true
      }
    } | ConvertTo-Json -Depth 12 -Compress

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $uri)
    $request.Content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
    $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    $response.EnsureSuccessStatusCode() | Out-Null
    $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $reader = [System.IO.StreamReader]::new($stream)

    while (($line = $reader.ReadLine()) -ne $null) {
      if (-not $line.StartsWith("data:")) {
        continue
      }

      $payload = $line.Substring(5).Trim()
      if ($payload -eq "[DONE]") {
        break
      }
      if ([string]::IsNullOrWhiteSpace($payload)) {
        continue
      }

      $obj = $payload | ConvertFrom-Json
      if ($obj.usage) {
        $usage = $obj.usage
      }
      if ($obj.choices -and $obj.choices.Count -gt 0) {
        $choice = $obj.choices[0]
        if ($choice.delta -and ($choice.delta.PSObject.Properties.Name -contains "content")) {
          $piece = [string]$choice.delta.content
          if ($piece.Length -gt 0) {
            if ($null -eq $firstTokenMs) {
              $firstTokenMs = $sw.Elapsed.TotalMilliseconds
            }
            [void]$completion.Append($piece)
          }
        }
      }
    }

    $sw.Stop()
    [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      TimeToFirstTokenMs = $firstTokenMs
      TotalElapsedMs = $sw.Elapsed.TotalMilliseconds
      Completion = $completion.ToString()
      Usage = $usage
    }
  } finally {
    $client.Dispose()
  }
}

function Invoke-BlockingChat {
  param(
    [string]$BaseUrl,
    [string]$Model,
    [string]$Prompt,
    [int]$MaxTokens
  )

  $uri = "$($BaseUrl.TrimEnd('/'))/v1/chat/completions"
  $client = [System.Net.Http.HttpClient]::new()
  $client.Timeout = [TimeSpan]::FromMinutes(120)
  $sw = [Diagnostics.Stopwatch]::StartNew()

  try {
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
    } | ConvertTo-Json -Depth 12 -Compress

    $content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
    $response = $client.PostAsync($uri, $content).GetAwaiter().GetResult()
    $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $sw.Stop()

    if (-not $response.IsSuccessStatusCode) {
      throw "HTTP $([int]$response.StatusCode): $text"
    }

    $obj = $text | ConvertFrom-Json
    $completion = ""
    if ($obj.choices -and $obj.choices.Count -gt 0 -and $obj.choices[0].message) {
      $completion = [string]$obj.choices[0].message.content
    }

    [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      TimeToFirstTokenMs = $null
      TotalElapsedMs = $sw.Elapsed.TotalMilliseconds
      Completion = $completion
      Usage = $obj.usage
    }
  } finally {
    $client.Dispose()
  }
}

function Get-SampleStats {
  param([object[]]$Samples)

  if (-not $Samples -or $Samples.Count -eq 0) {
    return [pscustomobject]@{}
  }

  [pscustomobject]@{
    Samples = $Samples.Count
    MinFreePhysicalBytes = ($Samples | Measure-Object FreePhysicalBytes -Minimum).Minimum
    MaxLmStudioWorkingSetBytes = ($Samples | Measure-Object LmStudioWorkingSetBytes -Maximum).Maximum
    MaxLmStudioPrivateBytes = ($Samples | Measure-Object LmStudioPrivateBytes -Maximum).Maximum
    MaxGpuAdapterSharedBytes = ($Samples | Measure-Object GpuAdapterSharedBytes -Maximum).Maximum
    MaxGpuAdapterDedicatedBytes = ($Samples | Measure-Object GpuAdapterDedicatedBytes -Maximum).Maximum
    MaxGpuAdapterTotalCommittedBytes = ($Samples | Measure-Object GpuAdapterTotalCommittedBytes -Maximum).Maximum
    MaxGpuLmStudioSharedBytes = ($Samples | Measure-Object GpuLmStudioSharedBytes -Maximum).Maximum
    MaxGpuLmStudioDedicatedBytes = ($Samples | Measure-Object GpuLmStudioDedicatedBytes -Maximum).Maximum
    MaxGpuLmStudioTotalCommittedBytes = ($Samples | Measure-Object GpuLmStudioTotalCommittedBytes -Maximum).Maximum
  }
}

$jsonl = Join-Path $OutputDir ("long-context-results-{0}.jsonl" -f (Get-Date -Format "yyyyMMdd"))
$results = @()

for ($run = 1; $run -le $Runs; $run++) {
  $runId = New-RunId -ContextLength $ContextLength -RunIndex $run
  Write-Host "Preparing prompt for $runId"
  $promptInfo = New-CalibratedPrompt -ContextLength $ContextLength -ReserveTokens $ReserveTokens -RunId $runId

  $promptPath = Join-Path $promptDir "$runId.txt"
  if ($KeepPromptFiles) {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($promptPath, $promptInfo.Prompt, $utf8NoBom)
  } else {
    $promptPath = ""
  }

  $serverLog = Get-ServerLogPath
  $startLine = Get-LineCount -Path $serverLog
  $stopFile = Join-Path $env:TEMP "$runId.stop"
  Remove-Item -LiteralPath $stopFile -Force -ErrorAction SilentlyContinue
  $sampler = Start-MemorySampler -StopFile $stopFile -IntervalSeconds $SamplerIntervalSeconds

  $requestStart = Get-Date
  $streamResult = $null
  $requestError = $null
  try {
    $modeName = if ($Stream) { "streaming" } else { "blocking" }
    Write-Host "Running $modeName benchmark for $runId with tokenizer prompt tokens $($promptInfo.TokenizerPromptTokens)"
    if ($Stream) {
      $streamResult = Invoke-StreamingChat -BaseUrl $BaseUrl -Model $Model -Prompt $promptInfo.Prompt -MaxTokens $MaxTokens
    } else {
      $streamResult = Invoke-BlockingChat -BaseUrl $BaseUrl -Model $Model -Prompt $promptInfo.Prompt -MaxTokens $MaxTokens
    }
  } catch {
    $requestError = $_.Exception.Message
  } finally {
    New-Item -ItemType File -Force -Path $stopFile | Out-Null
  }

  $samples = @(Receive-Job -Job $sampler -Wait -AutoRemoveJob)
  Remove-Item -LiteralPath $stopFile -Force -ErrorAction SilentlyContinue
  $samplePath = Join-Path $sampleDir "$runId.csv"
  $samples | Export-Csv -LiteralPath $samplePath -NoTypeInformation

  $timings = Get-LlamaTimings -Path $serverLog -StartLine $startLine
  $sampleStats = Get-SampleStats -Samples $samples
  $completion = if ($streamResult) { [string]$streamResult.Completion } else { "" }
  $usagePromptTokens = if ($streamResult -and $streamResult.Usage) { $streamResult.Usage.prompt_tokens } else { $null }
  $usageCompletionTokens = if ($streamResult -and $streamResult.Usage) { $streamResult.Usage.completion_tokens } else { $null }
  $decodeTpsFromUsage = $null

  if ($streamResult -and $usageCompletionTokens -and $streamResult.TimeToFirstTokenMs -ne $null) {
    $decodeSeconds = ($streamResult.TotalElapsedMs - $streamResult.TimeToFirstTokenMs) / 1000.0
    if ($decodeSeconds -gt 0) {
      $decodeTpsFromUsage = [math]::Round(([double]$usageCompletionTokens / $decodeSeconds), 3)
    }
  }

  $passBegin = $completion.Contains($promptInfo.BeginCode)
  $passMiddle = $completion.Contains($promptInfo.MiddleCode)
  $passEnd = $completion.Contains($promptInfo.EndCode)
  $passed = $passBegin -and $passMiddle -and $passEnd -and [string]::IsNullOrWhiteSpace($requestError)

  $record = [pscustomobject]@{
    Timestamp = (Get-Date).ToString("o")
    RequestStart = $requestStart.ToString("o")
    RunId = $runId
    ContextLength = $ContextLength
    Model = $Model
    TargetPromptTokens = $promptInfo.TargetPromptTokens
    TokenizerPromptTokens = $promptInfo.TokenizerPromptTokens
    FillerLines = $promptInfo.FillerLines
    MaxTokens = $MaxTokens
    TransportMode = if ($Stream) { "stream" } else { "blocking" }
    RequestError = $requestError
    HttpStatusCode = if ($streamResult) { $streamResult.StatusCode } else { $null }
    TimeToFirstTokenMs = if ($streamResult -and $streamResult.TimeToFirstTokenMs -ne $null) { [math]::Round($streamResult.TimeToFirstTokenMs, 1) } else { $null }
    EstimatedTimeToFirstTokenMs = if ($timings.PromptEvalMs) { [math]::Round($timings.PromptEvalMs, 1) } else { $null }
    TotalElapsedMs = if ($streamResult) { [math]::Round($streamResult.TotalElapsedMs, 1) } else { $null }
    UsagePromptTokens = $usagePromptTokens
    UsageCompletionTokens = $usageCompletionTokens
    DecodeTokensPerSecondFromUsage = $decodeTpsFromUsage
    LlamaPromptEvalMs = $timings.PromptEvalMs
    LlamaPromptEvalTokens = $timings.PromptEvalTokens
    LlamaPromptEvalTokensPerSecond = $timings.PromptEvalTokensPerSecond
    LlamaEvalMs = $timings.EvalMs
    LlamaEvalTokens = $timings.EvalTokens
    LlamaEvalTokensPerSecond = $timings.EvalTokensPerSecond
    LlamaTotalMs = $timings.TotalMs
    LlamaTotalTokens = $timings.TotalTokens
    NeedleBeginPass = $passBegin
    NeedleMiddlePass = $passMiddle
    NeedleEndPass = $passEnd
    RetrievalPassed = $passed
    BeginCode = $promptInfo.BeginCode
    MiddleCode = $promptInfo.MiddleCode
    EndCode = $promptInfo.EndCode
    SampleCount = $sampleStats.Samples
    MinFreePhysicalBytes = $sampleStats.MinFreePhysicalBytes
    MaxLmStudioWorkingSetBytes = $sampleStats.MaxLmStudioWorkingSetBytes
    MaxLmStudioPrivateBytes = $sampleStats.MaxLmStudioPrivateBytes
    MaxGpuAdapterSharedBytes = $sampleStats.MaxGpuAdapterSharedBytes
    MaxGpuAdapterDedicatedBytes = $sampleStats.MaxGpuAdapterDedicatedBytes
    MaxGpuAdapterTotalCommittedBytes = $sampleStats.MaxGpuAdapterTotalCommittedBytes
    MaxGpuLmStudioSharedBytes = $sampleStats.MaxGpuLmStudioSharedBytes
    MaxGpuLmStudioDedicatedBytes = $sampleStats.MaxGpuLmStudioDedicatedBytes
    MaxGpuLmStudioTotalCommittedBytes = $sampleStats.MaxGpuLmStudioTotalCommittedBytes
    ServerLog = $serverLog
    SamplePath = $samplePath
    PromptPath = $promptPath
    CompletionPreview = if ($completion.Length -gt 600) { $completion.Substring(0, 600) } else { $completion }
  }

  $record | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath $jsonl
  $results += $record
}

$results
