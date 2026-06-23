param(
  [string[]]$Profiles = @("gemma-65k", "qwen-65k"),
  [string[]]$Tasks = @("python-ledger", "java-slug", "js-window", "web-retrieval", "browser-style"),
  [int]$TimeoutMinutes = 20,
  [int]$AttachmentChunkChars = 32000,
  [ValidateSet("full", "thin")]
  [string]$PromptSourceMode = "full",
  [ValidateSet("distractor", "neutral", "none")]
  [string]$PromptPaddingMode = "distractor",
  [double]$PromptTargetScale = 0.78,
  [int]$PromptTokenTarget = 0,
  [int]$Parallel = 1,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [string]$KvCacheType = "",
  [string]$ReasoningEffort = "",
  [ValidateSet("snake", "camel")]
  [string]$AdvancedKeyStyle = "snake",
  [switch]$SpeculativeDraftMtp,
  [string]$DraftModel = "",
  [switch]$SkipRestore
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent (Split-Path -Parent $Root)
$Node = "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
$PythonDir = "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python"
$NodeDir = "%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin"
$PiNodeDir = "%USERPROFILE%\AppData\Local\pi-node\current"
$OpenCode = "%USERPROFILE%\AppData\Local\pi-node\current\node_modules\opencode-ai\bin\opencode.exe"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ResultsDir = Join-Path $Root "results\$Stamp"
$LogsDir = Join-Path $Root "logs\$Stamp"
$PromptDir = Join-Path $Root "prompts\$Stamp"
$XdgConfig = Join-Path $Root ".xdg-config"
$XdgData = Join-Path $Root ".xdg-data"
$XdgCache = Join-Path $Root ".xdg-cache"
$XdgState = Join-Path $Root ".xdg-state"
$TmpDir = Join-Path $Root ".tmp"
$ConfigDir = Join-Path $Root ".opencode-empty"
$ConfigFile = Join-Path $Root "opencode-benchmark.config.json"
$InitialState = Join-Path $ResultsDir "initial-lms-state.json"
$SummaryJsonl = Join-Path $ResultsDir "runs.jsonl"
$ProxyEvents = Join-Path $ResultsDir "proxy-events.jsonl"
$CanaryPath = Join-Path $Root "fixtures\canary\outside-fixture-canary.txt"

New-Item -ItemType Directory -Force -Path $ResultsDir,$LogsDir,$PromptDir,$XdgConfig,$XdgData,$XdgCache,$XdgState,$TmpDir,$ConfigDir | Out-Null

$env:PATH = "$PythonDir;$NodeDir;$PiNodeDir;$env:PATH"
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
$env:LMSTUDIO_PROXY_REASONING_EFFORT = $ReasoningEffort

$SelectedProfiles = @($Profiles | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$SelectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

function Add-JsonLine {
  param([string]$Path, [object]$Value)
  ($Value | ConvertTo-Json -Depth 20 -Compress) | Add-Content -LiteralPath $Path
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

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FileName
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = ConvertTo-ArgumentString $Arguments
  foreach ($name in @("PATH","OPENCODE_CONFIG","OPENCODE_CONFIG_DIR","XDG_CONFIG_HOME","XDG_DATA_HOME","XDG_CACHE_HOME","XDG_STATE_HOME","TEMP","TMP","NO_COLOR","OPENCODE_DISABLE_AUTOUPDATE","OPENCODE_DISABLE_TELEMETRY")) {
    $psi.Environment[$name] = (Get-Item "Env:$name").Value
  }

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
    ExitCode = if ($exited) { $process.ExitCode } else { $null }
    TimedOut = -not $exited
    ElapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
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

function Start-NodeHelper {
  param(
    [string[]]$Arguments,
    [string]$StdoutPath,
    [string]$StderrPath
  )

  $quoted = $Arguments | ForEach-Object {
    if ($_ -match '[\s"]') {
      '"' + ($_ -replace '"', '\"') + '"'
    } else {
      $_
    }
  }
  Start-Process -FilePath $Node -ArgumentList ($quoted -join " ") -WorkingDirectory $Root -RedirectStandardOutput $StdoutPath -RedirectStandardError $StderrPath -WindowStyle Hidden -PassThru
}

function Stop-Helper {
  param($Process)
  if ($null -ne $Process -and -not $Process.HasExited) {
    try {
      Stop-Process -Id $Process.Id -Force
    } catch {}
  }
}

function Get-ProfileInfo {
  param(
    [string]$Profile,
    [double]$PromptTargetScale = 0.78,
    [int]$PromptTokenTarget = 0,
    [int]$Parallel = 1,
    [int]$EvalBatchSize = 2048,
    [int]$PhysicalBatchSize = 512,
    [string]$KvCacheType = "",
    [string]$AdvancedKeyStyle = "snake",
    [bool]$SpeculativeDraftMtp = $false,
    [string]$DraftModel = ""
  )

  $contexts = @{
    "8k" = 8192
    "16k" = 16384
    "24k" = 24576
    "32k" = 32768
    "48k" = 49152
    "65k" = 65536
    "131k" = 131072
    "262k" = 262144
  }

  if ($Profile -match "^(qwen|gemma|gemma12)-(8k|16k|24k|32k|48k|65k|131k|262k)$") {
    $family = $Matches[1]
    $ctx = $Matches[2]
    if ($family -ne "gemma12" -and @("131k", "262k") -contains $ctx) {
      throw "Profile $Profile is not configured for the $ctx context"
    }
    $modelName = if ($family -eq "qwen") { "qwen/qwen3-coder-30b" } elseif ($family -eq "gemma12") { "google/gemma-4-12b" } else { "google/gemma-4-e4b" }
    $contextTarget = [int]$contexts[$ctx]
    return [pscustomobject]@{
      Profile = $Profile
      Family = $family
      Model = $modelName
      OpenCodeModel = "lmstudio/$modelName"
      ContextTarget = $contextTarget
      PromptTokenTarget = if ($PromptTokenTarget -gt 0) { $PromptTokenTarget } else { [int][math]::Floor($contextTarget * $PromptTargetScale) }
      Parallel = $Parallel
      EvalBatchSize = $EvalBatchSize
      PhysicalBatchSize = $PhysicalBatchSize
      FlashAttention = $true
      OffloadKvCacheToGpu = $true
      NumExperts = if ($family -eq "qwen") { 4 } else { $null }
      KvCacheType = if ([string]::IsNullOrWhiteSpace($KvCacheType)) { $null } else { $KvCacheType }
      AdvancedKeyStyle = $AdvancedKeyStyle
      SpeculativeDraftMtp = $SpeculativeDraftMtp
      DraftModel = if ([string]::IsNullOrWhiteSpace($DraftModel)) { $null } else { $DraftModel }
    }
  }

  throw "Unknown profile $Profile"
}

function Get-FileSha256 {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
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

function Read-OpenCodeRunSummary {
  param([string]$StdoutPath)

  $steps = @()
  $toolCalls = @()
  if (-not (Test-Path -LiteralPath $StdoutPath)) {
    return [pscustomobject]@{ steps = $steps; toolCalls = $toolCalls }
  }

  $stepIndex = 0
  foreach ($line in (Get-Content -LiteralPath $StdoutPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
      $event = $line | ConvertFrom-Json
    } catch {
      continue
    }

    if ($event.type -eq "step_finish" -and $null -ne $event.part.tokens) {
      $stepIndex += 1
      $steps += [pscustomobject]@{
        index = $stepIndex
        reason = $event.part.reason
        inputTokens = [int]$event.part.tokens.input
        outputTokens = [int]$event.part.tokens.output
        totalTokens = [int]$event.part.tokens.total
        cacheRead = [int]$event.part.tokens.cache.read
        cacheWrite = [int]$event.part.tokens.cache.write
      }
    }

    if ($event.type -eq "tool_use") {
      $input = $event.part.state.input
      $toolCalls += [pscustomobject]@{
        tool = $event.part.tool
        status = $event.part.state.status
        title = $event.part.title
        exit = $event.part.state.metadata.exit
        command = $input.command
        workdir = $input.workdir
        filePath = $input.filePath
      }
    }
  }

  [pscustomobject]@{
    steps = $steps
    toolCalls = $toolCalls
  }
}

& lms ps --json | Set-Content -LiteralPath $InitialState -Encoding UTF8
& $OpenCode debug paths --pure | Set-Content -LiteralPath (Join-Path $ResultsDir "opencode-paths.txt") -Encoding UTF8
& $OpenCode debug config --pure | Set-Content -LiteralPath (Join-Path $ResultsDir "opencode-config-resolved.json") -Encoding UTF8
$InitialCanarySha256 = Get-FileSha256 $CanaryPath
Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
  event = "benchmark_start"
  profiles = $SelectedProfiles
  tasks = $SelectedTasks
  attachmentChunkChars = $AttachmentChunkChars
  promptSourceMode = $PromptSourceMode
  promptPaddingMode = $PromptPaddingMode
  promptTargetScale = $PromptTargetScale
  promptTokenTarget = if ($PromptTokenTarget -gt 0) { $PromptTokenTarget } else { $null }
  parallel = $Parallel
  evalBatchSize = $EvalBatchSize
  physicalBatchSize = $PhysicalBatchSize
  kvCacheType = if ([string]::IsNullOrWhiteSpace($KvCacheType)) { $null } else { $KvCacheType }
  reasoningEffort = if ([string]::IsNullOrWhiteSpace($ReasoningEffort)) { $null } else { $ReasoningEffort }
  advancedKeyStyle = $AdvancedKeyStyle
  speculativeDraftMtp = [bool]$SpeculativeDraftMtp
  draftModel = if ([string]::IsNullOrWhiteSpace($DraftModel)) { $null } else { $DraftModel }
  canary = [pscustomobject]@{
    path = $CanaryPath
    sha256 = $InitialCanarySha256
  }
})

$proxy = $null
try {
  $proxy = Start-NodeHelper `
    -Arguments @((Join-Path $PSScriptRoot "lmstudio-timing-proxy.mjs"), "5678", "http://127.0.0.1:1234", $ProxyEvents) `
    -StdoutPath (Join-Path $LogsDir "proxy.out.log") `
    -StderrPath (Join-Path $LogsDir "proxy.err.log")
  Start-Sleep -Seconds 2

  foreach ($profile in $SelectedProfiles) {
    $profileInfo = Get-ProfileInfo `
      -Profile $profile `
      -PromptTargetScale $PromptTargetScale `
      -PromptTokenTarget $PromptTokenTarget `
      -Parallel $Parallel `
      -EvalBatchSize $EvalBatchSize `
      -PhysicalBatchSize $PhysicalBatchSize `
      -KvCacheType $KvCacheType `
      -AdvancedKeyStyle $AdvancedKeyStyle `
      -SpeculativeDraftMtp ([bool]$SpeculativeDraftMtp) `
      -DraftModel $DraftModel
    $loadOut = Join-Path $LogsDir "$profile-load.out.log"
    $loadErr = Join-Path $LogsDir "$profile-load.err.log"
    $loadArgs = @(
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      (Join-Path $PSScriptRoot "load-lmstudio-profile.ps1"),
      "-Profile",
      $profile,
      "-Parallel",
      "$Parallel",
      "-EvalBatchSize",
      "$EvalBatchSize",
      "-PhysicalBatchSize",
      "$PhysicalBatchSize",
      "-AdvancedKeyStyle",
      $AdvancedKeyStyle
    )
    if (-not [string]::IsNullOrWhiteSpace($KvCacheType)) {
      $loadArgs += "-KvCacheType"
      $loadArgs += $KvCacheType
    }
    if ($SpeculativeDraftMtp) {
      $loadArgs += "-SpeculativeDraftMtp"
    }
    if (-not [string]::IsNullOrWhiteSpace($DraftModel)) {
      $loadArgs += "-DraftModel"
      $loadArgs += $DraftModel
    }
    $load = Invoke-ProcessCapture `
      -FileName "powershell.exe" `
      -Arguments $loadArgs `
      -WorkingDirectory $RepoRoot `
      -StdoutPath $loadOut `
      -StderrPath $loadErr `
      -TimeoutSeconds 1000

    Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
      event = "profile_load"
      profile = $profile
      model = $profileInfo.Model
      settings = $profileInfo
      load = $load
      stdout = $loadOut
      stderr = $loadErr
    })

    if ($load.TimedOut -or $load.ExitCode -ne 0) {
      continue
    }

    $resetRaw = powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "reset-fixtures.ps1") -RunId "$profile-$Stamp"
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
          -Arguments @((Join-Path $PSScriptRoot "static-server.mjs"), (Join-Path $fixture "site"), "$port") `
          -StdoutPath (Join-Path $LogsDir "$profile-$task-static.out.log") `
          -StderrPath (Join-Path $LogsDir "$profile-$task-static.err.log")
        Start-Sleep -Seconds 1
      }

      try {
        $promptPath = Join-Path $PromptDir "$profile-$task-prompt.md"
        & $Node (Join-Path $PSScriptRoot "build-prompt.mjs") $fixture $task $webBase "--target-tokens" "$($profileInfo.PromptTokenTarget)" "--source-mode" $PromptSourceMode "--padding-mode" $PromptPaddingMode | Set-Content -LiteralPath $promptPath -Encoding UTF8
        $promptText = Get-Content -LiteralPath $promptPath -Raw
        $promptParts = @()
        $promptPartMeta = @()
        $chunkSize = $AttachmentChunkChars
        for ($offset = 0; $offset -lt $promptText.Length; $offset += $chunkSize) {
          $length = [Math]::Min($chunkSize, $promptText.Length - $offset)
          $partPath = Join-Path $PromptDir ("$profile-$task-prompt-part{0:D2}.md" -f ($promptParts.Count + 1))
          $partText = $promptText.Substring($offset, $length)
          Set-Content -LiteralPath $partPath -Value $partText -Encoding UTF8
          $promptParts += $partPath
          $promptPartMeta += [pscustomobject]@{
            path = $partPath
            index = $promptParts.Count
            meta = Get-TextMeta $partText
          }
        }
        $promptMeta = [pscustomobject]@{
          targetTokens = $profileInfo.PromptTokenTarget
          sourceMode = $PromptSourceMode
          paddingMode = $PromptPaddingMode
          meta = Get-TextMeta $promptText
          attachmentChunkChars = $chunkSize
          attachmentCount = $promptParts.Count
          attachments = $promptPartMeta
        }
        $manifestBefore = Join-Path $ResultsDir "$profile-$task-manifest-before.json"
        & $Node (Join-Path $PSScriptRoot "write-manifest.mjs") $fixture $manifestBefore
        $canaryBefore = Get-FileSha256 $CanaryPath

        $stdoutPath = Join-Path $LogsDir "$profile-$task-opencode.stdout.jsonl"
        $stderrPath = Join-Path $LogsDir "$profile-$task-opencode.stderr.log"
        $model = $profileInfo.OpenCodeModel
        $fileArgs = @()
        foreach ($part in $promptParts) {
          $fileArgs += "--file"
          $fileArgs += $part
        }
        $runResult = Invoke-ProcessCapture `
          -FileName $OpenCode `
          -Arguments (@("run","--pure","--format","json","--model",$model,"--dir",$fixture) + $fileArgs + @("--title","benchmark-$profile-$task","Follow the attached benchmark prompt exactly.")) `
          -WorkingDirectory $fixture `
          -StdoutPath $stdoutPath `
          -StderrPath $stderrPath `
          -TimeoutSeconds ($TimeoutMinutes * 60)

        $gradePath = Join-Path $ResultsDir "$profile-$task-grade.json"
        $gradeStdout = & $Node (Join-Path $PSScriptRoot "grade-run.mjs") $fixture $task $manifestBefore $gradePath
        $grade = Get-Content -LiteralPath $gradePath -Raw | ConvertFrom-Json
        $canaryAfter = Get-FileSha256 $CanaryPath
        $opencodeSummary = Read-OpenCodeRunSummary $stdoutPath

        Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
          event = "task_run"
          profile = $profile
          model = $profileInfo.Model
          opencodeModel = $model
          settings = $profileInfo
          contextTarget = $profileInfo.ContextTarget
          task = $task
          fixture = $fixture
          prompt = $promptPath
          promptMeta = $promptMeta
          promptAttachments = $promptParts
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
  }
} finally {
  Stop-Helper $proxy
  if (-not $SkipRestore) {
    $restoreOut = Join-Path $LogsDir "restore-initial.out.log"
    $restoreErr = Join-Path $LogsDir "restore-initial.err.log"
    $restore = Invoke-ProcessCapture `
      -FileName "powershell.exe" `
      -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",(Join-Path $PSScriptRoot "load-lmstudio-profile.ps1"),"-Profile","restore-initial","-InitialStateJson",$InitialState) `
      -WorkingDirectory $RepoRoot `
      -StdoutPath $restoreOut `
      -StderrPath $restoreErr `
      -TimeoutSeconds 1200
    $finalCanarySha256 = Get-FileSha256 $CanaryPath
    Add-JsonLine -Path $SummaryJsonl -Value ([pscustomobject]@{
      event = "restore_initial"
      restore = $restore
      stdout = $restoreOut
      stderr = $restoreErr
      canary = [pscustomobject]@{
        path = $CanaryPath
        initialSha256 = $InitialCanarySha256
        finalSha256 = $finalCanarySha256
        unchanged = ($InitialCanarySha256 -eq $finalCanarySha256)
      }
    })
  }
}

[pscustomobject]@{
  Stamp = $Stamp
  ResultsDir = $ResultsDir
  LogsDir = $LogsDir
  PromptsDir = $PromptDir
  SummaryJsonl = $SummaryJsonl
  ProxyEvents = $ProxyEvents
} | ConvertTo-Json -Depth 6
