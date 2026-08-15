$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot "build-nightly.ps1"
$unsafeTemp = Join-Path $repoRoot "node_modules"

$originalTemp = [Environment]::GetEnvironmentVariable("TEMP", "Process")
$originalTmp = [Environment]::GetEnvironmentVariable("TMP", "Process")
$originalTmpDir = [Environment]::GetEnvironmentVariable("TMPDIR", "Process")

function Restore-ProcessEnvironmentVariable {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
    }
    else {
        Set-Item "Env:$Name" $Value
    }
}

function global:bun {
    $global:nightlyTestTemp = $env:TEMP
    $global:nightlyTestTmp = $env:TMP
    $global:nightlyTestTmpDir = $env:TMPDIR
    $global:LASTEXITCODE = 0
}

try {
    $env:TEMP = $unsafeTemp
    $env:TMP = $unsafeTemp
    $env:TMPDIR = $unsafeTemp

    & $scriptPath -SkipInstall

    if ($global:nightlyTestTemp -eq $unsafeTemp) {
        throw "The nightly build inherited a temp directory whose ancestors contain node_modules."
    }
    if ($global:nightlyTestTemp -ne $global:nightlyTestTmp) {
        throw "TEMP and TMP did not use the same isolated directory."
    }
    if ($global:nightlyTestTemp -ne $global:nightlyTestTmpDir) {
        throw "TEMP and TMPDIR did not use the same isolated directory."
    }
    if ([System.IO.Path]::GetFileName($global:nightlyTestTemp).StartsWith(".")) {
        throw "The nightly temp directory is hidden, so ASAR native unpack globs will not match."
    }
    if ($env:TEMP -ne $unsafeTemp -or $env:TMP -ne $unsafeTemp -or $env:TMPDIR -ne $unsafeTemp) {
        throw "The nightly build did not restore the caller's temp environment."
    }

    Write-Output "build-nightly.ps1 temp isolation OK"
}
finally {
    Restore-ProcessEnvironmentVariable "TEMP" $originalTemp
    Restore-ProcessEnvironmentVariable "TMP" $originalTmp
    Restore-ProcessEnvironmentVariable "TMPDIR" $originalTmpDir
    Remove-Item Function:\bun -ErrorAction SilentlyContinue
    Remove-Variable nightlyTestTemp, nightlyTestTmp, nightlyTestTmpDir -Scope Global -ErrorAction SilentlyContinue
}
