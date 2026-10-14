[CmdletBinding()]
param([switch]$SkipGpu, [switch]$SkipNativeMod, [switch]$NativeEditorSession)

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
    param([string]$Name, [switch]$Gpu, [switch]$Fsr2, [int]$TimeoutSeconds = 30)
    $arguments = @('--path', "`"$rendererProject`"", '--script', "res://tests/$Name.gd")
    if (-not $Gpu) { $arguments += '--headless' }
    if ($Fsr2) { $arguments += @('--', '--fsr2') }
    $logName = if ($Fsr2) { "$Name-fsr2" } else { $Name }
    $log = Join-Path $logRoot "$logName.log"
    $errorLog = Join-Path $logRoot "$logName.err"
    $process = Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError $errorLog
    try {
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) { throw "Godot test timed out: $Name. See $logRoot" }
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
Test-GodotScript 'scene_preparation_test'
Test-GodotScript 'scene_resources_test'
Test-GodotScript 'session_gate_test'
Test-GodotScript 'native_context_test'
Test-GodotScript 'retained_palettes_test'
Test-GodotScript 'prepared_catalog_test'
Test-GodotScript 'original_ui_test'
Test-GodotScript 'kcb_font_test'
Test-GodotScript 'goggles_ui_test'
Test-GodotScript 'bars_ui_test'
Test-GodotScript 'subtitles_ui_test'
Test-GodotScript 'radar_ui_test'
Test-GodotScript 'inventory_ui_test'
Test-GodotScript 'codec_ui_test'
Test-GodotScript 'title_ui_test'
Test-GodotScript 'options_ui_test'
Test-GodotScript 'options_actions_test'
Test-GodotScript 'title_actions_test'
Test-GodotScript 'menu_input_test'
Test-GodotScript 'save_ui_test'
Test-GodotScript 'save_actions_test'
Test-GodotScript 'display_settings_test'
Test-GodotScript 'display_menu_test'
& (Join-Path $PSScriptRoot 'test-settings-bridge.ps1')
Test-GodotScript 'model_sources_test'
Test-GodotScript 'native_actors_test'
Test-GodotScript 'native_binding_workflow_test'
Test-GodotScript 'aspect_ratio_test'
Test-GodotScript 'mod_contract_test'
Test-GodotScript 'map_overlay_test'
Test-GodotScript 'map_composition_test'
Test-GodotScript 'map_additions_test'
Test-GodotScript 'mod_profile_test'
& (Join-Path $PSScriptRoot 'test-godot-map-editor.ps1') -LogDirectory $logRoot
& (Join-Path $PSScriptRoot 'test-godot-map-editor.ps1') -LogDirectory (Join-Path $logRoot 'startup') -Fixture startup
Test-GodotScript 'disc_map_test'
Test-GodotScript 'scene_catalog_test' -TimeoutSeconds 90
Test-GodotScript 'disc_content_test'
Test-GodotScript 'catalog_responsiveness_test' -TimeoutSeconds 120
Test-GodotScript 'scene_browser_test'
Test-GodotScript 'workspace_roundtrip_test'
Test-GodotScript 'binary_export_test'
Test-GodotScript 'source_dependency_test'
Test-GodotScript 'mod_resources_test' -TimeoutSeconds 90
& (Join-Path $PSScriptRoot 'test-godot-resource-editor.ps1') -LogDirectory $logRoot
Test-GodotScript 'export_provenance_test'
Test-GodotScript 'original_resource_export_test' -TimeoutSeconds 90
Test-GodotScript 'cinematic_preview_test'
Test-GodotScript 'camera_cuts_test'
Test-GodotScript 'presentation_camera_test'
Test-GodotScript 'native_camera_timeline_test'
Test-GodotScript 'effect_materials_test'
Test-GodotScript 'object_appearance_test'
Test-GodotScript 'night_vision_test'
Test-GodotScript 'thermal_vision_test'
Test-GodotScript 'map_coordinates_test'
Test-GodotScript 'map_session_test'
Test-GodotScript 'asset_authoring_test'
if ($NativeEditorSession) {
    Test-GodotScript 'native_test_session_test' -TimeoutSeconds 90
    & (Join-Path $PSScriptRoot 'test-godot-map-editor.ps1') -LogDirectory (Join-Path $logRoot 'profile') -Fixture mod_profile
}
if (-not $SkipNativeMod) {
    & (Join-Path $PSScriptRoot 'build-godot-mod.ps1')
    Test-GodotScript 'extension_test'
}
Push-Location $projectDirectory
try {
    & $python -m unittest tests.test_godot_assets tests.test_godot_provenance tests.test_godot_maps tests.test_godot_mod_import tests.test_godot_mod_fork tests.test_godot_mod_dependencies -v
    if ($LASTEXITCODE -ne 0) { throw 'Godot asset conversion tests failed.' }
}
finally { Pop-Location }
if ($SkipGpu) {
    Write-Host "[godot] CPU tests passed; GPU tests skipped. Logs: $logRoot"
    return
}
Test-GodotScript 'depth_composition_test' -Gpu
Test-GodotScript 'beam_render_test' -Gpu
Test-GodotScript 'beam_render_test' -Gpu -Fsr2
Test-GodotScript 'original_ui_render_test' -Gpu
Test-GodotScript 'original_ui_render_test' -Gpu -Fsr2
Test-GodotScript 'kcb_font_render_test' -Gpu
Test-GodotScript 'kcb_font_render_test' -Gpu -Fsr2
Test-GodotScript 'goggles_ui_render_test' -Gpu
Test-GodotScript 'goggles_ui_render_test' -Gpu -Fsr2
$subtitleReference = Join-Path $projectDirectory 'build/windows-x86-godot/mgs_text_layout_test.exe'
if (-not (Test-Path -LiteralPath $subtitleReference)) { throw 'Build the mgs_text_layout_test target before subtitle GPU checks.' }
$subtitleFixtures = Join-Path $rendererProject '.generated/subtitles-native-fixtures'
New-Item -ItemType Directory -Path $subtitleFixtures -Force | Out-Null
& $subtitleReference $subtitleFixtures
if ($LASTEXITCODE -ne 0) { throw 'Native subtitle reference failed.' }
Test-GodotScript 'subtitles_render_test' -Gpu
Test-GodotScript 'subtitles_render_test' -Gpu -Fsr2
Test-GodotScript 'bars_ui_render_test' -Gpu
Test-GodotScript 'bars_ui_render_test' -Gpu -Fsr2
Test-GodotScript 'radar_render_test' -Gpu
Test-GodotScript 'inventory_render_test' -Gpu
Test-GodotScript 'codec_render_test' -Gpu
Test-GodotScript 'title_render_test' -Gpu
Test-GodotScript 'options_render_test' -Gpu
Test-GodotScript 'save_ui_test' -Gpu
Test-GodotScript 'inventory_render_test' -Gpu -Fsr2
Test-GodotScript 'radar_render_test' -Gpu -Fsr2
Test-GodotScript 'depth_composition_test' -Gpu -Fsr2
Test-GodotScript 'resolution_test' -Gpu
Test-GodotScript 'display_buffers_test' -Gpu
Test-GodotScript 'resolution_test' -Gpu -Fsr2
Test-GodotScript 'pbr_lighting_test' -Gpu
Test-GodotScript 'texture_stability_test' -Gpu
Test-GodotScript 'character_shadow_test' -Gpu
Test-GodotScript 'event_lights_test' -Gpu
Test-GodotScript 'alarm_glass_test' -Gpu
Test-GodotScript 'global_illumination_test' -Gpu
Test-GodotScript 'camera_history_test' -Gpu
Test-GodotScript 'world_effects_test' -Gpu
Test-GodotScript 'camouflage_render_test' -Gpu
Test-GodotScript 'camouflage_render_test' -Gpu -Fsr2
Test-GodotScript 'night_vision_render_test' -Gpu
Test-GodotScript 'night_vision_render_test' -Gpu -Fsr2
Test-GodotScript 'thermal_vision_render_test' -Gpu
Test-GodotScript 'legacy_runtime_test' -Gpu
Test-GodotScript 'native_visibility_test' -Gpu
Test-GodotScript 'thermal_vision_render_test' -Gpu -Fsr2
& $python (Join-Path $projectDirectory 'tests/godot_geometry_fixture.py') (Join-Path $rendererProject '.generated/lighting-test')
if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare the imported geometry lighting fixture.' }
Test-GodotScript 'imported_lighting_test' -Gpu

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$readyFile = Join-Path $logRoot 'ready'
$sessionToken = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16)).ToLowerInvariant()
$renderer = Start-Process -FilePath $godot -ArgumentList @('--path', "`"$rendererProject`"") `
    -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'protocol.log') `
    -RedirectStandardError (Join-Path $logRoot 'protocol.err') -Environment @{
        MGS_GODOT_PORT = $port.ToString(); MGS_GODOT_READY_FILE = $readyFile
        MGS_GODOT_SESSION_TOKEN = $sessionToken
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
    $previousToken = $env:MGS_GODOT_SESSION_TOKEN
    try {
        $env:MGS_GODOT_SESSION_TOKEN = $sessionToken
        & $python (Join-Path $projectDirectory 'tests/test_godot_protocol.py') --port $port
    }
    finally { $env:MGS_GODOT_SESSION_TOKEN = $previousToken }
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
