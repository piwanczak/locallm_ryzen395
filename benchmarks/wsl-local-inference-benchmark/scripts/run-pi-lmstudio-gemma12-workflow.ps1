param(
  [string]$Model = "google/gemma-4-12b",
  [string]$Profile = "gemma12-16k",
  [int]$ProxyPort = 5682,
  [string]$ReasoningEffort = "none",
  [string[]]$Tasks = @("js-edit", "browser-style"),
  [int]$TaskTimeoutSeconds = 900,
  [switch]$BuildPiImages,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$opencodeRoot = Join-Path $repoRoot "benchmarks\opencode-agent-benchmark"
$piRunner = Join-Path $repoRoot "benchmarks\pi-docker-agent-runner\scripts\run-pi-docker.ps1"
$loadProfileScript = Join-Path $opencodeRoot "scripts\load-lmstudio-profile.ps1"
$proxyScript = Join-Path $opencodeRoot "scripts\lmstudio-timing-proxy.mjs"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-gemma12-pi-lmstudio-workflow"
$logRoot = Join-Path $benchRoot "logs\$timestamp-gemma12-pi-lmstudio-workflow"
$summaryPath = Join-Path $runRoot "gemma12-pi-lmstudio-workflow-summary.json"
$initialState = Join-Path $runRoot "initial-lms-state.json"

New-Item -ItemType Directory -Force -Path $runRoot,$logRoot | Out-Null

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

function Quote-PowerShellSingle {
  param([Parameter(Mandatory = $true)][string]$Value)
  return "'" + ($Value -replace "'", "''") + "'"
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

function Invoke-ProcessCapture {
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
  Write-Utf8NoBom -Path $StdoutPath -Value $stdout
  Write-Utf8NoBom -Path $StderrPath -Value $stderr

  [pscustomobject]@{
    exitCode = if ($exited) { $process.ExitCode } else { $null }
    timedOut = -not $exited
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)
    stdout = $StdoutPath
    stderr = $StderrPath
  }
}

function Invoke-NodeVerifier {
  param([string]$Workspace, [string]$OutputPath)
  Invoke-ProcessCapture `
    -FileName "node" `
    -Arguments @("test.mjs") `
    -WorkingDirectory $Workspace `
    -StdoutPath $OutputPath `
    -StderrPath ($OutputPath -replace '\.out\.txt$', '.err.txt') `
    -TimeoutSeconds 120
}

function Invoke-BrowserVerifier {
  param([string]$Workspace, [string]$TaskDir, [string]$Prefix)
  $stdoutPath = Join-Path $TaskDir "$Prefix.out.txt"
  $stderrPath = Join-Path $TaskDir "$Prefix.err.txt"
  Invoke-ProcessCapture `
    -FileName "docker" `
    -Arguments @("run","--rm","-v","${Workspace}:/workspace","-v","${TaskDir}:/out","-w","/workspace","--entrypoint","sh","local/pi-agent:browser","-c","node verify.mjs") `
    -WorkingDirectory $repoRoot `
    -StdoutPath $stdoutPath `
    -StderrPath $stderrPath `
    -TimeoutSeconds 180
}

function Invoke-PiTask {
  param(
    [Parameter(Mandatory = $true)][string]$TaskName,
    [Parameter(Mandatory = $true)][string]$Workspace,
    [Parameter(Mandatory = $true)][string]$Prompt,
    [Parameter(Mandatory = $true)][string]$Tools,
    [switch]$Browser
  )

  $taskDir = Split-Path -Parent $Workspace
  $planPath = Join-Path $taskDir "pi-docker-plan.json"
  $invokeScript = Join-Path $taskDir "invoke-pi-runner.ps1"
  $baseUrlFromContainer = "http://host.docker.internal:$ProxyPort/v1"
  $piArgs = @(
    "--model", "local-openai/$Model",
    "--thinking", "off",
    "--tools", $Tools,
    "-p", $Prompt
  )
  $runnerSwitches = @("-NoTty")
  if ($Browser) { $runnerSwitches += "-Browser" }
  if ($BuildPiImages) { $runnerSwitches += "-Build" }
  $piArgsLiteral = ($piArgs | ForEach-Object { "  $(Quote-PowerShellSingle $_)" }) -join ",`r`n"
  $runnerSwitchText = if ($runnerSwitches.Count) { " " + ($runnerSwitches -join " ") } else { "" }
  Write-Utf8NoBom -Path $invokeScript -Value @"
param([switch]`$DryRunMode)
`$ErrorActionPreference = "Stop"
`$piArgs = @(
$piArgsLiteral
)
if (`$DryRunMode) {
  & $(Quote-PowerShellSingle $piRunner) -Workspace $(Quote-PowerShellSingle $Workspace) -BaseUrl $(Quote-PowerShellSingle $baseUrlFromContainer) -Model $(Quote-PowerShellSingle $Model)$runnerSwitchText -DryRun -PlanOutput $(Quote-PowerShellSingle $planPath) -PiArgs `$piArgs
} else {
  & $(Quote-PowerShellSingle $piRunner) -Workspace $(Quote-PowerShellSingle $Workspace) -BaseUrl $(Quote-PowerShellSingle $baseUrlFromContainer) -Model $(Quote-PowerShellSingle $Model)$runnerSwitchText -PiArgs `$piArgs
}
exit `$LASTEXITCODE
"@

  $dryRun = Invoke-ProcessCapture `
    -FileName "powershell.exe" `
    -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",$invokeScript,"-DryRunMode") `
    -WorkingDirectory $repoRoot `
    -StdoutPath (Join-Path $taskDir "pi-dry-run.out.txt") `
    -StderrPath (Join-Path $taskDir "pi-dry-run.err.txt") `
    -TimeoutSeconds 120

  $run = Invoke-ProcessCapture `
    -FileName "powershell.exe" `
    -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",$invokeScript) `
    -WorkingDirectory $repoRoot `
    -StdoutPath (Join-Path $taskDir "pi-run.out.txt") `
    -StderrPath (Join-Path $taskDir "pi-run.err.txt") `
    -TimeoutSeconds $TaskTimeoutSeconds

  [ordered]@{
    task = $TaskName
    workspace = $Workspace
    baseUrlFromContainer = $baseUrlFromContainer
    planPath = $planPath
    dryRun = $dryRun
    run = $run
  }
}

function New-JsEditTask {
  $task = "js-edit"
  $taskDir = Join-Path $runRoot $task
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path (Join-Path $workspace "src") | Out-Null
  Write-Utf8NoBom -Path (Join-Path $workspace "src\math.mjs") -Value @'
export function slidingWindowSum(values, size) {
  const windows = [];
  for (let i = 0; i < values.length - size; i += 1) {
    windows.push(values.slice(i, i + size).reduce((sum, value) => sum + value, 0));
  }
  return windows;
}
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "test.mjs") -Value @'
import assert from "node:assert/strict";
import { slidingWindowSum } from "./src/math.mjs";

assert.deepEqual(slidingWindowSum([1, 2, 3, 4], 2), [3, 5, 7]);
assert.deepEqual(slidingWindowSum([5, 5, 5], 3), [15]);
console.log("JS_EDIT_OK");
'@
  $pi = Invoke-PiTask `
    -TaskName $task `
    -Workspace $workspace `
    -Tools "read,write,bash" `
    -Prompt "Fix src/math.mjs so node test.mjs passes. Make the smallest correct change, run node test.mjs, and stop after reporting the result."
  $verify = Invoke-NodeVerifier -Workspace $workspace -OutputPath (Join-Path $taskDir "verify.out.txt")
  [pscustomobject]@{
    task = $task
    workspace = $workspace
    pi = [pscustomobject]$pi
    verifier = $verify
    workSucceeded = ($verify.exitCode -eq 0)
    runnerCompleted = ($pi.run.exitCode -eq 0 -and -not $pi.run.timedOut)
    passed = ($verify.exitCode -eq 0 -and $pi.run.exitCode -eq 0 -and -not $pi.run.timedOut)
  }
}

function New-BrowserStyleTask {
  $task = "browser-style"
  $taskDir = Join-Path $runRoot $task
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path $workspace | Out-Null
  Write-Utf8NoBom -Path (Join-Path $workspace "index.html") -Value @'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Pi Browser Fixture</title>
  </head>
  <body>
    <button id="save" type="button">Save</button>
    <p id="status" hidden></p>
    <script src="./app.js"></script>
  </body>
</html>
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "app.js") -Value @'
const save = document.querySelector("#save");
const status = document.querySelector("#status");

save.addEventListener("click", () => {
  status.textContent = "Saved";
  status.hidden = true;
});
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "verify.mjs") -Value @'
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import path from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require("/usr/local/lib/node_modules/playwright");

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
await page.goto(pathToFileURL(path.resolve("index.html")).href);
await page.click("#save");
await page.waitForFunction(() => document.querySelector("#status")?.textContent === "Saved");
const visible = await page.locator("#status").isVisible();
const text = await page.locator("#status").textContent();
await browser.close();
assert.equal(text, "Saved");
assert.equal(visible, true);
console.log("BROWSER_STYLE_OK");
'@
  $before = Invoke-BrowserVerifier -Workspace $workspace -TaskDir $taskDir -Prefix "verify-before"
  $pi = Invoke-PiTask `
    -TaskName $task `
    -Workspace $workspace `
    -Tools "read,write,bash" `
    -Browser `
    -Prompt "Fix the frontend so node verify.mjs passes. Make the smallest correct change, run node verify.mjs, and stop after reporting the result."
  $after = Invoke-BrowserVerifier -Workspace $workspace -TaskDir $taskDir -Prefix "verify-after"
  [pscustomobject]@{
    task = $task
    workspace = $workspace
    beforeVerifier = $before
    pi = [pscustomobject]$pi
    verifier = $after
    workSucceeded = ($after.exitCode -eq 0)
    runnerCompleted = ($pi.run.exitCode -eq 0 -and -not $pi.run.timedOut)
    passed = ($after.exitCode -eq 0 -and $pi.run.exitCode -eq 0 -and -not $pi.run.timedOut)
  }
}

$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
  dryRun = [bool]$DryRun
  model = $Model
  profile = $Profile
  proxyPort = $ProxyPort
  reasoningEffort = $ReasoningEffort
  tasks = $selectedTasks
  runRoot = $runRoot
  logRoot = $logRoot
  initialState = $initialState
  load = $null
  proxy = $null
  taskResults = @()
  restore = $null
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 16) + "`n")
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $piRunner)) { throw "Missing Pi runner script: $piRunner" }
if (-not (Test-Path -LiteralPath $loadProfileScript)) { throw "Missing LM Studio profile loader: $loadProfileScript" }
if (-not (Test-Path -LiteralPath $proxyScript)) { throw "Missing LM Studio proxy script: $proxyScript" }

& "$env:USERPROFILE\.lmstudio\bin\lms.exe" ps --json | Set-Content -LiteralPath $initialState -Encoding UTF8
$proxyProcess = $null
try {
  $summary.load = Invoke-ProcessCapture `
    -FileName "powershell.exe" `
    -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",$loadProfileScript,"-Profile",$Profile) `
    -WorkingDirectory $repoRoot `
    -StdoutPath (Join-Path $logRoot "load.out.txt") `
    -StderrPath (Join-Path $logRoot "load.err.txt") `
    -TimeoutSeconds 900
  if ($summary.load.exitCode -ne 0 -or $summary.load.timedOut) {
    throw "LM Studio profile load failed"
  }

  $env:LMSTUDIO_PROXY_REASONING_EFFORT = $ReasoningEffort
  $proxyEvents = Join-Path $runRoot "proxy-events.jsonl"
  $proxyOut = Join-Path $logRoot "proxy.out.log"
  $proxyErr = Join-Path $logRoot "proxy.err.log"
  $proxyProcess = Start-Process `
    -FilePath "node" `
    -ArgumentList (ConvertTo-ArgumentString @($proxyScript, "$ProxyPort", "http://127.0.0.1:1234", $proxyEvents)) `
    -WorkingDirectory $repoRoot `
    -RedirectStandardOutput $proxyOut `
    -RedirectStandardError $proxyErr `
    -WindowStyle Hidden `
    -PassThru
  Start-Sleep -Seconds 2
  $summary.proxy = [pscustomobject]@{
    processId = $proxyProcess.Id
    events = $proxyEvents
    stdout = $proxyOut
    stderr = $proxyErr
  }

  $results = New-Object System.Collections.ArrayList
  foreach ($task in $selectedTasks) {
    if ($task -eq "js-edit") {
      [void]$results.Add((New-JsEditTask))
    } elseif ($task -eq "browser-style") {
      [void]$results.Add((New-BrowserStyleTask))
    } else {
      throw "Unknown task: $task"
    }
    $summary.taskResults = @($results.ToArray())
    Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 24) + "`n")
  }
} finally {
  if ($proxyProcess -and -not $proxyProcess.HasExited) {
    try { Stop-Process -Id $proxyProcess.Id -Force } catch {}
  }
  $env:LMSTUDIO_PROXY_REASONING_EFFORT = ""
  $summary.restore = Invoke-ProcessCapture `
    -FileName "powershell.exe" `
    -Arguments @("-NoProfile","-ExecutionPolicy","Bypass","-File",$loadProfileScript,"-Profile","restore-initial","-InitialStateJson",$initialState) `
    -WorkingDirectory $repoRoot `
    -StdoutPath (Join-Path $logRoot "restore.out.txt") `
    -StderrPath (Join-Path $logRoot "restore.err.txt") `
    -TimeoutSeconds 900
}

$summary.completedAt = (Get-Date).ToString("o")
$summary.passed = (
  @($summary.taskResults).Count -eq @($selectedTasks).Count -and
  @($summary.taskResults | Where-Object { -not $_.passed }).Count -eq 0
)
Write-Utf8NoBom -Path $summaryPath -Value (($summary | ConvertTo-Json -Depth 24) + "`n")
Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
