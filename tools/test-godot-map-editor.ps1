[CmdletBinding()]
param(
    [string]$LogDirectory = 'build/godot-sdk-m0',
    [ValidateSet('map_composition', 'mod_profile', 'startup')][string]$Fixture = 'map_composition'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$logs = [IO.Path]::GetFullPath($LogDirectory, $repository)
$staging = Join-Path $logs ('map-editor-' + [Guid]::NewGuid().ToString('N'))
@'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[2]) / 'tools'))
from package_godot_sdk import Package, copy_project
copy_project(Package(Path(sys.argv[1])))
'@ | & (Join-Path $repository '.venv/Scripts/python.exe') - $staging $repository
if ($LASTEXITCODE -ne 0) { throw 'Cannot stage isolated editor project.' }
$project = Join-Path $staging 'renderers/godot/project'
New-Item -ItemType Directory -Path (Join-Path $staging '.local') | Out-Null
foreach ($disc in @('godot-content', 'godot-content-disc2')) {
    New-Item -ItemType Junction -Path (Join-Path $staging ".local/$disc") -Target (Join-Path $repository ".local/$disc") | Out-Null
}
if ($Fixture -eq 'mod_profile') {
    foreach ($directory in @('.tools', '.venv', 'build/windows-x86-godot', '.local/content')) {
        $target = Join-Path $staging $directory
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        New-Item -ItemType Junction -Path $target -Target (Join-Path $repository $directory) | Out-Null
    }
    $shaders = 'vendor/psyz/psyz/src/platform/shaders'
    New-Item -ItemType Directory -Path (Join-Path $staging $shaders) -Force | Out-Null
    foreach ($shader in @('psx.vert.glsl', 'psx.frag.glsl')) {
        Copy-Item -LiteralPath (Join-Path $repository "$shaders/$shader") -Destination (Join-Path $staging "$shaders/$shader")
    }
    $font = 'vendor/psyz/external/SDL/src/render/SDL_render_debug_font.h'
    New-Item -ItemType Directory -Path (Split-Path (Join-Path $staging $font) -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository $font) -Destination (Join-Path $staging $font)
    New-Item -ItemType Directory -Path (Join-Path $project 'tests') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository 'renderers/godot/project/tests/map_composition_editor_test.gd') -Destination (Join-Path $project 'tests/map_composition_editor_test.gd')
}
$probe = Join-Path $project 'addons/composition-test'
New-Item -ItemType Directory -Path $probe | Out-Null
Copy-Item -LiteralPath (Join-Path $repository "renderers/godot/project/tests/${Fixture}_editor_test.gd") -Destination (Join-Path $probe 'test.gd')
@'
[plugin]
name="Map composition validation"
description="Exercise inherited map creation and export in an isolated editor."
author="RE:INTEGRAL"
version="1.0"
script="test.gd"
'@ | Set-Content -LiteralPath (Join-Path $probe 'plugin.cfg') -Encoding utf8NoBOM
$configPath = Join-Path $project 'project.godot'
$config = [IO.File]::ReadAllText($configPath).Replace('enabled=PackedStringArray("res://addons/mgs_editor/plugin.cfg")',
    'enabled=PackedStringArray("res://addons/mgs_editor/plugin.cfg", "res://addons/composition-test/plugin.cfg")')
[IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))
$stdout = Join-Path $logs 'composition-editor.log'
$stderr = Join-Path $logs 'composition-editor.err'
$engine = Join-Path $repository '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
$process = Start-Process -FilePath $engine -ArgumentList @('--editor', '--rendering-driver', 'vulkan', '--path', "`"$project`"") `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try {
    if (-not $process.WaitForExit(240000)) { throw "Map editor test timed out. See $logs" }
    $errors = @(Get-Content -LiteralPath $stdout,$stderr | Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING:.*leaked)' })
    if ($process.ExitCode -ne 0 -or $errors.Count -gt 0 -or
        -not (Select-String -LiteralPath $stdout -Pattern "^MGS_$($Fixture.ToUpperInvariant())_EDITOR_TEST failures=0$" -Quiet)) {
        throw "Map editor test failed. See $stdout and $stderr"
    }
    Get-Content -LiteralPath $stdout | Select-String 'TEST failures='
}
finally {
    if (-not $process.HasExited) { $process.Kill($true) }
    $process.Dispose()
}
