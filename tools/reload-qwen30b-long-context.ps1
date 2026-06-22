param(
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$Model = "qwen/qwen3-coder-30b",
  [int]$ContextLength = 32768,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [int]$Parallel = 1,
  [int]$NumExperts = 4,
  [bool]$FlashAttention = $true,
  [bool]$OffloadKvCacheToGpu = $true,
  [string]$Identifier = "",
  [switch]$UnloadDefaultModelInstance,
  [int]$TimeoutSec = 420
)

$ErrorActionPreference = "Stop"

$root = $BaseUrl.TrimEnd("/")
$instanceId = if ([string]::IsNullOrWhiteSpace($Identifier)) { $Model } else { $Identifier }

function Invoke-LmStudioJson {
  param(
    [string]$Uri,
    [hashtable]$Body,
    [int]$TimeoutSec
  )

  $json = $Body | ConvertTo-Json -Depth 12
  Invoke-RestMethod `
    -Uri $Uri `
    -Method Post `
    -ContentType "application/json" `
    -Body $json `
    -TimeoutSec $TimeoutSec
}

try {
  $unloadBody = @{ instance_id = $instanceId }
  Invoke-LmStudioJson `
    -Uri "$root/api/v1/models/unload" `
    -Body $unloadBody `
    -TimeoutSec 90 | Out-Null
} catch {
  Write-Host "Unload skipped or failed for '$instanceId': $($_.Exception.Message)"
}

if ($UnloadDefaultModelInstance -and $instanceId -ne $Model) {
  try {
    Invoke-LmStudioJson `
      -Uri "$root/api/v1/models/unload" `
      -Body @{ instance_id = $Model } `
      -TimeoutSec 90 | Out-Null
  } catch {
    Write-Host "Unload skipped or failed for default '$Model': $($_.Exception.Message)"
  }
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
}

if (-not [string]::IsNullOrWhiteSpace($Identifier)) {
  $loadBody.identifier = $Identifier
}

$loaded = Invoke-LmStudioJson `
  -Uri "$root/api/v1/models/load" `
  -Body $loadBody `
  -TimeoutSec $TimeoutSec

$loaded | ConvertTo-Json -Depth 12
