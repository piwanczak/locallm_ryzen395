param(
  [string]$RunId = ""
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Templates = Join-Path $Root "templates"
$WorkRoot = Join-Path $Root "fixtures\work"

if ([string]::IsNullOrWhiteSpace($RunId)) {
  $RunId = Get-Date -Format "yyyyMMdd-HHmmss"
}

$TargetRoot = Join-Path $WorkRoot $RunId
New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null

Get-ChildItem -LiteralPath $Templates -Directory | ForEach-Object {
  $target = Join-Path $TargetRoot $_.Name
  if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
  }
  Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse
}

[pscustomobject]@{
  RunId = $RunId
  WorkRoot = $TargetRoot
} | ConvertTo-Json -Depth 4
