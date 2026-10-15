[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$version = '4.8-dev7'
. (Join-Path $PSScriptRoot 'download-tool.ps1')
$toolDirectory = Install-MgsTool $projectDirectory 'godot'
$executable = Join-Path $toolDirectory "Godot_v${version}_win64_console.exe"
if (Test-Path -LiteralPath (Join-Path $projectDirectory 'sdk.json')) {
    foreach ($path in @($executable, (Join-Path $projectDirectory 'renderers/godot/project/.generated/psx.vert.glsl'),
        (Join-Path $projectDirectory 'renderers/godot/project/.generated/psx.frag.glsl'),
        (Join-Path $projectDirectory 'renderers/godot/project/.generated/legacy-debug-font.bin'))) {
        if (-not (Test-Path -LiteralPath $path)) { throw "SDK component is missing: $path. Extract a fresh SDK." }
    }
    $reported = & $executable --version
    if ($LASTEXITCODE -ne 0 -or $reported.Trim() -ne '4.8.dev7.official.c971f93e7') { throw "Unexpected SDK Godot version: $reported" }
    return
}
$reportedVersion = & $executable --version
if ($LASTEXITCODE -ne 0 -or $reportedVersion.Trim() -ne '4.8.dev7.official.c971f93e7') {
    throw "Unexpected Godot version: $reportedVersion"
}
$generated = Join-Path $projectDirectory 'renderers/godot/project/.generated'
New-Item -ItemType Directory -Path $generated -Force | Out-Null
$shaderRoot = Join-Path $projectDirectory 'vendor/psyz/psyz/src/platform/shaders'
$vertex = Get-Content -LiteralPath (Join-Path $shaderRoot 'psx.vert.glsl') -Raw
if (-not $vertex.Contains('vec4(x, -y, 0.0, 1.0)')) {
    throw 'Psyz vertex coordinate convention changed; review the Godot shader adapter.'
}
# Godot RenderingDevice uses the Vulkan viewport convention directly.
$vertex.Replace('vec4(x, -y, 0.0, 1.0)', 'vec4(x, y, 0.0, 1.0)') |
    Set-Content -LiteralPath (Join-Path $generated 'psx.vert.glsl') -Encoding utf8
Copy-Item -LiteralPath (Join-Path $shaderRoot 'psx.frag.glsl') -Destination $generated -Force
$fontHeader = Join-Path $projectDirectory 'vendor/psyz/external/SDL/src/render/SDL_render_debug_font.h'
$font = Get-Content -LiteralPath $fontHeader -Raw
$fontArray = [regex]::Match($font, '(?s)SDL_RenderDebugTextFontData\[\]\s*=\s*\{(.*?)\};').Groups[1].Value
$fontArray = [regex]::Replace($fontArray, '(?s)/\*.*?\*/|//[^\r\n]*', '')
$fontBytes = [byte[]]@([regex]::Matches($fontArray, '0x[0-9a-fA-F]{2}') | ForEach-Object { [Convert]::ToByte($_.Value.Substring(2), 16) })
if ($fontBytes.Length -ne 190 * 8) { throw 'Pinned SDL debug font changed; review the Legacy overlay adapter.' }
[IO.File]::WriteAllBytes((Join-Path $generated 'legacy-debug-font.bin'), $fontBytes)
Copy-Item -LiteralPath $fontHeader -Destination $generated -Force
Write-Host "[godot] Prepared $reportedVersion and pinned Psyz shaders."
