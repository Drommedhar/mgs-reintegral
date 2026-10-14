[CmdletBinding()]
param([string]$DiscDirectory, [string[]]$CueFiles, [ValidateSet(1, 2)][int]$Disc = 1, [string[]]$Stages, [switch]$CinematicsOnly, [switch]$UIOnly, [switch]$DeclarationsOnly)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (@($CinematicsOnly, $UIOnly, $DeclarationsOnly).Where({ $_ }).Count -gt 1) { throw 'Choose one incremental preparation mode.' }
$projectDirectory = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'sdk-paths.ps1')
$python = Get-MgsPython $projectDirectory
$content = Join-Path $projectDirectory '.local/content'
if (-not (Test-Path -LiteralPath $python)) {
    if (Test-Path -LiteralPath (Join-Path $projectDirectory 'sdk.json')) { throw "SDK Python is missing: $python. Extract a fresh SDK." }
    & (Join-Path $PSScriptRoot 'bootstrap.ps1')
}
if (-not (Test-Path -LiteralPath (Join-Path $content 'manifest.json'))) {
    if (-not $DiscDirectory) { throw 'Provide -DiscDirectory with your Integral BIN/CUE folder for first-time preparation.' }
    $importArguments = @((Join-Path $PSScriptRoot 'import_content.py'), '--source', $DiscDirectory, '--output', $content)
    if ($CueFiles) { $importArguments += @('--cue') + $CueFiles }
    & $python @importArguments
    if ($LASTEXITCODE -ne 0) { throw 'Disc import failed; see the retained incomplete import.' }
}
& (Join-Path $PSScriptRoot 'prepare-godot.ps1')
$arguments = @((Join-Path $PSScriptRoot 'prepare_godot_assets.py'), '--content', (Join-Path $content "disc$Disc"))
if ($Stages) { $arguments += @('--stages') + $Stages }
if ($CinematicsOnly) { $arguments += '--cinematics-only' }
if ($UIOnly) { $arguments += '--ui-only' }
if ($DeclarationsOnly) { $arguments += '--declarations-only' }
& $python @arguments
if ($LASTEXITCODE -ne 0) { throw 'Godot asset conversion failed.' }
