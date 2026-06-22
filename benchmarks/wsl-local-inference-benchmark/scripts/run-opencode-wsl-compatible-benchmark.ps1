param(
  [string]$BaseUrl = "http://127.0.0.1:8080",
  [string]$Model = "qwen/qwen3-coder-30b",
  [string]$ProviderName = "wslbench",
  [string[]]$Tasks = @("js-window"),
  [int]$ContextLimit = 32768,
  [int]$OutputLimit = 4096,
  [int]$PromptTokenTarget = 0,
  [ValidateSet("full", "thin")]
  [string]$PromptSourceMode = "thin",
  [ValidateSet("distractor", "neutral", "none")]
  [string]$PromptPaddingMode = "none",
  [int]$AttachmentChunkChars = 32000,
  [int]$TimeoutMinutes = 20,
  [int]$ProxyPort = 5680,
  [string]$OpenCodePath = "%USERPROFILE%\AppData\Local\pi-node\current\node_modules\opencode-ai\bin\opencode.exe",
  [string]$NodePath = "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-LocalBaseUrl {
  param([string]$Url)

  $uri = [Uri]$Url
  if ($uri.Scheme -notin @("http", "https")) {
    throw "BaseUrl must be http or https: $Url"
  }
  if ($uri.Host -notin @("127.0.0.1", "localhost", "::1")) {
    throw "BaseUrl must target localhost for this sandboxed benchmark: $Url"
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

function Resolve-Node {
  param([string]$Preferred)

  if (Test-Path -LiteralPath $Preferred) {
    return (Resolve-Path -LiteralPath $Preferred).Path
  }
  $found = Get-Command node -ErrorAction SilentlyContinue
  if ($null -ne $found) {
    return $found.Source
  }
  throw "Node was not found. Pass -NodePath explicitly."
}

function Add-JsonLine {
  param([string]$Path, [object]$Value)

  ($Value | ConvertTo-Json -Depth 30 -Compress) | Add-Content -LiteralPath $Path
}

function Get-FileSha256 {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return $null
  }
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-TextMeta {
  param([string]$Text)

  $bytes = [System.Text.Encoding]::UTF8.GetByteCount($Text)
  [pscustomobject]@{
    chars = $Text.Length
    bytes = $bytes
    tokenEstimate = [math]::Round($bytes / 3.7)
  }
}

function Stop-ProcessTree {
  param([int]$ProcessId)

  if ($ProcessId -le 0) {
    return
  }

  $toStop = New-Object System.Collections.Generic.List[int]
  $queue = New-Object System.Collections.Generic.Queue[int]
  $seen = @{}
  $queue.Enqueue($ProcessId)
  $seen[$ProcessId] = $true

  while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    $toStop.Add($current)
    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $current" -ErrorAction SilentlyContinue
    foreach ($child in $children) {
      $childId = [int]$child.ProcessId
      if (-not $seen.ContainsKey($childId)) {
        $seen[$childId] = $true
        $queue.Enqueue($childId)
      }
    }
  }

  [array]::Reverse($toStop)
  foreach ($id in $toStop) {
    try {
      Stop-Process -Id $id -Force -ErrorAction Stop
    } catch {
      # Process may have already exited between enumeration and stop.
    }
  }
}

function Invoke-ProcessCapture {
  param(
    [string]$FileName,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [string]$StdoutPath,
    [string]$StderrPath,
    [int]$TimeoutSeconds
  )

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $StdoutPath),(Split-Path -Parent $StderrPath) | Out-Null
  Set-Content -LiteralPath $StdoutPath -Value "" -Encoding UTF8
  Set-Content -LiteralPath $StderrPath -Value "" -Encoding UTF8

  $sw = [Diagnostics.Stopwatch]::StartNew()
  $process = Start-Process `
    -FilePath $FileName `
    -ArgumentList (ConvertTo-ArgumentString $Arguments) `
    -WorkingDirectory $WorkingDirectory `
    -RedirectStandardOutput $StdoutPath `
    -RedirectStandardError $StderrPath `
    -WindowStyle Hidden `
    -PassThru

  $exited = $process.WaitForExit($TimeoutSeconds * 1000)
  $timedOut = -not $exited
  if (-not $exited) {
    Stop-ProcessTree -ProcessId $process.Id
    $exited = $process.WaitForExit(15000)
  }
  $sw.Stop()

  [pscustomobject]@{
    exitCode = if ($exited -and -not $timedOut) { $process.ExitCode } else { $null }
    timedOut = $timedOut
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
  }
}

function Start-NodeHelper {
  param(
    [string[]]$Arguments,
    [string]$StdoutPath,
    [string]$StderrPath,
    [string]$WorkingDirectory
  )

  Start-Process `
    -FilePath $Node `
    -ArgumentList (ConvertTo-ArgumentString $Arguments) `
    -WorkingDirectory $WorkingDirectory `
    -RedirectStandardOutput $StdoutPath `
    -RedirectStandardError $StderrPath `
    -WindowStyle Hidden `
    -PassThru
}

function Stop-Helper {
  param($Process)

  if ($null -ne $Process -and -not $Process.HasExited) {
    try { Stop-Process -Id $Process.Id -Force } catch {}
  }
}

function Get-OptionalProperty {
  param(
    $Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }
  return $property.Value
}

function Read-OpenCodeRunSummary {
  param([string]$StdoutPath)

  $steps = @()
  $toolCalls = @()
  if (-not (Test-Path -LiteralPath $StdoutPath)) {
    return [pscustomobject]@{ steps = $steps; toolCalls = $toolCalls }
  }

  $stepIndex = 0
  foreach ($line in (Get-Content -LiteralPath $StdoutPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }
    try {
      $event = $line | ConvertFrom-Json
    } catch {
      continue
    }

    $eventType = Get-OptionalProperty $event "type"
    $part = Get-OptionalProperty $event "part"
    $tokens = Get-OptionalProperty $part "tokens"
    if ($eventType -eq "step_finish" -and $null -ne $tokens) {
      $cache = Get-OptionalProperty $tokens "cache"
      $stepIndex += 1
      $steps += [pscustomobject]@{
        index = $stepIndex
        reason = Get-OptionalProperty $part "reason"
        inputTokens = [int](Get-OptionalProperty $tokens "input")
        outputTokens = [int](Get-OptionalProperty $tokens "output")
        totalTokens = [int](Get-OptionalProperty $tokens "total")
        cacheRead = [int](Get-OptionalProperty $cache "read")
        cacheWrite = [int](Get-OptionalProperty $cache "write")
      }
    }

    if ($eventType -eq "tool_use") {
      $state = Get-OptionalProperty $part "state"
      $input = Get-OptionalProperty $state "input"
      $metadata = Get-OptionalProperty $state "metadata"
      $toolCalls += [pscustomobject]@{
        tool = Get-OptionalProperty $part "tool"
        status = Get-OptionalProperty $state "status"
        title = Get-OptionalProperty $part "title"
        exit = Get-OptionalProperty $metadata "exit"
        command = Get-OptionalProperty $input "command"
        workdir = Get-OptionalProperty $input "workdir"
        filePath = Get-OptionalProperty $input "filePath"
      }
    }
  }

  [pscustomobject]@{
    steps = $steps
    toolCalls = $toolCalls
  }
}

function Write-OpenCodeConfig {
  param(
    [string]$Path,
    [string]$Provider,
    [string]$ModelName,
    [string]$ProxyBaseUrl,
    [int]$Context,
    [int]$Output
  )

  $models = [ordered]@{}
  $models[$ModelName] = [ordered]@{
    name = "$ModelName via WSL OpenAI-compatible host"
    limit = [ordered]@{
      context = $Context
      output = $Output
    }
  }

  $providers = [ordered]@{}
  $providers[$Provider] = [ordered]@{
    npm = "@ai-sdk/openai-compatible"
    name = "WSL OpenAI-compatible timing proxy"
    options = [ordered]@{
      baseURL = "$ProxyBaseUrl/v1"
      apiKey = "local"
    }
    models = $models
  }

  $config = [ordered]@{
    '$schema' = "https://opencode.ai/config.json"
    provider = $providers
    model = "$Provider/$ModelName"
    small_model = "$Provider/$ModelName"
    permission = [ordered]@{
      "*" = "allow"
      external_directory = "deny"
      websearch = "deny"
      question = "deny"
      bash = [ordered]@{
        "*&&*" = "deny"
        "*" = "allow"
        "rm *" = "deny"
        "rm -rf *" = "deny"
        "del *" = "deny"
        "erase *" = "deny"
        "Remove-Item *" = "deny"
        "git commit *" = "deny"
        "git push *" = "deny"
        "npm install *" = "deny"
        "pnpm install *" = "deny"
        "yarn add *" = "deny"
      }
    }
    share = "disabled"
    autoupdate = $false
  }

  $config | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

Assert-LocalBaseUrl $BaseUrl
$Node = Resolve-Node $NodePath
if (-not (Test-Path -LiteralPath $OpenCodePath)) {
  throw "OpenCode was not found at $OpenCodePath"
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RepoRoot = (Resolve-Path (Join-Path $Root "..\..")).Path
$OpenCodeBenchmarkRoot = Join-Path $RepoRoot "benchmarks\opencode-agent-benchmark"
$OpenCodeScripts = Join-Path $OpenCodeBenchmarkRoot "scripts"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ResultsDir = Join-Path $Root "results\$Stamp-opencode"
$LogsDir = Join-Path $Root "logs\$Stamp-opencode"
$PromptDir = Join-Path $Root "prompts\$Stamp-opencode"
$XdgConfig = Join-Path $Root ".xdg-config"
$XdgData = Join-Path $Root ".xdg-data"
$XdgCache = Join-Path $Root ".xdg-cache"
$XdgState = Join-Path $Root ".xdg-state"
$TmpDir = Join-Path $Root ".tmp"
$ConfigDir = Join-Path $Root ".opencode-empty"
$ConfigFile = Join-Path $ResultsDir "opencode-wsl-benchmark.config.json"
$SummaryJsonl = Join-Path $ResultsDir "runs.jsonl"
$ProxyEvents = Join-Path $ResultsDir "proxy-events.jsonl"
$CanaryPath = Join-Path $OpenCodeBenchmarkRoot "fixtures\canary\outside-fixture-canary.txt"
$SelectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

New-Item -ItemType Directory -Force -Path $ResultsDir,$LogsDir,$PromptDir,$XdgConfig,$XdgData,$XdgCache,$XdgState,$TmpDir,$ConfigDir | Out-Null

$env:OPENCODE_CONFIG = $ConfigFile
$env:OPENCODE_CONFIG_DIR = $ConfigDir
$env:XDG_CONFIG_HOME = $XdgConfig
$env:XDG_DATA_HOME = $XdgData
$env:XDG_CACHE_HOME = $XdgCache
$env:XDG_STATE_HOME = $XdgState
$env:TEMP = $TmpDir
$env:TMP = $TmpDir
$env:NO_COLOR = "1"
$env:OPENCODE_DISABLE_AUTOUPDATE = "1"
$env:OPENCODE_DISABLE_TELEMETRY = "1"

$proxyBaseUrl = "http://127.0.0.1:$ProxyPort"
Write-OpenCodeConfig `
  -Path $ConfigFile `
  -Provider $ProviderName `
  -ModelName $Model `
  -ProxyBaseUrl $proxyBaseUrl `
  -Context $ContextLimit `
  -Output $OutputLimit

$initialCanarySha256 = Get-FileSha256 $CanaryPath
Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
  event = "benchmark_start"
  runner = "wsl-openai-compatible"
  baseUrl = $BaseUrl
  proxyBaseUrl = $proxyBaseUrl
  providerName = $ProviderName
  model = $Model
  opencodeModel = "$ProviderName/$Model"
  tasks = $SelectedTasks
  contextLimit = $ContextLimit
  outputLimit = $OutputLimit
  promptTokenTarget = if ($PromptTokenTarget -gt 0) { $PromptTokenTarget } else { $null }
  promptSourceMode = $PromptSourceMode
  promptPaddingMode = $PromptPaddingMode
  attachmentChunkChars = $AttachmentChunkChars
  canary = [pscustomobject]@{
    path = $CanaryPath
    sha256 = $initialCanarySha256
  }
})

if ($DryRun) {
  Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
    event = "dry_run_complete"
    message = "Generated isolated OpenCode config and benchmark metadata without contacting the model endpoint."
  })

  [pscustomobject]@{
    stamp = $Stamp
    dryRun = $true
    resultsDir = $ResultsDir
    logsDir = $LogsDir
    promptsDir = $PromptDir
    summaryJsonl = $SummaryJsonl
    proxyEvents = $ProxyEvents
    configFile = $ConfigFile
  } | ConvertTo-Json -Depth 6
  return
}

$proxy = $null
try {
  $proxy = Start-NodeHelper `
    -Arguments @((Join-Path $OpenCodeScripts "lmstudio-timing-proxy.mjs"), "$ProxyPort", $BaseUrl, $ProxyEvents) `
    -StdoutPath (Join-Path $LogsDir "proxy.out.log") `
    -StderrPath (Join-Path $LogsDir "proxy.err.log") `
    -WorkingDirectory $Root
  Start-Sleep -Seconds 2

  $resetRaw = powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $OpenCodeScripts "reset-fixtures.ps1") -RunId "wsl-$Stamp"
  $reset = $resetRaw | ConvertFrom-Json
  $workRoot = $reset.WorkRoot

  foreach ($task in $SelectedTasks) {
    $fixture = Join-Path $workRoot $task
    $port = 8765
    $webBase = ""
    $staticServer = $null
    if ($task -eq "web-retrieval") {
      $webBase = "http://127.0.0.1:$port"
      $staticServer = Start-NodeHelper `
        -Arguments @((Join-Path $OpenCodeScripts "static-server.mjs"), (Join-Path $fixture "site"), "$port") `
        -StdoutPath (Join-Path $LogsDir "$task-static.out.log") `
        -StderrPath (Join-Path $LogsDir "$task-static.err.log") `
        -WorkingDirectory $Root
      Start-Sleep -Seconds 1
    }

    try {
      $promptPath = Join-Path $PromptDir "$task-prompt.md"
      $buildArgs = @((Join-Path $OpenCodeScripts "build-prompt.mjs"), $fixture, $task, $webBase, "--source-mode", $PromptSourceMode, "--padding-mode", $PromptPaddingMode)
      if ($PromptTokenTarget -gt 0) {
        $buildArgs += "--target-tokens"
        $buildArgs += "$PromptTokenTarget"
      }
      & $Node $buildArgs | Set-Content -LiteralPath $promptPath -Encoding UTF8
      $promptText = Get-Content -LiteralPath $promptPath -Raw
      $promptParts = @()
      $promptPartMeta = @()
      for ($offset = 0; $offset -lt $promptText.Length; $offset += $AttachmentChunkChars) {
        $length = [Math]::Min($AttachmentChunkChars, $promptText.Length - $offset)
        $partPath = Join-Path $PromptDir ("$task-prompt-part{0:D2}.md" -f ($promptParts.Count + 1))
        $partText = $promptText.Substring($offset, $length)
        Set-Content -LiteralPath $partPath -Value $partText -Encoding UTF8
        $promptParts += $partPath
        $promptPartMeta += [pscustomObject]@{
          path = $partPath
          index = $promptParts.Count
          meta = Get-TextMeta $partText
        }
      }

      $manifestBefore = Join-Path $ResultsDir "$task-manifest-before.json"
      & $Node (Join-Path $OpenCodeScripts "write-manifest.mjs") $fixture $manifestBefore
      $canaryBefore = Get-FileSha256 $CanaryPath
      $stdoutPath = Join-Path $LogsDir "$task-opencode.stdout.jsonl"
      $stderrPath = Join-Path $LogsDir "$task-opencode.stderr.log"
      $fileArgs = @()
      foreach ($part in $promptParts) {
        $fileArgs += "--file"
        $fileArgs += $part
      }

      $runResult = Invoke-ProcessCapture `
        -FileName $OpenCodePath `
        -Arguments (@("run", "--pure", "--format", "json", "--model", "$ProviderName/$Model", "--dir", $fixture) + $fileArgs + @("--title", "wsl-benchmark-$task", "Follow the attached benchmark prompt exactly.")) `
        -WorkingDirectory $fixture `
        -StdoutPath $stdoutPath `
        -StderrPath $stderrPath `
        -TimeoutSeconds ($TimeoutMinutes * 60)

      $gradePath = Join-Path $ResultsDir "$task-grade.json"
      & $Node (Join-Path $OpenCodeScripts "grade-run.mjs") $fixture $task $manifestBefore $gradePath | Out-Null
      $grade = Get-Content -LiteralPath $gradePath -Raw | ConvertFrom-Json
      $canaryAfter = Get-FileSha256 $CanaryPath
      $opencodeSummary = Read-OpenCodeRunSummary $stdoutPath

      Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
        event = "task_run"
        runner = "wsl-openai-compatible"
        baseUrl = $BaseUrl
        providerName = $ProviderName
        model = $Model
        opencodeModel = "$ProviderName/$Model"
        task = $task
        fixture = $fixture
        contextLimit = $ContextLimit
        outputLimit = $OutputLimit
        prompt = $promptPath
        promptMeta = [pscustomobject]@{
          targetTokens = if ($PromptTokenTarget -gt 0) { $PromptTokenTarget } else { $null }
          sourceMode = $PromptSourceMode
          paddingMode = $PromptPaddingMode
          meta = Get-TextMeta $promptText
          attachmentChunkChars = $AttachmentChunkChars
          attachmentCount = $promptParts.Count
          attachments = $promptPartMeta
        }
        stdout = $stdoutPath
        stderr = $stderrPath
        opencode = $runResult
        opencodeSummary = $opencodeSummary
        grade = $grade
        canary = [pscustomobject]@{
          path = $CanaryPath
          beforeSha256 = $canaryBefore
          afterSha256 = $canaryAfter
          unchanged = ($canaryBefore -eq $canaryAfter)
        }
      })
    } finally {
      Stop-Helper $staticServer
    }
  }
} finally {
  Stop-Helper $proxy
  $finalCanarySha256 = Get-FileSha256 $CanaryPath
  Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
    event = "benchmark_end"
    canary = [pscustomobject]@{
      path = $CanaryPath
      initialSha256 = $initialCanarySha256
      finalSha256 = $finalCanarySha256
      unchanged = ($initialCanarySha256 -eq $finalCanarySha256)
    }
  })
}

[pscustomobject]@{
  stamp = $Stamp
  resultsDir = $ResultsDir
  logsDir = $LogsDir
  promptsDir = $PromptDir
  summaryJsonl = $SummaryJsonl
  proxyEvents = $ProxyEvents
  configFile = $ConfigFile
} | ConvertTo-Json -Depth 6
