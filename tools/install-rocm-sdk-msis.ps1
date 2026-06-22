param(
    [string]$PackageRoot = '<amd-software-installer-cache>\Packages\Apps\ROCmSDKPackages',
    [string]$LogRoot = "$PSScriptRoot\..\downloads\amd-hip-sdk\msi-logs"
)

$ErrorActionPreference = 'Stop'

$packages = @(
    @{ Name = 'ROCm SDK Core'; Path = 'SDKCore\ROCm_SDK_Core.msi' },
    @{ Name = 'ROCm Libraries Runtime'; Path = 'LibrariesRuntime\ROCm_Libs_RT.msi' },
    @{ Name = 'ROCm RTC Runtime'; Path = 'RTCRuntime\ROCm_RTC_RT.msi' },
    @{ Name = 'ROCm Libraries Development'; Path = 'LibrariesDevelopment\ROCm_Libs_Dev.msi' },
    @{ Name = 'ROCm RTC Development'; Path = 'RTCDevelopment\ROCm_RTC_Dev.msi' }
)

New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
$summaryPath = Join-Path $LogRoot 'summary.txt'
"ROCm SDK MSI install started: $(Get-Date -Format o)" | Set-Content -Path $summaryPath

$results = foreach ($pkg in $packages) {
    $msi = Join-Path $PackageRoot $pkg.Path
    if (-not (Test-Path -LiteralPath $msi)) {
        [pscustomobject]@{
            Name = $pkg.Name
            Path = $msi
            ExitCode = $null
            Status = 'Missing'
        }
        continue
    }

    $safeName = ($pkg.Name -replace '[^A-Za-z0-9]+', '-').Trim('-')
    $log = Join-Path $LogRoot "$safeName.log"
    $args = @('/i', $msi, '/qn', '/norestart', '/L*v', $log)
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $args -Wait -PassThru

    [pscustomobject]@{
        Name = $pkg.Name
        Path = $msi
        ExitCode = $process.ExitCode
        Status = if ($process.ExitCode -in 0, 3010) { 'OK' } else { 'Failed' }
        Log = $log
    }
}

$results | Format-Table -AutoSize | Out-String | Add-Content -Path $summaryPath
$results | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $LogRoot 'summary.json')
$results

if ($results | Where-Object { $_.Status -eq 'Failed' -or $_.Status -eq 'Missing' }) {
    exit 1
}
