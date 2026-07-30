$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$pkgPath = Join-Path $repoRoot "apps\desktop\package.json"
$pkg = Get-Content -Raw -Path $pkgPath | ConvertFrom-Json
if (-not $pkg.version) {
    throw "Could not read version from $pkgPath"
}

$version = $pkg.version -replace "[-+].*$", ""
$parts = $version -split "\."
if ($parts.Count -ne 3) {
    throw "Unexpected version format: $($pkg.version)"
}

$bumped = "$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"
$date = (Get-Date).ToUniversalTime().ToString("yyyyMMdd")
$run = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$nightlyVersion = "$bumped-nightly.$date.$run"

$previousDesktopVersion = [Environment]::GetEnvironmentVariable(
    "T3CODE_DESKTOP_VERSION",
    [EnvironmentVariableTarget]::Process
)
$previousHostedAppChannel = [Environment]::GetEnvironmentVariable(
    "VITE_HOSTED_APP_CHANNEL",
    [EnvironmentVariableTarget]::Process
)

Push-Location $repoRoot
try {
    $env:T3CODE_DESKTOP_VERSION = $nightlyVersion

    # This flag is only for hosted app.t3.codes deployments. Baking it into
    # Electron makes the desktop client skip its local environment connection.
    Remove-Item Env:VITE_HOSTED_APP_CHANNEL -ErrorAction SilentlyContinue

    Write-Host "Building nightly desktop artifact: $nightlyVersion"
    & bun run dist:desktop:artifact
    if ($LASTEXITCODE -ne 0) {
        throw "Nightly desktop artifact build failed with exit code $LASTEXITCODE."
    }
}
finally {
    if ($null -eq $previousDesktopVersion) {
        Remove-Item Env:T3CODE_DESKTOP_VERSION -ErrorAction SilentlyContinue
    }
    else {
        $env:T3CODE_DESKTOP_VERSION = $previousDesktopVersion
    }

    if ($null -eq $previousHostedAppChannel) {
        Remove-Item Env:VITE_HOSTED_APP_CHANNEL -ErrorAction SilentlyContinue
    }
    else {
        $env:VITE_HOSTED_APP_CHANNEL = $previousHostedAppChannel
    }

    Pop-Location
}
