[CmdletBinding()]
param(
    [ValidatePattern('^[a-z][a-z0-9_]*$')]
    [string]$Stage = 'title',
    [ValidateSet(1, 2)][int]$StartDisc = 1,
    [ValidateRange(0, 2147483647)]
    [int]$Frames = 0,
    [string]$Probe,
    [string]$Capture,
    [int]$CaptureEvery,
    [string]$RecordInput,
    [string]$ReplayInput,
    [string]$LoadCheckpoint,
    [switch]$BonusItems,
    [switch]$Invulnerable,
    [switch]$DebugOverlay,
    [switch]$Scene3D,
    [string[]]$Mods = @(),
    [string]$ModProfile,
    [string]$RuntimeDirectory,
    [string]$LogDirectory,
    [ValidatePattern('^[0-9]+x[0-9]+$')]
    [string]$Resolution = '1280x960',
    [switch]$Widescreen,
    [switch]$Fullscreen,
    [switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $projectDirectory '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
$rendererProject = Join-Path $projectDirectory 'renderers/godot/project'
$buildDirectory = Join-Path $projectDirectory 'build/windows-x86-godot'
if (Test-Path -LiteralPath (Join-Path $projectDirectory 'sdk.json')) {
    if ($Build) { throw 'This SDK contains prebuilt native hosts. Rebuild gameplay in the source checkout.' }
    foreach ($file in @('mgs-integral-native.exe', 'settings-host.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $buildDirectory $file))) { throw "SDK is missing $file. Extract a fresh SDK." }
    }
}
if (-not (Test-Path -LiteralPath $godot)) {
    throw 'Run tools/prepare-godot.ps1 to install the pinned Godot build first.'
}
if ($Build -or -not (Test-Path -LiteralPath (Join-Path $buildDirectory 'mgs-integral-native.exe'))) {
    & (Join-Path $PSScriptRoot 'build.ps1') -BuildDirectory $buildDirectory `
        -RendererModule (Join-Path $projectDirectory 'renderers/godot/native') -Target mgs-integral-native
}
$settingsHost = Join-Path $buildDirectory 'settings-host.exe'
if ($Build -or -not (Test-Path -LiteralPath $settingsHost)) {
    & (Join-Path $PSScriptRoot 'build.ps1') -BuildDirectory $buildDirectory `
        -RendererModule (Join-Path $projectDirectory 'renderers/godot/native') -Target reintegral_settings_host
}
& (Join-Path $PSScriptRoot 'prepare-godot.ps1')
$runId = [Guid]::NewGuid().ToString('N')
$logRoot = if ($LogDirectory) { [IO.Path]::GetFullPath($LogDirectory, $projectDirectory) } else { Join-Path $projectDirectory "build/godot-runs/$runId" }
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$readyFile = Join-Path $logRoot "ready-$runId"
$previousPort = $env:MGS_GODOT_PORT
$previousToken = $env:MGS_GODOT_SESSION_TOKEN
$previousReady = $env:MGS_GODOT_READY_FILE
$previousAssets = $env:MGS_GODOT_ASSETS
$previousScene = $env:MGS_GODOT_SCENE_VIEW
$previousMods = $env:MGS_GODOT_MODS
$previousProfile = $env:MGS_GODOT_PROFILE
$previousRenderSize = $env:MGS_GODOT_RENDER_SIZE
$previousWidescreen = $env:MGS_GODOT_WIDESCREEN
$previousPresentationMinor = $env:MGS_PRESENTATION_MINOR
$previousSettingsPort = $env:MGS_SETTINGS_PORT
$previousPerformanceRun = $env:MGS_GODOT_PERFORMANCE_RUN
$previousDiagnosticCapture = $env:MGS_GODOT_DIAGNOSTIC_CAPTURE
$env:MGS_GODOT_PERFORMANCE_RUN = if ($Capture) { '0' } else { '1' }
$env:MGS_GODOT_DIAGNOSTIC_CAPTURE = '0'
$env:MGS_GODOT_RENDER_SIZE = $Resolution
$env:MGS_GODOT_MODS = ConvertTo-Json -InputObject @($Mods | ForEach-Object { (Resolve-Path -LiteralPath $_).Path.Replace('\', '/') }) -Compress
$env:MGS_GODOT_PROFILE = if ($ModProfile) { (Resolve-Path -LiteralPath $ModProfile).Path.Replace('\', '/') } else { '' }
$env:MGS_GODOT_ASSETS = if ($Scene3D) { Join-Path $projectDirectory '.local/godot-content' } else { '' }
$env:MGS_GODOT_SCENE_VIEW = ([int][bool]$Scene3D).ToString()
$env:MGS_PRESENTATION_MINOR = '35'
$env:MGS_GODOT_SESSION_TOKEN = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16)).ToLowerInvariant()
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$env:MGS_GODOT_PORT = $listener.LocalEndpoint.Port.ToString()
$listener.Stop()
$env:MGS_GODOT_READY_FILE = $readyFile
$renderer = $null
$settingsProcess = $null
$settingsReady = Join-Path $logRoot "settings-ready-$runId.json"
$settingsStop = Join-Path $logRoot "settings-stop-$runId"
try {
    $runtimeRoot = if ($RuntimeDirectory) { [IO.Path]::GetFullPath($RuntimeDirectory, $projectDirectory) } else { Join-Path $projectDirectory '.local/godot-runtime' }
    $resolutionArgument = if ($PSBoundParameters.ContainsKey('Resolution')) { $Resolution } else { 'saved' }
    $wideArgument = if ($PSBoundParameters.ContainsKey('Widescreen')) { ([int][bool]$Widescreen).ToString() } else { 'saved' }
    $fullArgument = if ($PSBoundParameters.ContainsKey('Fullscreen')) { ([int][bool]$Fullscreen).ToString() } else { 'saved' }
    $settingsProcess = Start-Process -FilePath $settingsHost -ArgumentList @(
        "`"$(Join-Path $runtimeRoot 'settings.xml')`"", "`"$settingsReady`"", "`"$settingsStop`"", $resolutionArgument, $wideArgument, $fullArgument
    ) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'settings.log') `
        -RedirectStandardError (Join-Path $logRoot 'settings.err')
    $settingsDeadline = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath $settingsReady)) {
        if ($settingsProcess.HasExited -or [DateTime]::UtcNow -gt $settingsDeadline) { throw "Settings provider failed to start. See $logRoot/settings.err" }
        Start-Sleep -Milliseconds 50
    }
    $settingsReadyData = Get-Content -LiteralPath $settingsReady -Raw | ConvertFrom-Json
    $env:MGS_SETTINGS_PORT = $settingsReadyData.port.ToString()
    $Resolution = $settingsReadyData.launch.'display.resolution'
    $Widescreen = [bool]$settingsReadyData.launch.'display.widescreen'
    $env:MGS_GODOT_RENDER_SIZE = $Resolution
    $env:MGS_GODOT_WIDESCREEN = ([int][bool]$Widescreen).ToString()
    $rendererArguments = @('--path', "`"$rendererProject`"", '--rendering-driver', 'vulkan', '--resolution', $Resolution)
    if ($settingsReadyData.launch.'display.fullscreen') { $rendererArguments += '--fullscreen' }
    $renderer = Start-Process -FilePath $godot -ArgumentList $rendererArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'godot.log') `
        -RedirectStandardError (Join-Path $logRoot 'godot.err')
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    while (-not (Test-Path -LiteralPath $readyFile)) {
        if ($renderer.HasExited -or [DateTime]::UtcNow -gt $deadline) {
            throw "Godot renderer failed to start. See $logRoot"
        }
        Start-Sleep -Milliseconds 100
    }
    Write-Host "[godot] Renderer logs: $logRoot"
    $nativeArguments = @{ BuildDirectory = $buildDirectory; Frames = $Frames; Resolution = $Resolution; Widescreen = [bool]$Widescreen
        RuntimeDirectory = $runtimeRoot; DebugOverlay = [bool]$DebugOverlay }
    $receiptPath = Join-Path $projectDirectory ".local/content/disc$StartDisc/manifest.json"
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    $nativeArguments.Disc = $receipt.cue.path
    if ($PSBoundParameters.ContainsKey('Stage')) { $nativeArguments.Stage = $Stage }
    foreach ($name in @('Probe', 'Capture', 'CaptureEvery', 'RecordInput', 'ReplayInput',
                        'LoadCheckpoint', 'BonusItems', 'Invulnerable')) {
        if ($PSBoundParameters.ContainsKey($name)) { $nativeArguments[$name] = $PSBoundParameters[$name] }
    }
    & (Join-Path $PSScriptRoot 'run.ps1') @nativeArguments
}
finally {
    if ($renderer -and -not $renderer.HasExited) {
        if (-not $renderer.WaitForExit(2000)) { $renderer.Kill() }
    }
    if ($renderer) { $renderer.Dispose() }
    if ($settingsProcess) {
        [IO.File]::WriteAllText($settingsStop, '')
        if (-not $settingsProcess.WaitForExit(5000)) { $settingsProcess.Kill() }
        $settingsProcess.Dispose()
    }
    $env:MGS_GODOT_PORT = $previousPort
    $env:MGS_GODOT_SESSION_TOKEN = $previousToken
    $env:MGS_GODOT_READY_FILE = $previousReady
    $env:MGS_GODOT_ASSETS = $previousAssets
    $env:MGS_GODOT_SCENE_VIEW = $previousScene
    $env:MGS_GODOT_MODS = $previousMods
    $env:MGS_GODOT_PROFILE = $previousProfile
    $env:MGS_GODOT_PERFORMANCE_RUN = $previousPerformanceRun
    $env:MGS_GODOT_DIAGNOSTIC_CAPTURE = $previousDiagnosticCapture
    $env:MGS_GODOT_RENDER_SIZE = $previousRenderSize
    $env:MGS_GODOT_WIDESCREEN = $previousWidescreen
    $env:MGS_PRESENTATION_MINOR = $previousPresentationMinor
    $env:MGS_SETTINGS_PORT = $previousSettingsPort
}
