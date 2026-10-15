[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$lock = Get-Content -LiteralPath (Join-Path $repository 'sources.lock.json') -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'download-tool.ps1')
$tools = @{}
$legacy = $lock.legacyRelease
$archive = Get-MgsArchive $repository $legacy.player
$directory = Get-MgsChildPath (Join-Path $repository '.tools/sdk-prerequisites') "legacy-$($legacy.version)"
if (-not (Test-MgsArchiveContents $archive $directory)) {
    if (Test-Path -LiteralPath $directory) { Remove-Item -LiteralPath $directory -Recurse -Force }
    Expand-MgsTool $archive $directory
    if (-not (Test-MgsArchiveContents $archive $directory)) { throw 'Legacy prerequisite extraction is incomplete.' }
}
$tools.legacy = Join-Path $directory "reintegral-$($legacy.version)-windows-x86"
$tools.legacySource = Get-MgsArchive $repository $legacy.source
$notices = Join-Path $repository '.tools/sdk-prerequisites/godot-notices'
New-Item -ItemType Directory -Path $notices -Force | Out-Null
foreach ($entry in $lock.godotNotices) {
    $file = Get-MgsArchive $repository $entry
    Copy-Item -LiteralPath $file -Destination $notices -Force
}
$tools.godotNotices = $notices
return $tools
