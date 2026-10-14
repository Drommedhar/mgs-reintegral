[CmdletBinding()]
param([string]$BuildDirectory = 'build/windows-x86-godot')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot $BuildDirectory
$fixture = Join-Path $buildRoot 'settings-host.exe'
$godotExe = Join-Path $projectRoot '.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe'
$rendererRoot = Join-Path $projectRoot 'renderers/godot/project'
$logs = Join-Path $projectRoot ('build/settings-tests/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$hostProcess = $null
$clientProcess = $null
$previousToken = $env:MGS_GODOT_SESSION_TOKEN
$env:MGS_GODOT_SESSION_TOKEN = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16)).ToLowerInvariant()
$settingsPath = Join-Path $logs 'settings.xml'
$readyPath = Join-Path $logs 'ready.json'
$stopPath = Join-Path $logs 'stop'
[IO.File]::WriteAllText($settingsPath, '<Settings><Version>1</Version><Resolution>1280x720</Resolution><Widescreen>true</Widescreen><Fullscreen>false</Fullscreen><Mods><VisualMod><Id>keep.me</Id><Enabled>false</Enabled><Package>custom.zip</Package></VisualMod></Mods></Settings>')
try {
    $hostArguments = @("`"$settingsPath`"", "`"$readyPath`"", "`"$stopPath`"", 'saved', 'saved', 'saved')
    $hostProcess = Start-Process -FilePath $fixture -ArgumentList $hostArguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $logs 'host.log') -RedirectStandardError (Join-Path $logs 'host.err')
    $deadline = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath (Join-Path $logs 'ready.json'))) {
        if ($hostProcess.HasExited -or $deadline.Elapsed.TotalSeconds -gt 10) { throw "Settings fixture did not start: $logs" }
        Start-Sleep -Milliseconds 50
    }
    $clientProcess = Start-Process -FilePath $godotExe -ArgumentList @('--headless','--path',"`"$rendererRoot`"",'--script','res://tests/settings_client_test.gd','--',"`"$logs`"") -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $logs 'client.log') -RedirectStandardError (Join-Path $logs 'client.err')
    if (-not $clientProcess.WaitForExit(30000)) { throw "Settings client timed out: $logs" }
    if ($clientProcess.ExitCode -ne 0 -or (Select-String -Path (Join-Path $logs 'client.err') -Pattern 'ERROR:|leaked')) {
        Get-Content (Join-Path $logs 'client.log'), (Join-Path $logs 'client.err')
        throw "Settings client failed: $logs"
    }
    New-Item -ItemType File -Path (Join-Path $logs 'stop') | Out-Null
    if (-not $hostProcess.WaitForExit(5000) -or $hostProcess.ExitCode -ne 0) { throw "Settings host failed: $logs" }
    Get-Content (Join-Path $logs 'client.log')
    $hostProcess.Dispose()
    $hostProcess = $null
    $restartReady = Join-Path $logs 'restart-ready.json'
    $hostArguments[1] = "`"$restartReady`""
    $hostProcess = Start-Process -FilePath $fixture -ArgumentList $hostArguments -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $logs 'restart.log') -RedirectStandardError (Join-Path $logs 'restart.err')
    if (-not $hostProcess.WaitForExit(5000) -or $hostProcess.ExitCode -ne 0) { throw "Settings reload failed: $logs" }
    $restarted = Get-Content -LiteralPath $restartReady -Raw | ConvertFrom-Json
    if ($restarted.launch.'display.resolution' -ne '1920x1080' -or -not $restarted.launch.'display.fullscreen') { throw 'Next launch did not use saved display values.' }
    Write-Host "Settings bridge passed. Logs: $logs"
} finally {
    foreach ($process in @($clientProcess,$hostProcess)) {
        if ($null -ne $process) {
            if (-not $process.HasExited) { $process.Kill() }
            $process.Dispose()
        }
    }
    $env:MGS_GODOT_SESSION_TOKEN = $previousToken
}
