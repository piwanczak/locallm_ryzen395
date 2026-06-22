$ErrorActionPreference = "Stop"

$modelDir = Join-Path $env:USERPROFILE ".lmstudio\models\unsloth\Qwen3-Coder-30B-A3B-Instruct-GGUF"
$part = Join-Path $modelDir "downloading_Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf.part"
$target = Join-Path $modelDir "Qwen3-Coder-30B-A3B-Instruct-Q2_K.gguf"
$expectedBytes = 11258612896
$expectedSha256 = "6db9853d31fdb928a731666c9d44e8cdebf52f62f4810cb0908c6c677e6c84b5"

if (-not (Test-Path $part) -and -not (Test-Path $target)) {
  throw "Neither partial nor final Q2_K file exists in $modelDir"
}

$path = if (Test-Path $target) { $target } else { $part }
$item = Get-Item $path

if ($item.Length -ne $expectedBytes) {
  [pscustomobject]@{
    Path = $path
    Bytes = $item.Length
    ExpectedBytes = $expectedBytes
    Complete = $false
    Percent = [math]::Round(($item.Length / $expectedBytes) * 100, 2)
  }
  exit 2
}

if ($path -eq $part) {
  Move-Item -LiteralPath $part -Destination $target
  $path = $target
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()

[pscustomobject]@{
  Path = $path
  Bytes = (Get-Item $path).Length
  Complete = $true
  Sha256 = $hash
  HashMatches = ($hash -eq $expectedSha256)
}

if ($hash -ne $expectedSha256) {
  exit 3
}
