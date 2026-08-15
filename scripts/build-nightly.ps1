param(
    [switch]$SkipInstall,
    [ValidateRange(1, [int]::MaxValue)]
    [int]$FetchTimeoutMs = 300000
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Test-NodeModulesVisibleFrom {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $candidate = [System.IO.Path]::GetFullPath($Path)
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $candidate "node_modules") -PathType Container) {
            return $true
        }

        $parent = Split-Path -Parent $candidate
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $candidate) {
            return $false
        }
        $candidate = $parent
    }
}

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
$previousPnpmFetchTimeout = [Environment]::GetEnvironmentVariable(
    "PNPM_CONFIG_FETCH_TIMEOUT",
    [EnvironmentVariableTarget]::Process
)
$previousCi = [Environment]::GetEnvironmentVariable(
    "CI",
    [EnvironmentVariableTarget]::Process
)
$previousTemp = [Environment]::GetEnvironmentVariable(
    "TEMP",
    [EnvironmentVariableTarget]::Process
)
$previousTmp = [Environment]::GetEnvironmentVariable(
    "TMP",
    [EnvironmentVariableTarget]::Process
)
$previousTmpDir = [Environment]::GetEnvironmentVariable(
    "TMPDIR",
    [EnvironmentVariableTarget]::Process
)

$nightlyTempParent = Split-Path -Parent $repoRoot
while (Test-NodeModulesVisibleFrom $nightlyTempParent) {
    $parent = Split-Path -Parent $nightlyTempParent
    if ([string]::IsNullOrEmpty($parent) -or $parent -eq $nightlyTempParent) {
        throw "Could not find a temporary directory whose ancestors do not contain node_modules."
    }
    $nightlyTempParent = $parent
}
$nightlyTempRoot = Join-Path $nightlyTempParent "t3code-nightly-temp"

Push-Location $repoRoot
try {
    # The artifact self-containment probe must run outside both the workspace
    # node_modules tree and user-level Node installs. Node uses TEMP on Windows;
    # TMPDIR alone only affects Unix hosts.
    New-Item -ItemType Directory -Force -Path $nightlyTempRoot | Out-Null
    $env:TEMP = $nightlyTempRoot
    $env:TMP = $nightlyTempRoot
    $env:TMPDIR = $nightlyTempRoot

    # Desktop staging installs every supported provider's production package,
    # including large platform archives that can exceed pnpm's default timeout.
    $env:PNPM_CONFIG_FETCH_TIMEOUT = $FetchTimeoutMs

    if (-not $SkipInstall) {
        $localVp = Join-Path $repoRoot "node_modules\.bin\vp.cmd"
        if (Test-Path -Path $localVp -PathType Leaf) {
            Write-Host "Syncing workspace dependencies..."
            & $localVp i
        }
        else {
            # A node_modules tree last installed on Linux only has POSIX bin
            # links. Re-run the pinned package manager to recreate Windows
            # shims before anything tries to invoke vp.cmd.
            $env:CI = "true"
            $pnpm = Get-Command pnpm.cmd -ErrorAction SilentlyContinue
            if ($null -eq $pnpm) {
                $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
            }

            if ($null -ne $pnpm) {
                Write-Host "Restoring Windows workspace dependencies with pnpm..."
                & $pnpm.Source install
            }
            else {
                $corepack = Get-Command corepack.cmd -ErrorAction SilentlyContinue
                if ($null -eq $corepack) {
                    $corepack = Get-Command corepack -ErrorAction SilentlyContinue
                }
                if ($null -eq $corepack) {
                    throw "Could not find vp.cmd, pnpm, or corepack. Install pnpm and rerun this script."
                }

                Write-Host "Restoring Windows workspace dependencies with Corepack..."
                & $corepack.Source pnpm install
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Workspace dependency sync failed with exit code $LASTEXITCODE."
        }
        if (-not (Test-Path -Path $localVp -PathType Leaf)) {
            throw "Workspace dependency sync completed without creating $localVp."
        }
    }

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

    if ($null -eq $previousPnpmFetchTimeout) {
        Remove-Item Env:PNPM_CONFIG_FETCH_TIMEOUT -ErrorAction SilentlyContinue
    }
    else {
        $env:PNPM_CONFIG_FETCH_TIMEOUT = $previousPnpmFetchTimeout
    }

    if ($null -eq $previousCi) {
        Remove-Item Env:CI -ErrorAction SilentlyContinue
    }
    else {
        $env:CI = $previousCi
    }

    if ($null -eq $previousTemp) {
        Remove-Item Env:TEMP -ErrorAction SilentlyContinue
    }
    else {
        $env:TEMP = $previousTemp
    }

    if ($null -eq $previousTmp) {
        Remove-Item Env:TMP -ErrorAction SilentlyContinue
    }
    else {
        $env:TMP = $previousTmp
    }

    if ($null -eq $previousTmpDir) {
        Remove-Item Env:TMPDIR -ErrorAction SilentlyContinue
    }
    else {
        $env:TMPDIR = $previousTmpDir
    }

    Pop-Location
}
