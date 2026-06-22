param(
  [string]$Model = "qwen/qwen3-coder-30b",
  [string]$DraftModelPath = "$env:USERPROFILE\.lmstudio\models\unsloth\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q4_K_M.gguf",
  [int]$ContextLength = 8192,
  [int]$Parallel = 1
)

$ErrorActionPreference = "Stop"

$lms = Join-Path $env:USERPROFILE ".lmstudio\bin\lms.exe"

$env:LLAMA_ARG_FLASH_ATTN = "on"
$env:LLAMA_ARG_CACHE_TYPE_K = "q4_0"
$env:LLAMA_ARG_CACHE_TYPE_V = "q4_0"
$env:LLAMA_ARG_PRIO = "2"
$env:LLAMA_ARG_POLL = "100"

$env:LLAMA_ARG_MODEL_DRAFT = $DraftModelPath
$env:LLAMA_ARG_DRAFT_MAX = "8"
$env:LLAMA_ARG_DRAFT_MIN = "1"
$env:LLAMA_ARG_DRAFT_P_MIN = "0.3"

Write-Host "Reloading $Model with speculative draft model:"
Write-Host "  $DraftModelPath"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $lms unload $Model 2>$null
$ErrorActionPreference = $previousErrorActionPreference

& $lms load $Model --context-length $ContextLength --parallel $Parallel --gpu max -y
& $lms ps
