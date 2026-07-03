param(
  [string[]]$Tasks = @("backend-api"),
  [string]$BaseUrl = "http://127.0.0.1:5678/v1",
  [string]$Model = "qwen/qwen3-coder-30b-q4",
  [int]$TimeoutMinutes = 12,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$node = if ($env:NODE_EXE) { $env:NODE_EXE } else { "node" }
$opencode = if ($env:OPENCODE_EXE) { $env:OPENCODE_EXE } else { "opencode" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runId = "$stamp-opencode-real-usage"
$resultDir = Join-Path $benchRoot "results\$runId"
$logDir = Join-Path $benchRoot "logs\$runId"
$configDir = Join-Path $benchRoot ".opencode-empty"
$xdgConfig = Join-Path $benchRoot ".xdg-config"
$xdgData = Join-Path $benchRoot ".xdg-data"
$xdgCache = Join-Path $benchRoot ".xdg-cache"
$xdgState = Join-Path $benchRoot ".xdg-state"
$tmpDir = Join-Path $benchRoot ".tmp"
$configPath = Join-Path $resultDir "opencode-real-usage.config.json"
New-Item -ItemType Directory -Force -Path $resultDir,$logDir,$configDir,$xdgConfig,$xdgData,$xdgCache,$xdgState,$tmpDir | Out-Null

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value
  )
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
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

function Invoke-Capture {
  param(
    [Parameter(Mandatory = $true)][string]$FileName,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$StdoutPath,
    [Parameter(Mandatory = $true)][string]$StderrPath,
    [int]$TimeoutSeconds = 600
  )
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FileName
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = ConvertTo-ArgumentString $Arguments
  foreach ($name in @("PATH","OPENCODE_CONFIG","OPENCODE_CONFIG_DIR","XDG_CONFIG_HOME","XDG_DATA_HOME","XDG_CACHE_HOME","XDG_STATE_HOME","TEMP","TMP","NO_COLOR","OPENCODE_DISABLE_AUTOUPDATE","OPENCODE_DISABLE_TELEMETRY")) {
    if (Test-Path "Env:$name") { $psi.Environment[$name] = (Get-Item "Env:$name").Value }
  }
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $psi
  $startedAtUnixMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $sw = [Diagnostics.Stopwatch]::StartNew()
  [void]$process.Start()
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  $exited = $process.WaitForExit($TimeoutSeconds * 1000)
  if (-not $exited) {
    try {
      $taskkill = Join-Path $env:SystemRoot "System32\taskkill.exe"
      if (Test-Path -LiteralPath $taskkill) {
        & $taskkill /PID $process.Id /T /F | Out-Null
      } else {
        $process.Kill($true)
      }
    } catch {
      try { $process.Kill($true) } catch {}
    }
    try { [void]$process.WaitForExit(10000) } catch {}
  }
  $sw.Stop()
  $endedAtUnixMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  Write-Utf8NoBom -Path $StdoutPath -Value $stdoutTask.GetAwaiter().GetResult()
  Write-Utf8NoBom -Path $StderrPath -Value $stderrTask.GetAwaiter().GetResult()
  [pscustomobject]@{
    exitCode = if ($exited) { $process.ExitCode } else { $null }
    timedOut = -not $exited
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    startedAtUnixMs = $startedAtUnixMs
    endedAtUnixMs = $endedAtUnixMs
    stdout = $StdoutPath
    stderr = $StderrPath
  }
}

$config = [ordered]@{
  '$schema' = "https://opencode.ai/config.json"
  provider = [ordered]@{
    local = [ordered]@{
      npm = "@ai-sdk/openai-compatible"
      name = "Local OpenAI-compatible endpoint"
      options = [ordered]@{
        baseURL = $BaseUrl
        apiKey = "local"
      }
      models = [ordered]@{
        $Model = [ordered]@{
          name = "Local $Model"
          limit = [ordered]@{
            context = 65536
            output = 4096
          }
        }
      }
    }
  }
  model = "local/$Model"
  small_model = "local/$Model"
  permission = [ordered]@{
    "*" = "allow"
    external_directory = "deny"
    websearch = "deny"
    question = "deny"
    bash = [ordered]@{
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
Write-Utf8NoBom -Path $configPath -Value (($config | ConvertTo-Json -Depth 20) + "`n")

$env:OPENCODE_CONFIG = $configPath
$env:OPENCODE_CONFIG_DIR = $configDir
$env:XDG_CONFIG_HOME = $xdgConfig
$env:XDG_DATA_HOME = $xdgData
$env:XDG_CACHE_HOME = $xdgCache
$env:XDG_STATE_HOME = $xdgState
$env:TEMP = $tmpDir
$env:TMP = $tmpDir
$env:NO_COLOR = "1"
$env:OPENCODE_DISABLE_AUTOUPDATE = "1"
$env:OPENCODE_DISABLE_TELEMETRY = "1"

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$rows = New-Object System.Collections.ArrayList

foreach ($task in $selectedTasks) {
  $prepareJson = & $node (Join-Path $scriptRoot "real-usage-suite.mjs") prepare --task $task --run-id $runId --result-dir $resultDir
  if ($LASTEXITCODE -ne 0) { throw "prepare failed for $task" }
  $prepared = $prepareJson | ConvertFrom-Json
  $stdoutPath = Join-Path $logDir "$task-opencode.stdout.jsonl"
  $stderrPath = Join-Path $logDir "$task-opencode.stderr.log"
  $verifyPath = Join-Path $resultDir "$task-opencode-verification.json"
  $summaryPath = Join-Path $resultDir "$task-opencode-summary.json"
  $agentPromptPath = Join-Path $resultDir "$task-opencode-agent-prompt.md"
  $taskSpec = Get-Content -Raw -LiteralPath $prepared.promptPath
  $agentPrompt = @"
You are running the CLI-agent lane of the real-usage local coding benchmark.

Use your tools to inspect and edit files in the workspace, then run the verifier command before finishing.

Important: the task spec below is shared with the direct API JSON-edit harness and may contain instructions to return only JSON. Ignore those JSON-return instructions for this CLI-agent lane. Do not return a patch as your final answer. Modify the workspace files directly.

You already start in the task workspace. Run commands relative to the current directory, for example `node tools/test.mjs` or `npm test --silent`. Do not `cd` to an absolute Windows path; the benchmark workspace path contains spaces and OpenCode will block malformed absolute paths as external-directory access.

Keep all edits inside the workspace and respect the editable file list. Do not touch files outside the workspace.

Task spec:

$taskSpec
"@
  Write-Utf8NoBom -Path $agentPromptPath -Value $agentPrompt
  $args = @(
    "run",
    "--pure",
    "--format",
    "json",
    "--model",
    "local/$Model",
    "--dir",
    $prepared.workspace,
    "--file",
    $agentPromptPath,
    "--title",
    "real-usage-$task",
    "Use tools to modify the workspace and run the verifier before finishing."
  )
  if ($DryRun) {
    [void]$rows.Add([pscustomobject]@{
      task = $task
      dryRun = $true
      workspace = $prepared.workspace
      promptPath = $prepared.promptPath
      agentPromptPath = $agentPromptPath
      command = @($opencode) + $args
      passed = $null
    })
    continue
  }
  if (-not (Test-Path -LiteralPath $opencode)) {
    throw "OpenCode executable not found: $opencode"
  }
  $run = Invoke-Capture -FileName $opencode -Arguments $args -WorkingDirectory $prepared.workspace -StdoutPath $stdoutPath -StderrPath $stderrPath -TimeoutSeconds ($TimeoutMinutes * 60)
  & $node (Join-Path $scriptRoot "real-usage-suite.mjs") verify --task $task --workspace $prepared.workspace --manifest-before $prepared.manifestBefore --output $verifyPath | Out-Null
  & $node (Join-Path $scriptRoot "real-usage-suite.mjs") summarize-opencode --stdout $stdoutPath --verification $verifyPath --run-start-ms "$($run.startedAtUnixMs)" --run-end-ms "$($run.endedAtUnixMs)" --output $summaryPath | Out-Null
  $summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json
  [void]$rows.Add([pscustomobject]@{
    task = $task
    dryRun = $false
    workspace = $prepared.workspace
    promptPath = $prepared.promptPath
    agentPromptPath = $agentPromptPath
    run = $run
    verification = $verifyPath
    summary = $summaryPath
    metrics = $summary.metrics
    toolCallCount = $summary.toolCallCount
    failedToolCalls = $summary.failedToolCalls
    passed = $summary.passed
  })
}

$overall = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  runner = "opencode"
  dryRun = [bool]$DryRun
  runId = $runId
  baseUrl = $BaseUrl
  model = $Model
  resultDir = $resultDir
  logDir = $logDir
  tasks = @($rows.ToArray())
  passed = if ($DryRun) { $null } else { @($rows | Where-Object { $_.passed -ne $true }).Count -eq 0 }
}
$overallPath = Join-Path $resultDir "opencode-real-usage-summary.json"
Write-Utf8NoBom -Path $overallPath -Value (($overall | ConvertTo-Json -Depth 20) + "`n")
Write-Output $overallPath
if (-not $DryRun -and -not $overall.passed) { exit 1 }
