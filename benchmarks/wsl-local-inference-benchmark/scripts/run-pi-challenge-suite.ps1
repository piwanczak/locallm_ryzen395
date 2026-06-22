param(
  [string]$Distro = "Ubuntu-24.04",
  [int]$Port = 8091,
  [int]$ContextSize = 8192,
  [string]$ModelAlias = "qwen/qwen3-coder-30b-q4",
  [string]$ModelPath = "",
  [string[]]$Tasks = @("single-function", "multi-file", "canary-preserve", "browser-form", "failing-command-recovery"),
  [switch]$UseExistingServer,
  [switch]$KeepServer,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$benchRoot = (Resolve-Path -LiteralPath (Join-Path $scriptRoot "..")).Path
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $benchRoot "..\..")).Path
$piRunner = Join-Path $repoRoot "benchmarks\pi-docker-agent-runner\scripts\run-pi-docker.ps1"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runRoot = Join-Path $benchRoot "results\$timestamp-pi-challenge-suite"
$logRoot = Join-Path $benchRoot "logs\$timestamp-pi-challenge-suite"
$summaryPath = Join-Path $runRoot "pi-challenge-suite-summary.json"

if (-not $ModelPath) {
  $ModelPath = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
}

function Write-Utf8NoBom {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function ConvertTo-WslPath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  if ($resolved -notmatch '^([A-Za-z]):\\(.*)$') { throw "Only local drive paths are supported for WSL conversion: $resolved" }
  return "/mnt/$($Matches[1].ToLowerInvariant())/$($Matches[2] -replace '\\', '/')"
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
  param([Parameter(Mandatory = $true)][scriptblock]$Command, [Parameter(Mandatory = $true)][string]$OutputPath)
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

function Test-SessionContains {
  param([string]$SessionPath, [string[]]$Patterns)
  if (-not (Test-Path -LiteralPath $SessionPath)) { return $false }
  $text = Get-Content -Raw -LiteralPath $SessionPath
  foreach ($pattern in $Patterns) {
    if ($text -notlike "*$pattern*") { return $false }
  }
  return $true
}

function Invoke-PiTask {
  param(
    [Parameter(Mandatory = $true)][string]$TaskName,
    [Parameter(Mandatory = $true)][string]$Workspace,
    [Parameter(Mandatory = $true)][string]$Prompt,
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
    "--tools", "read,write,bash",
    "--append-system-prompt", $toolReminder,
    "-p", $Prompt
  )
  $runnerSwitches = @("-NoTty")
  if ($Browser) { $runnerSwitches += "-Browser" }
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
  $dryRunCode = Invoke-Capture -OutputPath $dryRunOut -Command { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $invokeScript -DryRunMode }
  $piExitCode = Invoke-Capture -OutputPath $piOut -Command { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $invokeScript }
  Set-Content -LiteralPath $piExitPath -Encoding ASCII -Value $piExitCode
  $sessionExportExitCode = Export-LatestPiSession -TargetDir $taskDir
  return [ordered]@{
    dryRunExitCode = $dryRunCode
    piExitCode = $piExitCode
    sessionExportExitCode = $sessionExportExitCode
    planPath = $planPath
    piOutputPath = $piOut
    piExitPath = $piExitPath
    sessionLog = Join-Path $taskDir "pi-session.jsonl"
  }
}

function Invoke-NodeVerifier {
  param([string]$Workspace, [string]$OutputPath)
  $oldLocation = Get-Location
  try {
    Set-Location -LiteralPath $Workspace
    return Invoke-Capture -OutputPath $OutputPath -Command { & node test.mjs }
  } finally {
    Set-Location $oldLocation
  }
}

function Invoke-BrowserVerifier {
  param([string]$Workspace, [string]$TaskDir, [string]$Prefix)
  $command = "node verify.mjs > /out/$Prefix.out.txt 2>&1; code=`$?; printf '%s\n' `$code > /out/$Prefix.exitcode.txt; exit `$code"
  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & docker run --rm -v "${Workspace}:/workspace" -v "${TaskDir}:/out" -w /workspace --entrypoint sh local/pi-agent:browser -c $command | Out-Null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $oldPreference
  return $exitCode
}

function New-SingleFunctionTask {
  $task = "single-function"
  $taskDir = Join-Path $runRoot $task
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path (Join-Path $workspace "src") | Out-Null
  Write-Utf8NoBom -Path (Join-Path $workspace "src\stats.mjs") -Value @'
export function average(values) {
  return values.reduce((sum, value) => sum + value, 0) / (values.length + 1);
}
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "test.mjs") -Value @'
import assert from "node:assert/strict";
import { average } from "./src/stats.mjs";

assert.equal(average([2, 4, 6]), 4);
assert.equal(average([10]), 10);
console.log("SINGLE_FUNCTION_OK");
'@
  $pi = Invoke-PiTask -TaskName $task -Workspace $workspace -Prompt "Fix src/stats.mjs so node test.mjs passes. Make the smallest correct change, run node test.mjs, and stop after reporting the result."
  $verifyOut = Join-Path $taskDir "verify.out.txt"
  $verifyCode = Invoke-NodeVerifier -Workspace $workspace -OutputPath $verifyOut
  $passed = ($pi.piExitCode -eq 0 -and $verifyCode -eq 0)
  return [pscustomobject]@{ task = $task; workspace = $workspace; passed = $passed; verifierExitCode = $verifyCode; verifierOutputPath = $verifyOut; pi = [pscustomobject]$pi }
}

function New-MultiFileTask {
  $task = "multi-file"
  $taskDir = Join-Path $runRoot $task
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path (Join-Path $workspace "src") | Out-Null
  Write-Utf8NoBom -Path (Join-Path $workspace "src\settings.mjs") -Value @'
export const settings = {
  prefix: "Hello",
  punctuation: "!"
};
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "src\renderGreeting.mjs") -Value @'
import { settings } from "./settings.mjs";

export function renderGreeting(name) {
  return `${settings.prefix}, ${name}.`;
}
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "test.mjs") -Value @'
import assert from "node:assert/strict";
import { renderGreeting } from "./src/renderGreeting.mjs";

assert.equal(renderGreeting("Ada"), "Hello, Ada!");
assert.equal(renderGreeting("Lin"), "Hello, Lin!");
console.log("MULTI_FILE_OK");
'@
  $pi = Invoke-PiTask -TaskName $task -Workspace $workspace -Prompt "Fix the greeting behavior so node test.mjs passes. Inspect both src/settings.mjs and src/renderGreeting.mjs before editing. Make the smallest correct change, run node test.mjs, and stop after reporting the result."
  $verifyOut = Join-Path $taskDir "verify.out.txt"
  $verifyCode = Invoke-NodeVerifier -Workspace $workspace -OutputPath $verifyOut
  $sawMultiFileReads = Test-SessionContains -SessionPath $pi.sessionLog -Patterns @("src/settings.mjs", "src/renderGreeting.mjs")
  $passed = ($pi.piExitCode -eq 0 -and $verifyCode -eq 0 -and $sawMultiFileReads)
  return [pscustomobject]@{ task = $task; workspace = $workspace; passed = $passed; verifierExitCode = $verifyCode; verifierOutputPath = $verifyOut; sawMultiFileReads = $sawMultiFileReads; pi = [pscustomobject]$pi }
}

function New-CanaryTask {
  $task = "canary-preserve"
  $taskDir = Join-Path $runRoot $task
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path (Join-Path $workspace "src") | Out-Null
  Write-Utf8NoBom -Path (Join-Path $workspace "canary.txt") -Value "DO_NOT_TOUCH_CANARY`n"
  Write-Utf8NoBom -Path (Join-Path $workspace "src\slug.mjs") -Value @'
export function normalizeSlug(input) {
  return input.trim().toUpperCase().replace(/\s+/g, "-");
}
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "test.mjs") -Value @'
import assert from "node:assert/strict";
import fs from "node:fs";
import { normalizeSlug } from "./src/slug.mjs";

assert.equal(fs.readFileSync("canary.txt", "utf8"), "DO_NOT_TOUCH_CANARY\n");
assert.equal(normalizeSlug("  Local Agent Test  "), "local-agent-test");
console.log("CANARY_OK");
'@
  $pi = Invoke-PiTask -TaskName $task -Workspace $workspace -Prompt "Fix src/slug.mjs so node test.mjs passes. Do not modify canary.txt. Make the smallest correct change, run node test.mjs, and stop after reporting the result."
  $verifyOut = Join-Path $taskDir "verify.out.txt"
  $verifyCode = Invoke-NodeVerifier -Workspace $workspace -OutputPath $verifyOut
  $canaryContent = [string](Get-Content -Raw -LiteralPath (Join-Path $workspace "canary.txt"))
  $canaryPreserved = ($canaryContent -eq "DO_NOT_TOUCH_CANARY`n")
  $passed = ($pi.piExitCode -eq 0 -and $verifyCode -eq 0 -and $canaryPreserved)
  return [pscustomobject]@{ task = $task; workspace = $workspace; passed = $passed; verifierExitCode = $verifyCode; verifierOutputPath = $verifyOut; canaryPreserved = $canaryPreserved; pi = [pscustomobject]$pi }
}

function New-BrowserFormTask {
  $task = "browser-form"
  $taskDir = Join-Path $runRoot $task
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path $workspace | Out-Null
  Write-Utf8NoBom -Path (Join-Path $workspace "index.html") -Value @'
<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>Browser Form Challenge</title></head>
  <body>
    <label>Name <input id="name" value=""></label>
    <button id="greet" type="button">Greet</button>
    <p id="message" hidden></p>
    <script src="./app.js"></script>
  </body>
</html>
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "app.js") -Value @'
const input = document.querySelector("#name");
const button = document.querySelector("#greet");
const message = document.querySelector("#message");

button.addEventListener("click", () => {
  message.textContent = "Hello";
  message.hidden = true;
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
await page.fill("#name", "Ada");
await page.click("#greet");
await page.waitForFunction(() => document.querySelector("#message")?.textContent === "Hello, Ada");
const visible = await page.locator("#message").isVisible();
await browser.close();
assert.equal(visible, true);
console.log("BROWSER_FORM_OK");
'@
  Invoke-BrowserVerifier -Workspace $workspace -TaskDir $taskDir -Prefix "verify-before" | Out-Null
  $pi = Invoke-PiTask -TaskName $task -Workspace $workspace -Prompt "Fix the frontend so node verify.mjs passes. The message must include the entered name and be visible. Make the smallest correct change, run node verify.mjs, and stop after reporting the result." -Browser
  $verifyCode = Invoke-BrowserVerifier -Workspace $workspace -TaskDir $taskDir -Prefix "verify-after"
  $verifyOut = Join-Path $taskDir "verify-after.out.txt"
  $passed = ($pi.piExitCode -eq 0 -and $verifyCode -eq 0)
  return [pscustomobject]@{ task = $task; workspace = $workspace; passed = $passed; verifierExitCode = $verifyCode; verifierOutputPath = $verifyOut; pi = [pscustomobject]$pi }
}

function New-FailingCommandTask {
  $task = "failing-command-recovery"
  $taskDir = Join-Path $runRoot $task
  $workspace = Join-Path $taskDir "workspace"
  New-Item -ItemType Directory -Force -Path (Join-Path $workspace "src") | Out-Null
  Write-Utf8NoBom -Path (Join-Path $workspace "bad-test.mjs") -Value 'throw new Error("EXPECTED_BAD_COMMAND_FAILURE");'
  Write-Utf8NoBom -Path (Join-Path $workspace "src\filter.mjs") -Value @'
export function activeNames(users) {
  return users.filter((user) => user.active).map((user) => user.name);
}
'@
  Write-Utf8NoBom -Path (Join-Path $workspace "test.mjs") -Value @'
import assert from "node:assert/strict";
import { activeNames } from "./src/filter.mjs";

const users = [
  { name: "Zoe", active: true },
  { name: "Mallory", active: false },
  { name: "Ada", active: true }
];

assert.deepEqual(activeNames(users), ["Ada", "Zoe"]);
console.log("FAILING_COMMAND_RECOVERY_OK");
'@
  $pi = Invoke-PiTask -TaskName $task -Workspace $workspace -Prompt "First run node bad-test.mjs; that command is expected to fail. Then fix src/filter.mjs so node test.mjs passes. Make the smallest correct change, run node test.mjs, and stop after reporting the result."
  $verifyOut = Join-Path $taskDir "verify.out.txt"
  $verifyCode = Invoke-NodeVerifier -Workspace $workspace -OutputPath $verifyOut
  $sawExpectedFailure = Test-SessionContains -SessionPath $pi.sessionLog -Patterns @("EXPECTED_BAD_COMMAND_FAILURE")
  $passed = ($pi.piExitCode -eq 0 -and $verifyCode -eq 0 -and $sawExpectedFailure)
  return [pscustomobject]@{ task = $task; workspace = $workspace; passed = $passed; verifierExitCode = $verifyCode; verifierOutputPath = $verifyOut; sawExpectedFailure = $sawExpectedFailure; pi = [pscustomobject]$pi }
}

New-Item -ItemType Directory -Force -Path $runRoot, $logRoot | Out-Null
$selectedTasks = @($Tasks | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$summary = [ordered]@{
  createdAt = (Get-Date).ToString("o")
  completedAt = $null
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
  taskResults = @()
  serverStart = $null
  serverStop = $null
  passed = $false
}

if ($DryRun) {
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 12)
  Write-Output $summaryPath
  exit 0
}

if (-not (Test-Path -LiteralPath $piRunner)) { throw "Missing Pi runner: $piRunner" }
if (-not (Test-Path -LiteralPath $ModelPath)) { throw "Missing model file: $ModelPath" }

$benchRootWsl = ConvertTo-WslPath $benchRoot
$modelPathWsl = ConvertTo-WslPath $ModelPath
$logRootWsl = ConvertTo-WslPath $logRoot
$pidFileWsl = "$logRootWsl/llama-server.pid"
$logFileWsl = "$logRootWsl/llama-server.log"
$readyFileWsl = "$logRootWsl/llama-server.ready.json"
$startedServer = $false
$serverCommand = @(
  "cd $(Quote-Bash $benchRootWsl)", "&&",
  "MODEL_PATH=$(Quote-Bash $modelPathWsl)",
  "MODEL_ALIAS=$(Quote-Bash $ModelAlias)",
  "PORT=$Port", "CTX_SIZE=$ContextSize", "PARALLEL=1", "LLAMA_JINJA=1",
  "LOG_DIR=$(Quote-Bash $logRootWsl)",
  "PID_FILE=$(Quote-Bash $pidFileWsl)",
  "LOG_FILE=$(Quote-Bash $logFileWsl)",
  "READY_FILE=$(Quote-Bash $readyFileWsl)",
  "bash scripts/start-wsl-llama-server-amd.sh"
) -join " "
$stopCommand = @(
  "cd $(Quote-Bash $benchRootWsl)", "&&",
  "LOG_DIR=$(Quote-Bash $logRootWsl)",
  "PID_FILE=$(Quote-Bash $pidFileWsl)",
  "bash scripts/stop-wsl-llama-server-amd.sh"
) -join " "

try {
  if (-not $UseExistingServer) {
    $startOut = Join-Path $runRoot "llama-start.out.txt"
    $startCode = Invoke-Capture -OutputPath $startOut -Command { & wsl.exe --distribution $Distro --user root -- bash -lc $serverCommand }
    $summary.serverStart = [pscustomobject]@{ exitCode = $startCode; outputPath = $startOut }
    if ($startCode -ne 0) { throw "llama-server start failed with exit code $startCode" }
    $startedServer = $true
  }
  $results = New-Object System.Collections.ArrayList
  foreach ($task in $selectedTasks) {
    if ($task -eq "single-function") { [void]$results.Add((New-SingleFunctionTask)) }
    elseif ($task -eq "multi-file") { [void]$results.Add((New-MultiFileTask)) }
    elseif ($task -eq "canary-preserve") { [void]$results.Add((New-CanaryTask)) }
    elseif ($task -eq "browser-form") { [void]$results.Add((New-BrowserFormTask)) }
    elseif ($task -eq "failing-command-recovery") { [void]$results.Add((New-FailingCommandTask)) }
    else { throw "Unknown task: $task" }
  }
  $summary.taskResults = @($results.ToArray())
} finally {
  if ($startedServer -and -not $KeepServer) {
    $stopOut = Join-Path $runRoot "llama-stop.out.txt"
    $stopCode = Invoke-Capture -OutputPath $stopOut -Command { & wsl.exe --distribution $Distro --user root -- bash -lc $stopCommand }
    $summary.serverStop = [pscustomobject]@{ exitCode = $stopCode; outputPath = $stopOut }
  }
  $summary.completedAt = (Get-Date).ToString("o")
  $summary.passed = (
    @($summary.taskResults).Count -eq @($selectedTasks).Count -and
    @($summary.taskResults | Where-Object { -not $_.passed }).Count -eq 0 -and
    ($UseExistingServer -or $summary.serverStart.exitCode -eq 0) -and
    ($KeepServer -or $UseExistingServer -or $summary.serverStop.exitCode -eq 0)
  )
  Write-Utf8NoBom -Path $summaryPath -Value ($summary | ConvertTo-Json -Depth 16)
}

Write-Output $summaryPath
if (-not $summary.passed) { exit 1 }
