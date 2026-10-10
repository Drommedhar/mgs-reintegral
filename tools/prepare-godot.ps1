[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$version = '4.8-dev7'
$archiveHash = '560a08a239421b89e6c7532930bc78714fda12ef5cf10bc9586531c7c1a64ac2'
$toolDirectory = Join-Path $projectDirectory ".tools/godot-$version"
$executable = Join-Path $toolDirectory "Godot_v${version}_win64_console.exe"
if (-not (Test-Path -LiteralPath $executable)) {
    $archive = Join-Path $projectDirectory ".tools/Godot_v${version}_win64.exe.zip"
    New-Item -ItemType Directory -Path (Split-Path $archive -Parent) -Force | Out-Null
    if (-not (Test-Path -LiteralPath $archive)) {
        Invoke-WebRequest -Uri "https://github.com/godotengine/godot-builds/releases/download/$version/Godot_v${version}_win64.exe.zip" -OutFile $archive
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $archiveHash) {
        throw "Godot archive hash mismatch: $archive"
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $toolDirectory -Force
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
Write-Host "[godot] Prepared $reportedVersion and pinned Psyz shaders."
