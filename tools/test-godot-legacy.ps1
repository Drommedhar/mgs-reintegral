[CmdletBinding()]
param(
    [string]$ReferenceFixture = 'build/legacy-parity-reference/fixture.exe',
    [string]$NativeFixture = 'build/windows-x86-godot/mgs_legacy_parity_fixture.exe',
    [string]$LogDirectory = ('build/godot-legacy-tests/' + [Guid]::NewGuid().ToString('N')),
    [ValidateRange(320,2560)][int]$Width = 1280,
    [ValidateRange(240,1920)][int]$Height = 720,
    [ValidateSet(0,1)][int]$Wide = 1,
    [switch]$Fullscreen
)
$ErrorActionPreference='Stop'
$repo = Split-Path $PSScriptRoot -Parent
$Scale = [Math]::Clamp([int][Math]::Ceiling([Math]::Max($Width / 320.0, $Height / $(if ($Wide) { 224.0 } else { 240.0 }))), 1, 8)
$logs=[IO.Path]::GetFullPath($LogDirectory, $repo)
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$reference=Start-Process -FilePath ([IO.Path]::GetFullPath($ReferenceFixture, $repo)) -ArgumentList @($Width,$Height,$Wide,0,$Scale,"$logs/reference") -Environment @{SDL_VIDEODRIVER='offscreen'; MGS_GODOT_PORT=''} -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/reference.log" -RedirectStandardError "$logs/reference.err"
try {
 if (-not $reference.WaitForExit(30000) -or $reference.ExitCode -ne 0) { throw 'Reference fixture failed' }
} finally {
 if (-not $reference.HasExited) { $reference.Kill($true) }
 $reference.Dispose()
}
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
$listener.Start()
$port=$listener.LocalEndpoint.Port.ToString()
$listener.Stop()
$token=[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16)).ToLowerInvariant()
$ready="$logs/ready-$([Guid]::NewGuid().ToString('N'))"
$environment=@{MGS_GODOT_PORT=$port; MGS_GODOT_SESSION_TOKEN=$token; MGS_GODOT_SCENE_VIEW='0'; MGS_PRESENTATION_MINOR='31'}
$rendererEnvironment=@{}
foreach($key in $environment.Keys) {$rendererEnvironment[$key]=$environment[$key]}
$rendererEnvironment['MGS_GODOT_READY_FILE']=$ready
$rendererEnvironment['MGS_GODOT_RENDER_SIZE']="${Width}x${Height}"
$rendererEnvironment['MGS_GODOT_WIDESCREEN']="$Wide"
$rendererEnvironment['MGS_GODOT_CAPTURE_FRAME']='1'
$rendererEnvironment['MGS_GODOT_DIAGNOSTIC_CAPTURE']='1'
$rendererEnvironment['MGS_GODOT_PERFORMANCE_RUN']='0'
$rendererEnvironment['MGS_GODOT_CAPTURE_FILE']="$logs/godot-output.png"
$rendererEnvironment['MGS_GODOT_CAPTURE_EVERY']='0'
$rendererEnvironment['MGS_GODOT_QUIT_FRAME']='0'
$rendererEnvironment['MGS_SETTINGS_PORT']=''
$renderer=Start-Process -FilePath "$repo/.tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe" -ArgumentList @('--path',"$repo/renderers/godot/project",$(if ($Fullscreen) { '--fullscreen' } else { '--borderless' }),'--position','0,0','--resolution',"${Width}x${Height}") -Environment $rendererEnvironment -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/godot.log" -RedirectStandardError "$logs/godot.err"
$native=$null
try {
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 while (-not (Test-Path -LiteralPath $ready)) {
  if ($renderer.HasExited -or [DateTime]::UtcNow -gt $deadline) {throw 'Godot fixture startup failed'}
  Start-Sleep -Milliseconds 50
 }
 $native=Start-Process -FilePath ([IO.Path]::GetFullPath($NativeFixture, $repo)) -ArgumentList @($Width,$Height,$Wide,1,$Scale,"$logs/godot") -Environment $environment -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/native.log" -RedirectStandardError "$logs/native.err"
 if (-not $native.WaitForExit(30000) -or $native.ExitCode -ne 0) {throw 'Remote fixture failed'}
 if (-not $renderer.WaitForExit(10000) -or $renderer.ExitCode -ne 0) {throw 'Godot fixture shutdown failed'}
 if (Select-String -Path "$logs/godot.log","$logs/godot.err" -Pattern '^(SCRIPT ERROR:|ERROR:|WARNING:.*leaked)' -Quiet) {throw 'Godot renderer errors'}
 "Captured pair in $logs"
} finally {
 foreach($process in @($native,$renderer)) {
  if ($process) {
   if (-not $process.HasExited) {$process.Kill($true)}
   $process.Dispose()
  }
 }
}


& (Join-Path $repo '.venv/Scripts/python.exe') (Join-Path $repo 'tests/compare_legacy_captures.py') $logs
if ($LASTEXITCODE -ne 0) { throw "Legacy parity mismatch: $logs" }
