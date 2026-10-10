[CmdletBinding()]
param([string]$DiscDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$python = Join-Path $projectDirectory '.venv/Scripts/python.exe'
$content = Join-Path $projectDirectory '.local/content'
if (-not (Test-Path -LiteralPath $python)) { & (Join-Path $PSScriptRoot 'bootstrap.ps1') }
if (-not (Test-Path -LiteralPath (Join-Path $content 'manifest.json'))) {
    if (-not $DiscDirectory) { throw 'Provide -DiscDirectory with your Integral BIN/CUE folder for first-time preparation.' }
    & $python (Join-Path $PSScriptRoot 'import_content.py') --source $DiscDirectory --output $content
    if ($LASTEXITCODE -ne 0) { throw 'Disc import failed; see the retained incomplete import.' }
}
& (Join-Path $PSScriptRoot 'prepare-godot.ps1')
& $python (Join-Path $PSScriptRoot 'prepare_godot_assets.py') --content (Join-Path $content 'disc1')
if ($LASTEXITCODE -ne 0) { throw 'Godot asset conversion failed.' }
