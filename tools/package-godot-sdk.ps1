[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$BuildDirectory = 'build/windows-x86-godot',
    [string]$LegacyDirectory = 'build/alpha-0.2-published/unpacked/reintegral-0.2.0-alpha.1-windows-x86'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory, $repository)
if (Test-Path -LiteralPath $output) { throw "SDK output already exists: $output. Choose a new directory to preserve local work." }
& (Join-Path $PSScriptRoot 'prepare-godot.ps1')
$prerequisites = & (Join-Path $PSScriptRoot 'prepare-sdk-tools.ps1')
& (Join-Path $repository '.venv/Scripts/python.exe') (Join-Path $PSScriptRoot 'package_godot_sdk.py') `
    --output $output --build ([IO.Path]::GetFullPath($BuildDirectory, $repository)) `
    --legacy ([IO.Path]::GetFullPath($LegacyDirectory, $repository)) `
    --python $prerequisites.python --powershell $prerequisites.powershell --godot-notices $prerequisites.godotNotices
if ($LASTEXITCODE -ne 0) { throw 'SDK packaging failed; inspect the retained staging folder.' }
