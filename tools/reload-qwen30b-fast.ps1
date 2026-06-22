param(
  [string]$Model = "qwen/qwen3-coder-30b",
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

Remove-Item Env:\LLAMA_ARG_MODEL_DRAFT -ErrorAction SilentlyContinue
Remove-Item Env:\LLAMA_ARG_DRAFT_MAX -ErrorAction SilentlyContinue
Remove-Item Env:\LLAMA_ARG_DRAFT_MIN -ErrorAction SilentlyContinue
Remove-Item Env:\LLAMA_ARG_DRAFT_P_MIN -ErrorAction SilentlyContinue

Write-Host "Reloading $Model with fast single-stream settings..."
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& $lms unload $Model 2>$null
$ErrorActionPreference = $previousErrorActionPreference
& $lms load $Model --context-length $ContextLength --parallel $Parallel --gpu max -y
& $lms ps
