param(
  [string[]]$Profiles = @("qwen-32k", "qwen-48k", "qwen-65k", "gemma-32k", "gemma-48k", "gemma-65k"),
  [string[]]$Tasks = @("js-window"),
  [int]$TimeoutMinutes = 12,
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
  [ValidateSet("snake", "camel")]
  [string]$AdvancedKeyStyle = "snake",
  [switch]$SpeculativeDraftMtp,
  [string]$DraftModel = "",
  [switch]$SkipRestore
)

$ErrorActionPreference = "Stop"

$runner = Join-Path $PSScriptRoot "run-opencode-benchmark.ps1"
$args = @{
  Profiles = $Profiles
  Tasks = $Tasks
  TimeoutMinutes = $TimeoutMinutes
  AttachmentChunkChars = $AttachmentChunkChars
  PromptSourceMode = $PromptSourceMode
  PromptPaddingMode = $PromptPaddingMode
  PromptTargetScale = $PromptTargetScale
  PromptTokenTarget = $PromptTokenTarget
  Parallel = $Parallel
  EvalBatchSize = $EvalBatchSize
  PhysicalBatchSize = $PhysicalBatchSize
  KvCacheType = $KvCacheType
  AdvancedKeyStyle = $AdvancedKeyStyle
  DraftModel = $DraftModel
}

if ($SkipRestore) {
  if ($SpeculativeDraftMtp) {
    & $runner @args -SpeculativeDraftMtp -SkipRestore
  } else {
    & $runner @args -SkipRestore
  }
} else {
  if ($SpeculativeDraftMtp) {
    & $runner @args -SpeculativeDraftMtp
  } else {
    & $runner @args
  }
}
