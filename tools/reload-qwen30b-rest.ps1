param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$ContextLength = 8192,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [int]$Parallel = 1,
  [int]$NumExperts = 4,
  [bool]$FlashAttention = $true,
  [bool]$OffloadKvCacheToGpu = $true
)

$ErrorActionPreference = "Stop"

$root = $BaseUrl.TrimEnd("/")
$instanceId = $Model

try {
  $unloadBody = @{ instance_id = $instanceId } | ConvertTo-Json -Depth 5
  Invoke-RestMethod `
    -Uri "$root/api/v1/models/unload" `
    -Method Post `
    -ContentType "application/json" `
    -Body $unloadBody `
    -TimeoutSec 60 | Out-Null
} catch {
  Write-Host "Unload skipped or failed: $($_.Exception.Message)"
}

$loadBody = @{
  model = $Model
  context_length = $ContextLength
  eval_batch_size = $EvalBatchSize
  physical_batch_size = $PhysicalBatchSize
  parallel = $Parallel
  flash_attention = $FlashAttention
  num_experts = $NumExperts
  offload_kv_cache_to_gpu = $OffloadKvCacheToGpu
  echo_load_config = $true
} | ConvertTo-Json -Depth 8

$loaded = Invoke-RestMethod `
  -Uri "$root/api/v1/models/load" `
  -Method Post `
  -ContentType "application/json" `
  -Body $loadBody `
  -TimeoutSec 180

$loaded | ConvertTo-Json -Depth 8
