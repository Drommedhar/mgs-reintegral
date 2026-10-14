[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SdkDirectory,
    [string]$LogDirectory = 'build/godot-sdk-m0',
    [ValidateSet('sdk', 'mod_profile')][string]$Fixture = 'sdk'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$sdk = [IO.Path]::GetFullPath($SdkDirectory)
$logs = [IO.Path]::GetFullPath($LogDirectory, $repository)
$project = Join-Path $sdk 'renderers/godot/project'
$godot = Join-Path $sdk '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
if (-not (Test-Path -LiteralPath (Join-Path $sdk 'sdk.json'))) { throw 'Select an extracted development SDK.' }
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$configPath = Join-Path $project 'project.godot'
$originalConfig = [IO.File]::ReadAllBytes($configPath)
$probe = Join-Path $project '.generated/sdk-proof'
New-Item -ItemType Directory -Path $probe -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repository "renderers/godot/project/tests/${Fixture}_editor_test.gd") -Destination (Join-Path $probe 'test.gd')
if ($Fixture -eq 'mod_profile') {
    New-Item -ItemType Directory -Path (Join-Path $project 'tests') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repository 'renderers/godot/project/tests/map_composition_editor_test.gd') -Destination (Join-Path $project 'tests/map_composition_editor_test.gd')
}
@'
[plugin]
name="SDK relocation validation"
description="Exercise the relocated editor and native workflow."
author="RE:INTEGRAL"
version="1.0"
script="test.gd"
'@ | Set-Content -LiteralPath (Join-Path $probe 'plugin.cfg') -Encoding utf8NoBOM
$process = $null
try {
    if ($Fixture -eq 'sdk') {
        & $godot --headless --path $project --script res://examples/named_resources/export_example.gd *> (Join-Path $logs 'sdk-example.log')
        if ($LASTEXITCODE -ne 0) { throw 'SDK example export failed.' }
    }
    $config = [Text.Encoding]::UTF8.GetString($originalConfig).Replace('enabled=PackedStringArray("res://addons/mgs_editor/plugin.cfg")',
        'enabled=PackedStringArray("res://addons/mgs_editor/plugin.cfg", "res://.generated/sdk-proof/plugin.cfg")')
    [IO.File]::WriteAllText($configPath, $config, [Text.UTF8Encoding]::new($false))
    $stdout = Join-Path $logs 'sdk-editor.log'
    $stderr = Join-Path $logs 'sdk-editor.err'
    $process = Start-Process -FilePath $godot -ArgumentList @('--editor', '--rendering-driver', 'vulkan', '--path', "`"$project`"") `
        -Environment @{PATH = "$env:SystemRoot\System32"; APPDATA = "$sdk/proof-profile/roaming"; LOCALAPPDATA = "$sdk/proof-profile/local"} `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(240000)) { throw "SDK editor proof timed out. See $logs" }
    $errors = @(Get-Content -LiteralPath $stdout, $stderr | Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING:.*leaked)' })
    if ($process.ExitCode -ne 0 -or $errors.Count -gt 0 -or -not (Select-String -LiteralPath $stdout -Pattern "^MGS_$($Fixture.ToUpperInvariant())_EDITOR_TEST failures=0(?: |$)" -Quiet)) {
        throw "SDK editor proof failed. See $logs"
    }
    Get-Content -LiteralPath $stdout | Select-String 'TEST failures='
}
finally {
    if ($process) {
        if (-not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
    [IO.File]::WriteAllBytes($configPath, $originalConfig)
}
