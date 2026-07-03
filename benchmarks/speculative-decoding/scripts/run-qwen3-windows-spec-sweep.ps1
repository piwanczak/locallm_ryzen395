param(
  [int]$Reps = 2,
  [int]$Tokens = 192,
  [int]$Context = 2048,
  [int]$DraftN = 2,
  [string]$RunName = "",
  [string]$PromptFile = "",
  [string]$LlamaCli = "",
  [string]$Model = "",
  [string]$Draft = "",
  [string[]]$Variants = @("base", "draft-simple", "draft-simple-fast"),
  [switch]$ReasoningOff
)

$ErrorActionPreference = "Stop"

if (($Variants.Count -eq 1) -and ($Variants[0] -like "*,*")) {
  $Variants = @($Variants[0].Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BenchDir = Split-Path -Parent $ScriptDir
$RepoRoot = Resolve-Path (Join-Path $BenchDir "..\..")

if (-not $RunName) {
  $RunName = Get-Date -Format "yyyyMMdd-HHmmss-qwen3-windows-spec"
}
if (-not $PromptFile) {
  $PromptFile = Join-Path $BenchDir "prompts\qwen3-coding-pattern.txt"
}
if (-not $LlamaCli) {
  $LlamaCli = Join-Path $RepoRoot "downloads\llama-vulkan\b9728-vulkan\llama-cli.exe"
}
if (-not $Model) {
  $promotedModel = Join-Path $RepoRoot "downloads\speculative-qwen3\Qwen3-8B-Q4_K_M.gguf"
  if (Test-Path -LiteralPath $promotedModel) {
    $Model = $promotedModel
  } else {
    $Model = Join-Path $env:USERPROFILE ".lmstudio\models\lmstudio-community\Qwen3-Coder-30B-A3B-Instruct-GGUF\Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf"
  }
}
if (-not $Draft) {
  $promotedDraft = Join-Path $RepoRoot "downloads\speculative-qwen3\Qwen3-0.6B-Q4_K_M.gguf"
  if (Test-Path -LiteralPath $promotedDraft) {
    $Draft = $promotedDraft
  } else {
    $Draft = Join-Path $RepoRoot "downloads\speculative-qwen3\Qwen3-0.6B-Q8_0.gguf"
  }
}

foreach ($required in @($PromptFile, $LlamaCli, $Model)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Required path does not exist: $required"
  }
}

$PromptText = (Get-Content -LiteralPath $PromptFile -Raw).Trim()
$ResultDir = Join-Path $BenchDir ("results\" + $RunName)
New-Item -ItemType Directory -Force -Path $ResultDir | Out-Null

function Quote-Arg([string]$Value) {
  return '"' + ($Value -replace '"', '\"') + '"'
}

function Get-VariantArgs([string]$Variant) {
  switch ($Variant) {
    "base" { return @() }
    "ngram-cache" { return @("--spec-type", "ngram-cache") }
    "ngram-mod" { return @("--spec-type", "ngram-mod", "--spec-ngram-mod-n-match", "16", "--spec-ngram-mod-n-min", "16", "--spec-ngram-mod-n-max", "64") }
    "ngram-simple" { return @("--spec-type", "ngram-simple", "--spec-ngram-simple-size-n", "8", "--spec-ngram-simple-size-m", "32", "--spec-ngram-simple-min-hits", "1") }
    "ngram-map-k" { return @("--spec-type", "ngram-map-k", "--spec-ngram-map-k-size-n", "8", "--spec-ngram-map-k-size-m", "32", "--spec-ngram-map-k-min-hits", "1") }
    "ngram-map-k4v" { return @("--spec-type", "ngram-map-k4v", "--spec-ngram-map-k4v-size-n", "8", "--spec-ngram-map-k4v-size-m", "32", "--spec-ngram-map-k4v-min-hits", "1") }
    "poll-0" { return @("--poll", "0") }
    "poll-100" { return @("--poll", "100") }
    "ubatch-256" { return @("-ub", "256") }
    "ubatch-1024" { return @("-ub", "1024") }
    "split-none" { return @("-sm", "none") }
    "win-fast" { return @("--poll", "0", "-sm", "none") }
    "cache-q8" { return @("-ctk", "q8_0", "-ctv", "q8_0") }
    "cache-q4" { return @("-ctk", "q4_0", "-ctv", "q4_0") }
    "flash-auto" { return @("-fa", "auto") }
    "flash-off" { return @("-fa", "off") }
    "draft-simple" {
      if (-not (Test-Path -LiteralPath $Draft)) {
        throw "Draft path does not exist: $Draft"
      }
      return @("--model-draft", $Draft, "--spec-type", "draft-simple", "--spec-draft-n-max", "$DraftN", "--spec-draft-ngl", "all")
    }
    "draft-simple-fast" {
      if (-not (Test-Path -LiteralPath $Draft)) {
        throw "Draft path does not exist: $Draft"
      }
      return @("--poll", "0", "-sm", "none", "--model-draft", $Draft, "--spec-type", "draft-simple", "--spec-draft-n-max", "$DraftN", "--spec-draft-ngl", "all")
    }
    "draft-simple-cpu" {
      if (-not (Test-Path -LiteralPath $Draft)) {
        throw "Draft path does not exist: $Draft"
      }
      return @("--model-draft", $Draft, "--spec-type", "draft-simple", "--spec-draft-n-max", "$DraftN", "--spec-draft-ngl", "0")
    }
    "q2-draft" {
      if (-not (Test-Path -LiteralPath $Draft)) {
        throw "Draft path does not exist: $Draft"
      }
      return @("--model-draft", $Draft, "--spec-type", "draft-simple", "--spec-draft-n-max", "$DraftN", "--spec-draft-ngl", "all")
    }
    default { throw "Unknown variant: $Variant" }
  }
}

function Get-Timing([string]$Text) {
  $matches = [regex]::Matches($Text, "\[ Prompt:\s*([0-9.]+)\s*t/s\s*\|\s*Generation:\s*([0-9.]+)\s*t/s\s*\]")
  if ($matches.Count -eq 0) {
    return [PSCustomObject]@{ PromptTps = $null; GenerationTps = $null; TimingLine = $null }
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
  if ($sorted.Count -eq 0) { return $null }
  $mid = [math]::Floor($sorted.Count / 2)
  if ($sorted.Count % 2 -eq 1) { return [double]$sorted[$mid] }
  return ([double]$sorted[$mid - 1] + [double]$sorted[$mid]) / 2.0
}

function Invoke-LlamaVariant([string]$Variant, [int]$Rep) {
  $stdout = Join-Path $ResultDir ("$Variant-rep$Rep.stdout.txt")
  $stderr = Join-Path $ResultDir ("$Variant-rep$Rep.stderr.txt")
  Remove-Item -LiteralPath $stdout, $stderr -ErrorAction SilentlyContinue

  $args = @(
    "-m", $Model,
    "-p", $PromptText,
    "-n", "$Tokens",
    "-c", "$Context",
    "-ngl", "all",
    "-fa", "on",
    "--temp", "0",
    "--seed", "42",
    "--no-display-prompt",
    "-st",
    "--no-warmup"
  )
  if ($ReasoningOff) {
    $args += @("-rea", "off")
  }
  $args += (Get-VariantArgs $Variant)

  Write-Host "Running $Variant rep $Rep/$Reps..."
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  Push-Location $RepoRoot
  try {
    & $LlamaCli @args 1> $stdout 2> $stderr
    $exitCode = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  $sw.Stop()
  $outText = if (Test-Path -LiteralPath $stdout) { Get-Content -LiteralPath $stdout -Raw } else { "" }
  $errText = if (Test-Path -LiteralPath $stderr) { Get-Content -LiteralPath $stderr -Raw } else { "" }
  $timing = Get-Timing ($outText + "`n" + $errText)

  $row = [PSCustomObject]@{
    variant = $Variant
    rep = $Rep
    exitCode = $exitCode
    success = (($exitCode -eq 0) -or (($exitCode -eq 130) -and ($null -ne $timing.GenerationTps)))
    elapsedMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
    promptTps = $timing.PromptTps
    generationTps = $timing.GenerationTps
    timingLine = $timing.TimingLine
    stdout = (Split-Path -Leaf $stdout)
    stderr = (Split-Path -Leaf $stderr)
  }
  Write-Host ("{0} rep {1}: success={2} exit={3} generation={4} tok/s elapsed={5} ms" -f $Variant, $Rep, $row.success, $row.exitCode, $row.generationTps, $row.elapsedMs)
  return $row
}

$Rows = @()
foreach ($variant in $Variants) {
  for ($rep = 1; $rep -le $Reps; $rep++) {
    $Rows += Invoke-LlamaVariant -Variant $variant -Rep $rep
  }
}

$SummaryRows = @()
foreach ($variant in $Variants) {
  $variantRows = @($Rows | Where-Object { $_.variant -eq $variant })
  $gen = Get-Median ([double[]]@($variantRows | ForEach-Object { if ($null -ne $_.generationTps) { $_.generationTps } }))
  $promptTps = Get-Median ([double[]]@($variantRows | ForEach-Object { if ($null -ne $_.promptTps) { $_.promptTps } }))
  $baseGen = Get-Median ([double[]]@(($Rows | Where-Object { $_.variant -eq "base" }) | ForEach-Object { if ($null -ne $_.generationTps) { $_.generationTps } }))
  $SummaryRows += [PSCustomObject]@{
    variant = $variant
    runs = $variantRows.Count
    successes = @($variantRows | Where-Object { $_.success }).Count
    medianPromptTps = $promptTps
    medianGenerationTps = $gen
    generationSpeedupVsBase = if ($baseGen -and $gen) { $gen / $baseGen } else { $null }
  }
}

$Best = $SummaryRows | Where-Object { $_.variant -ne "base" -and $_.successes -eq $_.runs -and $null -ne $_.medianGenerationTps } | Sort-Object medianGenerationTps -Descending | Select-Object -First 1

$Payload = [PSCustomObject]@{
  generatedAt = (Get-Date).ToString("o")
  runName = $RunName
  config = [PSCustomObject]@{
    llamaCli = (Resolve-Path -LiteralPath $LlamaCli).Path
    model = (Resolve-Path -LiteralPath $Model).Path
    draft = if (Test-Path -LiteralPath $Draft) { (Resolve-Path -LiteralPath $Draft).Path } else { $Draft }
    promptFile = (Resolve-Path -LiteralPath $PromptFile).Path
    reps = $Reps
    tokens = $Tokens
    context = $Context
    draftN = $DraftN
    variants = $Variants
    reasoningOff = [bool]$ReasoningOff
  }
  prompt = $PromptText
  summary = $SummaryRows
  best = $Best
  rows = $Rows
}

$Payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $ResultDir "summary.json") -Encoding UTF8

$md = @()
$md += "# Qwen3 Windows Speculative Sweep $RunName"
$md += ""
$md += "## Summary"
$md += ""
$md += "| Variant | Runs | Successes | Median prompt tok/s | Median generation tok/s | Speedup vs base |"
$md += "| --- | ---: | ---: | ---: | ---: | ---: |"
foreach ($row in $SummaryRows) {
  $md += ("| {0} | {1} | {2} | {3:N2} | {4:N2} | {5:N2}x |" -f $row.variant, $row.runs, $row.successes, $row.medianPromptTps, $row.medianGenerationTps, $row.generationSpeedupVsBase)
}
$md += ""
if ($Best) {
  $md += ("Best non-base variant: `{0}` at `{1:N2}` generation tok/s (`{2:N2}x`)." -f $Best.variant, $Best.medianGenerationTps, $Best.generationSpeedupVsBase)
} else {
  $md += "Best non-base variant: none."
}
$md += ""
$md += "## Configuration"
$md += ""
$md += "- target: ``$Model``"
$md += "- draft: ``$Draft``"
$md += "- prompt: ``$PromptFile``"
$md += "- tokens: ``$Tokens``"
$md += "- context: ``$Context``"
$md += "- draft n max: ``$DraftN``"
$md += "- reasoning off: ``$([bool]$ReasoningOff)``"
$md += ""
$md += "## Runs"
$md += ""
$md += "| Variant | Rep | Success | Exit | Prompt tok/s | Generation tok/s | Elapsed ms |"
$md += "| --- | ---: | ---: | ---: | ---: | ---: | ---: |"
foreach ($row in $Rows) {
  $md += ("| {0} | {1} | {2} | {3} | {4:N2} | {5:N2} | {6:N0} |" -f $row.variant, $row.rep, $row.success, $row.exitCode, $row.promptTps, $row.generationTps, $row.elapsedMs)
}
$md += ""
$md | Set-Content -LiteralPath (Join-Path $ResultDir "summary.md") -Encoding UTF8

Write-Host "Wrote $ResultDir"
