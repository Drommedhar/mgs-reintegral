[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BuildDirectory,
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+(?:-[a-z0-9.]+)?$')][string]$Version = '0.1.0-alpha.1',
    [string]$OutputDirectory = 'build/packages'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$build = [IO.Path]::GetFullPath($BuildDirectory, $project)
if (-not (Select-String -LiteralPath (Join-Path $build 'CMakeCache.txt') -Pattern '^CMAKE_BUILD_TYPE:STRING=RelWithDebInfo$' -Quiet)) {
    throw 'Release packaging requires a RelWithDebInfo build.'
}
$output = [IO.Path]::GetFullPath($OutputDirectory, $project)
$name = "reintegral-$Version-windows-x86"
$staging = Join-Path $output ($name + '-' + [Guid]::NewGuid().ToString('N'))
$package = Join-Path $staging $name
New-Item -ItemType Directory -Path $package -Force | Out-Null
foreach ($file in @('RE-INTEGRAL.exe', 'mgs-integral-native.exe')) {
    Copy-Item -LiteralPath (Join-Path $build $file) -Destination $package
}
Copy-Item -LiteralPath (Join-Path $build 'language-importer') -Destination $package -Recurse
if (Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object { $_.Extension -in @('.mgslang', '.bin', '.cue', '.iso', '.dat', '.dir') }) {
    throw 'Retail resource files must not be included in a player package.'
}
$versionText = & (Join-Path $package 'mgs-integral-native.exe') --version
if ($LASTEXITCODE -ne 0 -or $versionText -notlike "RE:INTEGRAL $Version (*)") { throw 'Executable version does not match package version.' }
Copy-Item -LiteralPath (Join-Path $project 'LICENSE') -Destination $package
Copy-Item -LiteralPath (Join-Path $project 'docs/ALPHA.md') -Destination (Join-Path $package 'START-HERE.md')
Copy-Item -LiteralPath (Join-Path $project 'docs/THIRD_PARTY.md') -Destination $package
Copy-Item -LiteralPath (Join-Path $project 'docs/LANGUAGES.md') -Destination $package
Copy-Item -LiteralPath (Join-Path $project 'docs/REGIONAL_LANGUAGE_RESOURCES.md') -Destination $package
Copy-Item -LiteralPath (Join-Path $project 'sources.lock.json') -Destination $package
$notices = Join-Path $package 'licenses'
New-Item -ItemType Directory -Path $notices | Out-Null
$licenseFiles = @{
    'psyz-scopes.txt' = 'vendor/psyz/LICENSE'
    'psyz-decomp-MIT.txt' = 'vendor/psyz/decomp/LICENSE'
    'MPL-2.0.txt' = 'vendor/psyz/psyz/src/psyz/LICENSE'
    'psxe-MIT.txt' = 'vendor/psyz/psyz/LICENSE-psxe.txt'
    'SDL-zlib.txt' = 'vendor/psyz/external/SDL/LICENSE.txt'
    'HIDAPI-BSD.txt' = 'vendor/psyz/external/SDL/src/hidapi/LICENSE-bsd.txt'
    'yuv2rgb-BSD.txt' = 'vendor/psyz/external/SDL/src/video/yuv2rgb/LICENSE'
    'Apache-2.0.txt' = 'licenses/Apache-2.0.txt'
}
foreach ($entry in $licenseFiles.GetEnumerator()) {
    Copy-Item -LiteralPath (Join-Path $project $entry.Value) -Destination (Join-Path $notices $entry.Key)
}
$stb = Get-Content -LiteralPath (Join-Path $project 'vendor/psyz/psyz/src/dbgserver/stb_image_write.h') -Raw
$noticeStart = $stb.IndexOf('This software is available under 2 licenses')
if ($noticeStart -lt 0) { throw 'Cannot locate stb_image_write license notice.' }
$stb.Substring($noticeStart) | Set-Content -LiteralPath (Join-Path $notices 'stb_image_write.txt') -Encoding utf8
'Vulkan headers: Copyright 2015-2024 The Khronos Group Inc. Licensed under Apache-2.0.' |
    Set-Content -LiteralPath (Join-Path $notices 'Vulkan-copyright.txt') -Encoding utf8
$commit = & git -C $project rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot identify package source commit.' }
[ordered]@{ version = $Version; commit = $commit; configuration = 'RelWithDebInfo'; architecture = 'x86'; engine = $versionText } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $package 'build-info.json') -Encoding utf8
$sourceName = "reintegral-$Version-mpl-source.zip"
$sourceRoot = Join-Path $staging 'mpl-source'
New-Item -ItemType Directory -Path $sourceRoot | Out-Null
foreach ($part in @('platform', 'psyz')) {
    Copy-Item -LiteralPath (Join-Path $project "vendor/psyz/psyz/src/$part") -Destination (Join-Path $sourceRoot $part) -Recurse
}
@"
RE:INTEGRAL $Version; source commit $commit
Modified MPL-covered source is in the accompanying $sourceName release asset.
It is available under MPL 2.0; see licenses/MPL-2.0.txt.
Build scripts, pinned upstream revisions and all patches:
https://github.com/Drommedhar/mgs-reintegral/tree/$commit
The project MIT license covers only the original contributions described in LICENSE.
Other components retain their own notices and documented license scopes.
"@ | Set-Content -LiteralPath (Join-Path $package 'SOURCE-AND-NOTICES.txt') -Encoding utf8
Compress-Archive -LiteralPath $package -DestinationPath (Join-Path $output "$name.zip") -Force
Compress-Archive -Path (Join-Path $sourceRoot '*') -DestinationPath (Join-Path $output $sourceName) -Force
$pdb = Join-Path $build 'mgs-integral-native.pdb'
if (-not (Test-Path -LiteralPath $pdb)) { throw 'RelWithDebInfo package requires matching PDB symbols.' }
Compress-Archive -LiteralPath $pdb -DestinationPath (Join-Path $output "reintegral-$Version-symbols.zip") -Force
$hashes = foreach ($file in @("$name.zip", $sourceName, "reintegral-$Version-symbols.zip")) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $output $file) -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $file"
}
$hashes | Set-Content -LiteralPath (Join-Path $output "reintegral-$Version-SHA256SUMS.txt") -Encoding ascii
Write-Host "Release files ready in $output"
