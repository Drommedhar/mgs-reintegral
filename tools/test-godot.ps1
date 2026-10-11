[CmdletBinding()]
param([switch]$SkipGpu, [switch]$SkipNativeMod)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $projectDirectory '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
$python = Join-Path $projectDirectory '.venv/Scripts/python.exe'
$rendererProject = Join-Path $projectDirectory 'renderers/godot/project'
$logRoot = Join-Path $projectDirectory ('build/godot-tests/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
& (Join-Path $PSScriptRoot 'prepare-godot.ps1')

function Test-GodotScript {
    param([string]$Name, [switch]$Gpu)
    $arguments = @('--path', "`"$rendererProject`"", '--script', "res://tests/$Name.gd")
    if (-not $Gpu) { $arguments += '--headless' }
    $log = Join-Path $logRoot "$Name.log"
    $errorLog = Join-Path $logRoot "$Name.err"
    $process = Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError $errorLog
    try {
        if (-not $process.WaitForExit(30000)) { throw "Godot test timed out: $Name. See $logRoot" }
        $findings = @(Get-Content -LiteralPath $log, $errorLog | Where-Object { $_ -match '^(SCRIPT ERROR:|ERROR:|WARNING:.*leaked)' })
        if ($process.ExitCode -ne 0 -or $findings.Count -gt 0) {
            Get-Content -LiteralPath $log, $errorLog
            throw "Godot test failed: $Name. See $logRoot"
        }
    }
    finally {
        if (-not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
    Get-Content -LiteralPath $log | Select-String 'PASS:|TEST failures='
}

Test-GodotScript 'scene_snapshot_test'
Test-GodotScript 'aspect_ratio_test'
Test-GodotScript 'mod_contract_test'
Test-GodotScript 'map_overlay_test'
Test-GodotScript 'disc_map_test'
Test-GodotScript 'map_coordinates_test'
Test-GodotScript 'map_session_test'
Test-GodotScript 'asset_authoring_test'
if (-not $SkipNativeMod) {
    & (Join-Path $PSScriptRoot 'build-godot-mod.ps1')
    Test-GodotScript 'extension_test'
}
Push-Location $projectDirectory
try {
    & $python -m unittest tests.test_godot_assets tests.test_godot_maps tests.test_godot_mod_import -v
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset conversion tests failed.' }
}
finally { Pop-Location }
if ($SkipGpu) {
    Write-Host "[godot] CPU tests passed; GPU tests skipped. Logs: $logRoot"
    return
}
Test-GodotScript 'depth_composition_test' -Gpu
Test-GodotScript 'resolution_test' -Gpu
Test-GodotScript 'pbr_lighting_test' -Gpu
Test-GodotScript 'character_shadow_test' -Gpu
Test-GodotScript 'event_lights_test' -Gpu
Test-GodotScript 'alarm_glass_test' -Gpu
Test-GodotScript 'global_illumination_test' -Gpu
Test-GodotScript 'world_effects_test' -Gpu
& $python (Join-Path $projectDirectory 'tests/godot_geometry_fixture.py') (Join-Path $rendererProject '.generated/lighting-test')
if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare the imported geometry lighting fixture.' }
Test-GodotScript 'imported_lighting_test' -Gpu

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$readyFile = Join-Path $logRoot 'ready'
$renderer = Start-Process -FilePath $godot -ArgumentList @('--path', "`"$rendererProject`"") `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'protocol.log') `
    -RedirectStandardError (Join-Path $logRoot 'protocol.err') -Environment @{
        MGS_GODOT_PORT = $port.ToString(); MGS_GODOT_READY_FILE = $readyFile
        MGS_GODOT_SCENE_VIEW = '0'; MGS_GODOT_CAPTURE_FRAME = '0'; MGS_GODOT_CAPTURE_EVERY = '0'
        MGS_GODOT_QUIT_FRAME = '0'
    }
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $readyFile)) {
        if ($renderer.HasExited -or [DateTime]::UtcNow -gt $deadline) {
            throw "Godot protocol server failed to start. See $logRoot"
        }
        Start-Sleep -Milliseconds 100
    }
    & $python (Join-Path $projectDirectory 'tests/test_godot_protocol.py') --port $port
    if ($LASTEXITCODE -ne 0) { throw "Godot protocol test failed. See $logRoot" }
    if (-not $renderer.WaitForExit(5000) -or $renderer.ExitCode -ne 0) {
        throw "Godot protocol server did not exit normally. See $logRoot"
    }
    if (Select-String -LiteralPath (Join-Path $logRoot 'protocol.err') -Pattern '^(SCRIPT ERROR:|ERROR:|WARNING:.*leaked)' -Quiet) {
        throw "Godot protocol server reported an error. See $logRoot"
    }
}
finally {
    if (-not $renderer.HasExited) { $renderer.Kill($true) }
    $renderer.Dispose()
}
Write-Host "[godot] CPU and GPU tests passed. Logs: $logRoot"
