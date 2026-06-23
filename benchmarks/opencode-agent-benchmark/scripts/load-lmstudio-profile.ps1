param(
  [Parameter(Mandatory = $true)][ValidateSet("qwen-8k", "qwen-16k", "qwen-24k", "qwen-32k", "qwen-48k", "qwen-65k", "gemma-8k", "gemma-16k", "gemma-24k", "gemma-32k", "gemma-48k", "gemma-65k", "gemma12-8k", "gemma12-16k", "gemma12-24k", "gemma12-32k", "gemma12-48k", "gemma12-65k", "gemma12-131k", "gemma12-262k", "restore-initial")]
  [string]$Profile,
  [string]$BaseUrl = "http://127.0.0.1:1234",
  [string]$InitialStateJson = "",
  [int]$Parallel = 1,
  [int]$EvalBatchSize = 2048,
  [int]$PhysicalBatchSize = 512,
  [string]$KvCacheType = "",
  [ValidateSet("snake", "camel")]
  [string]$AdvancedKeyStyle = "snake",
  [switch]$SpeculativeDraftMtp,
  [string]$DraftModel = ""
)

$ErrorActionPreference = "Stop"

function Invoke-LmStudioJson {
  param([string]$Uri, [hashtable]$Body, [int]$TimeoutSec = 600)
  $json = $Body | ConvertTo-Json -Depth 12
  Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" -Body $json -TimeoutSec $TimeoutSec
}

function Get-LoadedModels {
  $raw = & lms ps --json
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return @()
  }
  $parsed = $raw | ConvertFrom-Json
  if ($null -eq $parsed) {
    return @()
  }
  @($parsed)
}

function Unload-ModelInstances {
  param([string]$Model)

  foreach ($loaded in (Get-LoadedModels | Where-Object { $_.modelKey -eq $Model })) {
    try {
      Invoke-LmStudioJson `
        -Uri "$($BaseUrl.TrimEnd('/'))/api/v1/models/unload" `
        -Body @{ instance_id = $loaded.identifier } `
        -TimeoutSec 180 | Out-Null
      Write-Host "Unloaded $($loaded.identifier)"
    } catch {
      Write-Host "Unload skipped or failed for $($loaded.identifier): $($_.Exception.Message)"
    }
  }
}

function Load-Model {
  param(
    [string]$Model,
    [int]$ContextLength,
    [int]$Parallel,
    [int]$EvalBatchSize,
    [int]$PhysicalBatchSize,
    [string]$KvCacheType,
    [string]$AdvancedKeyStyle,
    [bool]$SpeculativeDraftMtp,
    [string]$DraftModel
  )

  Unload-ModelInstances -Model $Model

  $body = @{
    model = $Model
    context_length = $ContextLength
    eval_batch_size = $EvalBatchSize
    physical_batch_size = $PhysicalBatchSize
    parallel = $Parallel
    flash_attention = $true
    offload_kv_cache_to_gpu = $true
    echo_load_config = $true
  }
  if ($Model -like "qwen/*") {
    $body.num_experts = 4
  }
  if (-not [string]::IsNullOrWhiteSpace($KvCacheType)) {
    if ($AdvancedKeyStyle -eq "camel") {
      $body.llamaKCacheQuantizationType = $KvCacheType
      $body.llamaVCacheQuantizationType = $KvCacheType
    } else {
      $body.llama_k_cache_quantization_type = $KvCacheType
      $body.llama_v_cache_quantization_type = $KvCacheType
    }
  }
  if ($SpeculativeDraftMtp) {
    if ($AdvancedKeyStyle -eq "camel") {
      $body.speculativeDraftMtp = $true
    } else {
      $body.speculative_draft_mtp = $true
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($DraftModel)) {
    if ($AdvancedKeyStyle -eq "camel") {
      $body.draftModel = $DraftModel
    } else {
      $body.draft_model = $DraftModel
    }
  }
  Invoke-LmStudioJson -Uri "$($BaseUrl.TrimEnd('/'))/api/v1/models/load" -Body $body -TimeoutSec 900
}

function Get-BenchmarkProfile {
  param([string]$Name)

  $contexts = @{
    "8k" = 8192
    "16k" = 16384
    "24k" = 24576
    "32k" = 32768
    "48k" = 49152
    "65k" = 65536
    "131k" = 131072
    "262k" = 262144
  }

  if ($Name -match "^(qwen|gemma|gemma12)-(8k|16k|24k|32k|48k|65k|131k|262k)$") {
    $family = $Matches[1]
    $ctx = $Matches[2]
    if ($family -ne "gemma12" -and @("131k", "262k") -contains $ctx) {
      throw "Profile $Name is not configured for the $ctx context"
    }
    return [pscustomobject]@{
      Model = if ($family -eq "qwen") { "qwen/qwen3-coder-30b" } elseif ($family -eq "gemma12") { "google/gemma-4-12b" } else { "google/gemma-4-e4b" }
      ContextLength = [int]$contexts[$ctx]
      Parallel = 1
    }
  }

  throw "Unknown benchmark profile $Name"
}

if ($Profile -ne "restore-initial") {
  $settings = Get-BenchmarkProfile $Profile
  Load-Model `
    -Model $settings.Model `
    -ContextLength $settings.ContextLength `
    -Parallel $Parallel `
    -EvalBatchSize $EvalBatchSize `
    -PhysicalBatchSize $PhysicalBatchSize `
    -KvCacheType $KvCacheType `
    -AdvancedKeyStyle $AdvancedKeyStyle `
    -SpeculativeDraftMtp ([bool]$SpeculativeDraftMtp) `
    -DraftModel $DraftModel
  return
}

if ($Profile -eq "restore-initial") {
  if ([string]::IsNullOrWhiteSpace($InitialStateJson) -or -not (Test-Path -LiteralPath $InitialStateJson)) {
    throw "Initial state JSON path is required for restore-initial"
  }
  $models = Get-Content -LiteralPath $InitialStateJson -Raw | ConvertFrom-Json
  $loadedModelKeys = @(
    Get-LoadedModels |
      Where-Object { $null -ne $_ -and @($_.PSObject.Properties.Name) -contains "modelKey" } |
      Select-Object -ExpandProperty modelKey -Unique
  )
  foreach ($modelKey in $loadedModelKeys) {
    Unload-ModelInstances -Model $modelKey
  }
  foreach ($model in $models) {
    $body = @{
      model = $model.modelKey
      context_length = [int]$model.contextLength
      eval_batch_size = 2048
      physical_batch_size = 512
      parallel = [int]$model.parallel
      flash_attention = $true
      offload_kv_cache_to_gpu = $true
      echo_load_config = $true
    }
    if ($model.modelKey -like "qwen/*") {
      $body.num_experts = 4
    }
    Invoke-LmStudioJson -Uri "$($BaseUrl.TrimEnd('/'))/api/v1/models/load" -Body $body -TimeoutSec 900 | Out-Null
  }
}
