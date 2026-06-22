param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8091,
  [int]$ContextSize = 8192,
  [string]$ModelAlias = "qwen/qwen3-coder-30b-q4",
  [string]$ModelPath = "",
  [string[]]$Tasks = @("file-create", "js-edit", "browser-style"),
  [switch]$UseExistingServer,
  [switch]$KeepServer,
  [switch]$BuildPiImages,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$piRunner = Join-Path $repoRoot "benchmarks\pi-docker-agent-runner\scripts\run-pi-docker.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-pi-jinja-q4-toolcall-workflow"
$logRoot = Join-Path $benchRoot "logs\$timestamp-pi-jinja-q4-toolcall-workflow"
$summaryPath = Join-Path $runRoot "pi-jinja-q4-toolcall-workflow-summary.json"

if (-not $ModelPath) {
  $ModelPath = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Value
  )
  $dir = Split-Path -Parent $Path
  if ($dir) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function ConvertTo-WslPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  if ($resolved -notmatch '^([A-Za-z]):\\(.*)$') {
    throw "Only local drive paths are supported for WSL conversion: $resolved"
  }
  $drive = $Matches[1].ToLowerInvariant()
  $rest = $Matches[2] -replace '\\', '/'
  return "/mnt/$drive/$rest"
}

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)
  return "'" + ($Value -replace "'", "'\''") + "'"
}

function Quote-PowerShellSingle {
  param([Parameter(Mandatory = $true)][string]$Value)
  return "'" + ($Value -replace "'", "''") + "'"
}

function Invoke-Capture {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Command,
    [Parameter(Mandatory = $true)][string]$OutputPath
  )
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $Command 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  $output | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $OutputPath -Encoding UTF8
  return $exitCode
}

function Export-LatestPiSession {
  param([Parameter(Mandatory = $true)][string]$TargetDir)
  $command = 'latest=$(ls -t /sessions/--workspace--/*.jsonl | head -1); test -n $latest; cp $latest /out/pi-session.jsonl'
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & docker run --rm `
    -v "pi-docker-agent-runner_pi-agent-sessions:/sessions" `
    -v "${TargetDir}:/out" `
    --entrypoint sh local/pi-agent:base -c $command *> (Join-Path $TargetDir "pi-session-export.out.txt")
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  return $exitCode
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
  $dryRunOut = Join-Path $taskDir "pi-docker-dry-run.out.txt"
  $piOut = Join-Path $taskDir "pi-agent-$TaskName.out.txt"
  $piExitPath = Join-Path $taskDir "pi-agent-$TaskName.exitcode.txt"
  $invokeScript = Join-Path $taskDir "invoke-pi-runner.ps1"
  $baseUrlFromContainer = "http://host.docker.internal:$Port/v1"
  $toolReminder = "For this local Qwen/llama.cpp endpoint, when you call a tool you must output a complete tool block with the opening <tool_call> tag, then the <function=tool_name> block, then </function>, then </tool_call>. Never omit the opening <tool_call> tag. Do not write prose after a tool call."
  $piArgs = @(
    "--model", "local-openai/$ModelAlias",
    "--thinking", "off",
    "--tools", $Tools,
    "--append-system-prompt", $toolReminder,
    "-p", $Prompt
  )
  $runnerSwitches = @("-NoTty")
  if ($Browser) {
    $runnerSwitches += "-Browser"
  }
  if ($BuildPiImages) {
    $runnerSwitches += "-Build"
  }
  $piArgsLiteral = ($piArgs | ForEach-Object { "  $(Quote-PowerShellSingle $_)" }) -join ",`r`n"
  $runnerSwitchText = if ($runnerSwitches.Count) { " " + ($runnerSwitches -join " ") } else { "" }
  Write-Utf8NoBom -Path $invokeScript -Value @"
param([switch]`$DryRunMode)
`$ErrorActionPreference = "Stop"
`$piArgs = @(
$piArgsLiteral
)
if (`$DryRunMode) {
  & $(Quote-PowerShellSingle $piRunner) -Workspace $(Quote-PowerShellSingle $Workspace) -BaseUrl $(Quote-PowerShellSingle $baseUrlFromContainer) -Model $(Quote-PowerShellSingle $ModelAlias)$runnerSwitchText -DryRun -PlanOutput $(Quote-PowerShellSingle $planPath) -PiArgs `$piArgs
} else {
  & $(Quote-PowerShellSingle $piRunner) -Workspace $(Quote-PowerShellSingle $Workspace) -BaseUrl $(Quote-PowerShellSingle $baseUrlFromContainer) -Model $(Quote-PowerShellSingle $ModelAlias)$runnerSwitchText -PiArgs `$piArgs
}
exit `$LASTEXITCODE
"@

  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $invokeScript -DryRunMode *> $dryRunOut
  $dryRunCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference

  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $invokeScript *> $piOut
  $piExitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  Set-Content -LiteralPath $piExitPath -Encoding ASCII -Value $piExitCode
  $sessionExportExitCode = Export-LatestPiSession -TargetDir $taskDir

  return [ordered]@{
    task = $TaskName
    workspace = $Workspace
    dryRunExitCode = $dryRunCode
    piExitCode = $piExitCode
    sessionExportExitCode = $sessionExportExitCode
    planPath = $planPath
    piOutputPath = $piOut
    piExitPath = $piExitPath
    sessionLog = Join-Path $taskDir "pi-session.jsonl"
  }
}

function New-FileCreateTask {
  $taskDir = Join-Path $runRoot "file-create"
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path $workspace | Out-Null
  $result = Invoke-PiTask `
    -TaskName "file-create" `
    -Workspace $workspace `
    -Tools "write" `
    -Prompt "Create a file named pi_docker_result.txt in the current workspace containing exactly PI_DOCKER_OK and nothing else. Do not modify any other file."
  $resultFile = Join-Path $workspace "pi_docker_result.txt"
  $content = if (Test-Path -LiteralPath $resultFile) { [string](Get-Content -Raw -LiteralPath $resultFile) } else { $null }
  $result.resultFile = $resultFile
  $result.resultContent = $content
  $result.passed = ($result.piExitCode -eq 0 -and $content -eq "PI_DOCKER_OK")
  return $result
}

function New-JsEditTask {
  $taskDir = Join-Path $runRoot "js-edit"
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
  $result = Invoke-PiTask `
    -TaskName "js-edit" `
    -Workspace $workspace `
    -Tools "read,write,bash" `
    -Prompt "Fix src/math.mjs so node test.mjs passes. Make the smallest correct change, run node test.mjs, and stop after reporting the result."
  $verifyOut = Join-Path $taskDir "verify.out.txt"
  $oldLocation = Get-Location
  try {
    Set-Location -LiteralPath $workspace
    $verifyCode = Invoke-Capture -OutputPath $verifyOut -Command { & node test.mjs }
  } finally {
    Set-Location $oldLocation
  }
  $result.verifierExitCode = $verifyCode
  $result.verifierOutputPath = $verifyOut
  $result.passed = ($result.piExitCode -eq 0 -and $verifyCode -eq 0)
  return $result
}

function New-BrowserStyleTask {
  $taskDir = Join-Path $runRoot "browser-style"
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
  $beforeOut = Join-Path $taskDir "verify-before.out.txt"
  $beforeExit = Join-Path $taskDir "verify-before.exitcode.txt"
  $afterOut = Join-Path $taskDir "verify-after.out.txt"
  $afterExit = Join-Path $taskDir "verify-after.exitcode.txt"
  $verifyBeforeCommand = "node verify.mjs > /out/verify-before.out.txt 2>&1; code=`$?; printf '%s\n' `$code > /out/verify-before.exitcode.txt; exit 0"
  & docker run --rm -v "${workspace}:/workspace" -v "${taskDir}:/out" -w /workspace --entrypoint sh local/pi-agent:browser -c $verifyBeforeCommand | Out-Null
  $result = Invoke-PiTask `
    -TaskName "browser-style" `
    -Workspace $workspace `
    -Tools "read,write,bash" `
    -Browser `
    -Prompt "Fix the frontend so node verify.mjs passes. Make the smallest correct change, run node verify.mjs, and stop after reporting the result."
  $verifyAfterCommand = "node verify.mjs > /out/verify-after.out.txt 2>&1; code=`$?; printf '%s\n' `$code > /out/verify-after.exitcode.txt; exit `$code"
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & docker run --rm -v "${workspace}:/workspace" -v "${taskDir}:/out" -w /workspace --entrypoint sh local/pi-agent:browser -c $verifyAfterCommand | Out-Null
  $dockerExitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  $result.beforeVerifierExitCode = if (Test-Path -LiteralPath $beforeExit) { (Get-Content -Raw -LiteralPath $beforeExit).Trim() } else { $null }
  $result.beforeVerifierOutputPath = $beforeOut
  $result.afterVerifierExitCode = if (Test-Path -LiteralPath $afterExit) { (Get-Content -Raw -LiteralPath $afterExit).Trim() } else { $null }
  $result.afterVerifierOutputPath = $afterOut
  $result.passed = ($result.piExitCode -eq 0 -and $dockerExitCode -eq 0 -and $result.afterVerifierExitCode -eq "0")
  return $result
}

New-Item -ItemType Directory -Force -Path $runRoot, $logRoot | Out-Null
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$baseUrl = "http://127.0.0.1:$Port/v1"
$workflow = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  dryRun = [bool]$DryRun
  distro = $Distro
  port = $Port
  contextSize = $ContextSize
  modelAlias = $ModelAlias
  modelPath = $ModelPath
  useExistingServer = [bool]$UseExistingServer
  keepServer = [bool]$KeepServer
  runRoot = $runRoot
  logRoot = $logRoot
  tasks = $selectedTasks
  rawProbes = @()
  taskResults = @()
}
$rawProbeResults = New-Object System.Collections.ArrayList
$taskResults = New-Object System.Collections.ArrayList

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($workflow | ConvertTo-Json -Depth 16)
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $piRunner)) {
  throw "Missing Pi runner script: $piRunner"
}
if (-not (Test-Path -LiteralPath $ModelPath)) {
  throw "Missing model file: $ModelPath"
}

$benchRootWsl = ConvertTo-WslPath $benchRoot
$modelPathWsl = ConvertTo-WslPath $ModelPath
$logRootWsl = ConvertTo-WslPath $logRoot
$pidFileWsl = "$logRootWsl/llama-server.pid"
$logFileWsl = "$logRootWsl/llama-server.log"
$readyFileWsl = "$logRootWsl/llama-server.ready.json"
$startedServer = $false

$serverCommand = @(
  "cd $(Quote-Bash $benchRootWsl)",
  "&&",
  "MODEL_PATH=$(Quote-Bash $modelPathWsl)",
  "MODEL_ALIAS=$(Quote-Bash $ModelAlias)",
  "PORT=$Port",
  "CTX_SIZE=$ContextSize",
  "PARALLEL=1",
  "LLAMA_JINJA=1",
  "LOG_DIR=$(Quote-Bash $logRootWsl)",
  "PID_FILE=$(Quote-Bash $pidFileWsl)",
  "LOG_FILE=$(Quote-Bash $logFileWsl)",
  "READY_FILE=$(Quote-Bash $readyFileWsl)",
  "bash scripts/start-wsl-llama-server-amd.sh"
) -join " "

$stopCommand = @(
  "cd $(Quote-Bash $benchRootWsl)",
  "&&",
  "LOG_DIR=$(Quote-Bash $logRootWsl)",
  "PID_FILE=$(Quote-Bash $pidFileWsl)",
  "bash scripts/stop-wsl-llama-server-amd.sh"
) -join " "

try {
  if (-not $UseExistingServer) {
    $startOutPath = Join-Path $runRoot "llama-start.out.txt"
    $startCode = Invoke-Capture -OutputPath $startOutPath -Command {
      & wsl.exe --distribution $Distro --user root -- bash -lc $serverCommand
    }
    $workflow.llamaStart = [ordered]@{ exitCode = $startCode; outputPath = $startOutPath }
    if ($startCode -ne 0) {
      throw "llama-server start failed with exit code $startCode"
    }
    $startedServer = $true
  }

  foreach ($stream in @($false, $true)) {
    $suffix = if ($stream) { "stream" } else { "nonstream" }
    $probeOut = Join-Path $runRoot "endpoint-tool-call-probe-$suffix.json"
    $probeArgs = @(
      (Join-Path $scriptRoot "probe-openai-tool-calls.mjs"),
      "--base-url", $baseUrl,
      "--model", $ModelAlias,
      "--output", $probeOut
    )
    if ($stream) {
      $probeArgs += "--stream"
    }
    $probeCapture = Join-Path $runRoot "endpoint-tool-call-probe-$suffix.out.txt"
    $probeCode = Invoke-Capture -OutputPath $probeCapture -Command { & node @probeArgs }
    [void]$rawProbeResults.Add([ordered]@{
      stream = $stream
      exitCode = $probeCode
      output = $probeOut
      console = $probeCapture
    })
  }

  foreach ($task in $selectedTasks) {
    if ($task -eq "file-create") {
      [void]$taskResults.Add((New-FileCreateTask))
    } elseif ($task -eq "js-edit") {
      [void]$taskResults.Add((New-JsEditTask))
    } elseif ($task -eq "browser-style") {
      [void]$taskResults.Add((New-BrowserStyleTask))
    } else {
      throw "Unknown task: $task"
    }
  }
} finally {
  $finalizeTrace = Join-Path $runRoot "workflow-finalize.trace.txt"
  "enter-finally $(Get-Date -Format o)" | Set-Content -LiteralPath $finalizeTrace -Encoding UTF8
  if ($startedServer -and -not $KeepServer) {
    $stopOutPath = Join-Path $runRoot "llama-stop.out.txt"
    $stopCode = Invoke-Capture -OutputPath $stopOutPath -Command {
      & wsl.exe --distribution $Distro --user root -- bash -lc $stopCommand
    }
    $workflow.llamaStop = [ordered]@{ exitCode = $stopCode; outputPath = $stopOutPath }
  }
  "after-stop $(Get-Date -Format o)" | Add-Content -LiteralPath $finalizeTrace -Encoding UTF8
  $workflow.completedAt = (Get-Date).ToString("o")
  $workflow.rawProbes = @($rawProbeResults.ToArray())
  $workflow.taskResults = @($taskResults.ToArray())
  "after-array-assign raw=$(@($workflow.rawProbes).Count) tasks=$(@($workflow.taskResults).Count) $(Get-Date -Format o)" | Add-Content -LiteralPath $finalizeTrace -Encoding UTF8
  $workflow.passed = (
    @($workflow.rawProbes).Count -eq 2 -and
    @($workflow.taskResults).Count -eq @($selectedTasks).Count -and
    @($workflow.rawProbes | Where-Object { $_.exitCode -ne 0 }).Count -eq 0 -and
    @($workflow.taskResults | Where-Object { -not $_.passed }).Count -eq 0
  )
  "after-pass passed=$($workflow.passed) $(Get-Date -Format o)" | Add-Content -LiteralPath $finalizeTrace -Encoding UTF8
  $plainRawProbes = @($workflow.rawProbes | ForEach-Object {
    [pscustomobject]@{
      stream = [bool]$_["stream"]
      exitCode = [int]$_["exitCode"]
      output = [string]$_["output"]
      console = [string]$_["console"]
    }
  })
  $plainTaskResults = @($workflow.taskResults | ForEach-Object {
    [pscustomobject]@{
      task = [string]$_["task"]
      workspace = [string]$_["workspace"]
      dryRunExitCode = $_["dryRunExitCode"]
      piExitCode = $_["piExitCode"]
      sessionExportExitCode = $_["sessionExportExitCode"]
      planPath = [string]$_["planPath"]
      piOutputPath = [string]$_["piOutputPath"]
      piExitPath = [string]$_["piExitPath"]
      sessionLog = [string]$_["sessionLog"]
      resultFile = [string]$_["resultFile"]
      resultContent = if ($_["resultContent"] -ne $null) { [string]$_["resultContent"] } else { $null }
      verifierExitCode = $_["verifierExitCode"]
      verifierOutputPath = [string]$_["verifierOutputPath"]
      beforeVerifierExitCode = $_["beforeVerifierExitCode"]
      beforeVerifierOutputPath = [string]$_["beforeVerifierOutputPath"]
      afterVerifierExitCode = $_["afterVerifierExitCode"]
      afterVerifierOutputPath = [string]$_["afterVerifierOutputPath"]
      passed = [bool]$_["passed"]
    }
  })
  $summary = [pscustomobject]@{
    createdAt = $workflow.createdAt
    completedAt = $workflow.completedAt
    dryRun = [bool]$workflow.dryRun
    distro = $workflow.distro
    port = [int]$workflow.port
    contextSize = [int]$workflow.contextSize
    modelAlias = $workflow.modelAlias
    modelPath = $workflow.modelPath
    useExistingServer = [bool]$workflow.useExistingServer
    keepServer = [bool]$workflow.keepServer
    runRoot = $workflow.runRoot
    logRoot = $workflow.logRoot
    tasks = @($workflow.tasks)
    llamaStart = if ($workflow.Contains("llamaStart")) { $workflow["llamaStart"] } else { $null }
    llamaStop = if ($workflow.Contains("llamaStop")) { $workflow["llamaStop"] } else { $null }
    rawProbes = $plainRawProbes
    taskResults = $plainTaskResults
    passed = [bool]$workflow.passed
  }
  $summaryJson = $summary | ConvertTo-Json -Depth 8
  "after-json length=$($summaryJson.Length) $(Get-Date -Format o)" | Add-Content -LiteralPath $finalizeTrace -Encoding UTF8
  Write-Utf8NoBom -Path $summaryPath -Value $summaryJson
  "after-write $(Get-Date -Format o)" | Add-Content -LiteralPath $finalizeTrace -Encoding UTF8
}

Write-Output $summaryPath
if (-not $workflow.passed) {
  exit 1
}
