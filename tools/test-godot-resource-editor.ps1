[CmdletBinding()]
param([string]$LogDirectory = 'build/godot-sdk-m0')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$logs = [IO.Path]::GetFullPath($LogDirectory, $repository)
$project = Join-Path $logs ('resource-editor-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $project -Force | Out-Null
foreach ($file in @('mod_registry.gd', 'mod_resources.gd',
    'addons/mgs_editor/mod_workspace.gd', 'addons/mgs_editor/mod_resources_editor.gd',
    'tests/mod_resources_editor_test.gd')) {
    $target = Join-Path $project $file
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository "renderers/godot/project/$file") -Destination $target
}
@'
config_version=5
[application]
config/name="Mod resource editor validation"
[editor_plugins]
enabled=PackedStringArray("res://addons/mgs_editor/plugin.cfg")
'@ | Set-Content -LiteralPath (Join-Path $project 'project.godot') -Encoding utf8NoBOM
@'
[plugin]
name="Mod resource editor validation"
description="Exercise registration controls in a separate editor project."
author="RE:INTEGRAL"
version="1.0"
script="../../tests/mod_resources_editor_test.gd"
'@ | Set-Content -LiteralPath (Join-Path $project 'addons/mgs_editor/plugin.cfg') -Encoding utf8NoBOM
$stdout = Join-Path $logs 'resources-editor.log'
$stderr = Join-Path $logs 'resources-editor.err'
$godot = Join-Path $repository '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
$process = Start-Process -FilePath $godot -ArgumentList @('--headless', '--editor', '--path', "`"$project`"") `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try {
    if (-not $process.WaitForExit(45000)) { throw "Resource editor test timed out. See $logs" }
    $errors = @(Get-Content -LiteralPath $stdout, $stderr | Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING:.*leaked)' })
    if ($process.ExitCode -ne 0 -or $errors.Count -gt 0 -or
        -not (Select-String -LiteralPath $stdout -Pattern '^MGS_MOD_RESOURCES_EDITOR_TEST failures=0$' -Quiet)) {
        throw "Resource editor test failed. See $stdout and $stderr"
    }
    Get-Content -LiteralPath $stdout | Select-String 'TEST failures='
}
finally {
    if (-not $process.HasExited) { $process.Kill($true) }
    $process.Dispose()
}
