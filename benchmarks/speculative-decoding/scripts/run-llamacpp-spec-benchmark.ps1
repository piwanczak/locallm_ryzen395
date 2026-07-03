param(
  [int]$Reps = 3,
  [int]$Tokens = 128,
  [int]$Context = 1024,
  [int]$DraftN = 3,
  [string]$RunName = "",
  [string]$PromptFile = "",
  [string]$LlamaCli = "",
  [string]$Model = "",
  [string]$Draft = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BenchDir = Split-Path -Parent $ScriptDir
$RepoRoot = Resolve-Path (Join-Path $BenchDir "..\..")

if (-not $RunName) {
  $RunName = Get-Date -Format "yyyyMMdd-HHmmss-qwen25coder-spec"
}
if (-not $PromptFile) {
  $PromptFile = Join-Path $BenchDir "prompts\coding-add.txt"
}
if (-not $LlamaCli) {
  $LlamaCli = Join-Path $RepoRoot "downloads\llama-vulkan\b9728-vulkan\llama-cli.exe"
}
if (-not $Model) {
  $Model = Join-Path $RepoRoot "downloads\speculative-qwen25coder\qwen2.5-coder-7b-q8_0.gguf"
}
if (-not $Draft) {
  $Draft = Join-Path $RepoRoot "downloads\speculative-qwen25coder\qwen2.5-coder-0.5b-q8_0.gguf"
}

foreach ($required in @($PromptFile, $LlamaCli, $Model, $Draft)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required path does not exist: $required"
  }
}

$Prompt = (Get-Content -LiteralPath $PromptFile -Raw).Trim()
$ResultDir = Join-Path $BenchDir ("results\" + $RunName)
New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null

function Quote-Arg([string]$Value) {
  return '"' + ($Value -replace '"', '\"') + '"'
}

function Get-Timing([string]$Text) {
  $matches = [regex]::Matches($Text, "\[ Prompt:\s*([0-9.]+)\s*t/s\s*\|\s*Generation:\s*([0-9.]+)\s*t/s\s*\]")
  if ($matches.Count -eq 0) {
    return [PSCustomObject]@{
      PromptTps = $null
      GenerationTps = $null
      TimingLine = $null
    }
  }
  $m = $matches[$matches.Count - 1]
  return [PSCustomObject]@{
    PromptTps = [double]$m.Groups[1].Value
    GenerationTps = [double]$m.Groups[2].Value
    TimingLine = $m.Value
  }
}

function Get-Median([double[]]$Values) {
  $sorted = @($Values | Where-Object { [double]::IsNaN($_) -eq $false } | Sort-Object)
  if ($sorted.Count -eq 0) {
    return $null
  }
  $mid = [math]::Floor($sorted.Count / 2)
  if ($sorted.Count % 2 -eq 1) {
    return [double]$sorted[$mid]
  }
  return ([double]$sorted[$mid - 1] + [double]$sorted[$mid]) / 2.0
}

function Invoke-LlamaVariant([string]$Variant, [int]$Rep) {
  $stdout = Join-Path $ResultDir ("$Variant-rep$Rep.stdout.txt")
  $stderr = Join-Path $ResultDir ("$Variant-rep$Rep.stderr.txt")
  Remove-Item -LiteralPath $stdout, $stderr -ErrorAction SilentlyContinue

  if ($Variant -eq "draft") {
    $argString = @(
      "-m", (Quote-Arg $Model),
      "--model-draft", (Quote-Arg $Draft),
      "--spec-type", "draft-simple",
      "--spec-draft-n-max", "$DraftN",
      "--spec-draft-ngl", "all",
      "-p", (Quote-Arg $Prompt),
      "-n", "$Tokens",
      "-c", "$Context",
      "-ngl", "all",
      "-fa", "on",
      "--temp", "0",
      "--seed", "42",
      "--no-display-prompt",
      "--no-warmup"
    ) -join " "
  } else {
    $argString = @(
      "-m", (Quote-Arg $Model),
      "-p", (Quote-Arg $Prompt),
      "-n", "$Tokens",
      "-c", "$Context",
      "-ngl", "all",
      "-fa", "on",
      "--temp", "0",
      "--seed", "42",
      "--no-display-prompt",
      "--no-warmup"
    ) -join " "
  }

  Write-Host "Running $Variant rep $Rep/$Reps..."
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $LlamaCli
  $psi.Arguments = $argString
  $psi.WorkingDirectory = $RepoRoot
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $p = [System.Diagnostics.Process]::Start($psi)
  $outText = $p.StandardOutput.ReadToEnd()
  $errText = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  $sw.Stop()

  Set-Content -LiteralPath $stdout -Value $outText -Encoding UTF8
  Set-Content -LiteralPath $stderr -Value $errText -Encoding UTF8
  $timing = Get-Timing ($outText + "`n" + $errText)

  $row = [PSCustomObject]@{
    variant = $Variant
    rep = $Rep
    exitCode = $p.ExitCode
    success = (($p.ExitCode -eq 0) -or (($p.ExitCode -eq 130) -and ($null -ne $timing.GenerationTps)))
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
    promptTps = $timing.PromptTps
    generationTps = $timing.GenerationTps
    timingLine = $timing.TimingLine
    stdout = (Split-Path -Leaf $stdout)
    stderr = (Split-Path -Leaf $stderr)
  }
  Write-Host ("{0} rep {1}: exit={2} generation={3} tok/s elapsed={4} ms" -f $Variant, $Rep, $row.exitCode, $row.generationTps, $row.elapsedMs)
  return $row
}

$Rows = @()
foreach ($variant in @("base", "draft")) {
  for ($rep = 1; $rep -le $Reps; $rep++) {
    $Rows += Invoke-LlamaVariant -Variant $variant -Rep $rep
  }
}

$BaseRows = @($Rows | Where-Object { $_.variant -eq "base" })
$DraftRows = @($Rows | Where-Object { $_.variant -eq "draft" })
$BaseGenMedian = Get-Median ([double[]]@($BaseRows | ForEach-Object { if ($null -ne $_.generationTps) { $_.generationTps } }))
$DraftGenMedian = Get-Median ([double[]]@($DraftRows | ForEach-Object { if ($null -ne $_.generationTps) { $_.generationTps } }))
$BasePromptMedian = Get-Median ([double[]]@($BaseRows | ForEach-Object { if ($null -ne $_.promptTps) { $_.promptTps } }))
$DraftPromptMedian = Get-Median ([double[]]@($DraftRows | ForEach-Object { if ($null -ne $_.promptTps) { $_.promptTps } }))
$Speedup = if ($BaseGenMedian -and $DraftGenMedian) { $DraftGenMedian / $BaseGenMedian } else { $null }

$Payload = [PSCustomObject]@{
  generatedAt = (Get-Date).ToString("o")
  runName = $RunName
  config = [PSCustomObject]@{
    llamaCli = Resolve-Path -LiteralPath $LlamaCli | ForEach-Object { $_.Path }
    model = Resolve-Path -LiteralPath $Model | ForEach-Object { $_.Path }
    draft = Resolve-Path -LiteralPath $Draft | ForEach-Object { $_.Path }
    promptFile = Resolve-Path -LiteralPath $PromptFile | ForEach-Object { $_.Path }
    reps = $Reps
    tokens = $Tokens
    context = $Context
    draftN = $DraftN
  }
  prompt = $Prompt
  summary = [PSCustomObject]@{
    baseMedianPromptTps = $BasePromptMedian
    draftMedianPromptTps = $DraftPromptMedian
    baseMedianGenerationTps = $BaseGenMedian
    draftMedianGenerationTps = $DraftGenMedian
    generationSpeedup = $Speedup
  }
  rows = $Rows
}

$SummaryJson = Join-Path $ResultDir "summary.json"
$Payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $SummaryJson -Encoding UTF8

$SummaryMd = Join-Path $ResultDir "summary.md"
$md = @()
$md += "# Speculative Decoding Run $RunName"
$md += ""
$md += "## Summary"
$md += ""
$md += "| Variant | Median prompt tok/s | Median generation tok/s |"
$md += "| --- | ---: | ---: |"
$md += ("| base | {0:N2} | {1:N2} |" -f $BasePromptMedian, $BaseGenMedian)
$md += ("| draft | {0:N2} | {1:N2} |" -f $DraftPromptMedian, $DraftGenMedian)
$md += ""
$md += ("Generation speedup: {0:N2}x" -f $Speedup)
$md += ""
$md += "## Configuration"
$md += ""
$md += "- target: ``$Model``"
$md += "- draft: ``$Draft``"
$md += "- tokens: ``$Tokens``"
$md += "- context: ``$Context``"
$md += "- draft n max: ``$DraftN``"
$md += ""
$md += "## Runs"
$md += ""
$md += "| Variant | Rep | Success | Exit | Prompt tok/s | Generation tok/s | Elapsed ms |"
$md += "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"
foreach ($row in $Rows) {
  $md += ("| {0} | {1} | {2} | {3} | {4:N2} | {5:N2} | {6:N0} |" -f $row.variant, $row.rep, $row.success, $row.exitCode, $row.promptTps, $row.generationTps, $row.elapsedMs)
}
$md += ""
$md | Set-Content -LiteralPath $SummaryMd -Encoding UTF8

Write-Host "Wrote $ResultDir"
