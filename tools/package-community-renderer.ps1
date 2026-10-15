[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$BuildDirectory = 'build/windows-x86-godot'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
& (Join-Path $repository '.venv/Scripts/python.exe') (Join-Path $PSScriptRoot 'package_community_renderer.py') `
    --output ([IO.Path]::GetFullPath($OutputDirectory, $repository)) `
    --build ([IO.Path]::GetFullPath($BuildDirectory, $repository))
if ($LASTEXITCODE -ne 0) { throw 'Community renderer packaging failed.' }
