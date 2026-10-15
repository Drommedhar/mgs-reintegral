[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$BuildDirectory = 'build/windows-x86-godot',
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+-alpha\.[0-9]+$')][string]$Version = '0.3.0-alpha.1',
    [ValidateSet('sdk', 'game')][string]$Kind = 'sdk'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory, $repository)
if (Test-Path -LiteralPath $output) { throw "SDK output already exists: $output. Choose a new directory to preserve local work." }
& (Join-Path $PSScriptRoot 'prepare-godot.ps1')
$prerequisites = & (Join-Path $PSScriptRoot 'prepare-sdk-tools.ps1')
$auditArguments = @()
$catalogs = @(@('godot-content', 'godot-content-disc2') | Where-Object { Test-Path -LiteralPath (Join-Path $repository ".local/$_/catalog.json") })
if ($catalogs.Count -gt 0) { $auditArguments = @('--local-content', (Join-Path $repository '.local')) }
& (Join-Path $repository '.venv/Scripts/python.exe') (Join-Path $PSScriptRoot 'package_godot_sdk.py') `
    --output $output --build ([IO.Path]::GetFullPath($BuildDirectory, $repository)) `
    --legacy $prerequisites.legacy --legacy-source $prerequisites.legacySource `
    --godot-notices $prerequisites.godotNotices --version $Version --kind $Kind @auditArguments
if ($LASTEXITCODE -ne 0) { throw 'SDK packaging failed; inspect the retained staging folder.' }
