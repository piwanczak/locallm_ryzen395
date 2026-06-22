param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b"
)

$ErrorActionPreference = "Stop"

$helper = Join-Path $PSScriptRoot "reload-qwen30b-rest.ps1"

& $helper `
  -BaseUrl $BaseUrl `
  -Model $Model `
  -ContextLength 8192 `
  -EvalBatchSize 2048 `
  -PhysicalBatchSize 512 `
  -Parallel 1 `
  -NumExperts 4 `
  -FlashAttention $true `
  -OffloadKvCacheToGpu $true
