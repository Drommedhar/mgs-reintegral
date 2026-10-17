[CmdletBinding()]
param([Parameter(Mandatory)][string]$BuildDirectory)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$build = [IO.Path]::GetFullPath($BuildDirectory, $repository)
$renderer = Get-Content -LiteralPath (Join-Path $build 'renderer.json') -Raw | ConvertFrom-Json
if ($renderer.backend -ne 'godot') { throw 'Renderer preparation requires a Godot native host build.' }

& (Join-Path $PSScriptRoot 'prepare-godot.ps1')
$prerequisites = & (Join-Path $PSScriptRoot 'prepare-sdk-tools.ps1')
$descriptor = Join-Path $repository 'renderers/legacy/renderer.json'
$legacy = Get-Content -LiteralPath $descriptor -Raw | ConvertFrom-Json
$executable = Join-Path $prerequisites.legacy $legacy.executable
$baseline = Get-Content -LiteralPath (Join-Path $repository 'docs/data/godot_sdk_baseline.json') -Raw | ConvertFrom-Json
$member = "reintegral-$($legacy.version)-windows-x86/$($legacy.executable)"
if ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ne $baseline.legacy_archive_members.$member) {
    throw 'Legacy executable differs from preserved 0.2 baseline.'
}

$destination = Join-Path $build 'renderers/legacy'
$licenses = Join-Path $destination 'licenses'
New-Item -ItemType Directory -Path $licenses -Force | Out-Null
Copy-Item -LiteralPath $executable -Destination $destination -Force
Copy-Item -LiteralPath $descriptor -Destination $destination -Force
Get-ChildItem -LiteralPath (Join-Path $prerequisites.legacy 'licenses') -File |
    Copy-Item -Destination $licenses -Force
Copy-Item -LiteralPath $prerequisites.legacySource -Destination (Join-Path $destination 'legacy-0.2-mpl-source.zip') -Force
Write-Host "[renderers] Godot and Legacy 0.2 are installed for $build. Prepare your discs before playing."
