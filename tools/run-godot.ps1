[CmdletBinding()]
param(
    [ValidateSet('title', 's00a', 's01a')]
    [string]$Stage = 'title',
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
    [switch]$Scene3D,
    [string[]]$Mods = @(),
    [switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $projectDirectory '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
$rendererProject = Join-Path $projectDirectory 'renderers/godot/project'
$buildDirectory = Join-Path $projectDirectory 'build/windows-x86-godot'
if (-not (Test-Path -LiteralPath $godot)) {
    throw 'Run tools/prepare-godot.ps1 to install the pinned Godot build first.'
}
if ($Build -or -not (Test-Path -LiteralPath (Join-Path $buildDirectory 'mgs-integral-native.exe'))) {
    & (Join-Path $PSScriptRoot 'build.ps1') -BuildDirectory $buildDirectory `
        -RendererModule (Join-Path $projectDirectory 'renderers/godot/native') -Target mgs-integral-native
}
& (Join-Path $PSScriptRoot 'prepare-godot.ps1')
$runId = [Guid]::NewGuid().ToString('N')
$logRoot = Join-Path $projectDirectory "build/godot-runs/$runId"
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$readyFile = Join-Path $logRoot 'ready'
$previousPort = $env:MGS_GODOT_PORT
$previousReady = $env:MGS_GODOT_READY_FILE
$previousAssets = $env:MGS_GODOT_ASSETS
$previousScene = $env:MGS_GODOT_SCENE_VIEW
$previousMods = $env:MGS_GODOT_MODS
$env:MGS_GODOT_MODS = ConvertTo-Json -InputObject @($Mods | ForEach-Object { (Resolve-Path -LiteralPath $_).Path.Replace('\', '/') }) -Compress
$env:MGS_GODOT_ASSETS = if ($Scene3D) { Join-Path $projectDirectory '.local/godot-content' } else { '' }
$env:MGS_GODOT_SCENE_VIEW = ([int][bool]$Scene3D).ToString()
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$env:MGS_GODOT_PORT = $listener.LocalEndpoint.Port.ToString()
$listener.Stop()
$env:MGS_GODOT_READY_FILE = $readyFile
$renderer = $null
try {
    $renderer = Start-Process -FilePath $godot -ArgumentList @(
        '--path', "`"$rendererProject`"", '--rendering-driver', 'vulkan'
    ) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logRoot 'godot.log') `
        -RedirectStandardError (Join-Path $logRoot 'godot.err')
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $readyFile)) {
        if ($renderer.HasExited -or [DateTime]::UtcNow -gt $deadline) {
            throw "Godot renderer failed to start. See $logRoot"
        }
        Start-Sleep -Milliseconds 100
    }
    Write-Host "[godot] Renderer logs: $logRoot"
    $nativeArguments = @{ BuildDirectory = $buildDirectory; Frames = $Frames; Resolution = '320x240'
        RuntimeDirectory = (Join-Path $projectDirectory '.local/godot-runtime'); DebugOverlay = $false }
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
    $env:MGS_GODOT_PORT = $previousPort
    $env:MGS_GODOT_READY_FILE = $previousReady
    $env:MGS_GODOT_ASSETS = $previousAssets
    $env:MGS_GODOT_SCENE_VIEW = $previousScene
    $env:MGS_GODOT_MODS = $previousMods
}
