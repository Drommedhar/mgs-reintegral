[CmdletBinding()]
param(
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')][string]$Version = '0.3.0',
    [Parameter(Mandatory)][string]$BuildDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory, $repository)
$build = [IO.Path]::GetFullPath($BuildDirectory, $repository)
if (Test-Path -LiteralPath $output) { throw "Release output already exists: $output" }
if (-not (Select-String -LiteralPath (Join-Path $build 'CMakeCache.txt') -Pattern '^CMAKE_BUILD_TYPE:STRING=RelWithDebInfo$' -Quiet)) {
    throw 'Release requires an optimized RelWithDebInfo build.'
}
$python = Join-Path $repository '.venv/Scripts/python.exe'
Push-Location $repository
try {
    & $python -m unittest tests.test_sdk_tools tests.test_sdk_package tests.test_godot_release_package
    if ($LASTEXITCODE -ne 0) { throw 'Release prerequisite tests failed.' }
    foreach ($kind in @('game', 'sdk')) {
        $name = if ($kind -eq 'sdk') { "reintegral-sdk-$Version-windows-x86" } else { "reintegral-$Version-windows-x86" }
        & (Join-Path $PSScriptRoot 'package-godot-sdk.ps1') -OutputDirectory (Join-Path $output $name) -BuildDirectory $build -Version $Version -Kind $kind
    }
    $packages = @(Get-ChildItem -LiteralPath $output -Filter '*.zip' -File | Select-Object -ExpandProperty FullName)
    & $python (Join-Path $PSScriptRoot 'verify_godot_package.py') @packages
    if ($LASTEXITCODE -ne 0) { throw 'Release archive validation failed.' }
    $symbols = @(Join-Path $build 'mgs-integral-native.pdb')
    foreach ($file in $symbols) { if (-not (Test-Path -LiteralPath $file)) { throw "Missing matching symbols: $file" } }
    Compress-Archive -LiteralPath $symbols -DestinationPath (Join-Path $output "reintegral-$Version-symbols.zip")
    $hashes = Get-ChildItem -LiteralPath $output -Filter '*.zip' -File | Sort-Object Name | ForEach-Object {
        (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $_.Name
    }
    $hashes | Set-Content -LiteralPath (Join-Path $output "reintegral-$Version-SHA256SUMS.txt") -Encoding ascii
    Write-Host "Validated release candidates: $output"
}
finally { Pop-Location }
