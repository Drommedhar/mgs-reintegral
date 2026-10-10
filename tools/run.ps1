[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release', 'RelWithDebInfo')]
    [string]$Configuration = 'Debug',
    [string]$Disc,
    [string]$DiscTwo,
    [string]$BuildDirectory,
    [string]$RuntimeDirectory,
    [switch]$Widescreen,
    [ValidatePattern('^[0-9]+x[0-9]+$')]
    [string]$Resolution,
    [switch]$Fullscreen,
    [switch]$DebugOverlay,
    [ValidatePattern('^[a-z][a-z0-9_]*$')]
    [string]$Stage = 'title',
    [ValidateRange(0, 65535)]
    [int]$StageMap,
    [string]$ModsRoot,
    [string]$Capture,
    [string]$CadenceLog,
    [string]$RecordInput,
    [string]$ReplayInput,
    [string]$ResumeInput,
    [string]$LoadCheckpoint,
    [string]$SaveCheckpoint,
    [switch]$ReplayFast,
    [ValidateRange(1, 3600)]
    [int]$ReplayTailFrames,
    [switch]$BonusItems,
    [switch]$Invulnerable,
    [switch]$AutoCard,
    [ValidatePattern('^(random|off|[1-9][0-9]{0,9})$')]
    [string]$MantisMemory = 'off',
    [ValidateRange(1, 2147483647)]
    [int]$CaptureEvery,
    [ValidateSet('dock', 'bonus', 'new-game', 'intro', 'dock-route', 'new-game-route', 'save-menu', 'load-menu', 'stage', 'disc-change', 'escape', 'briefing', 'ending', 'completed-load', 'escape-route', 'rex-fight', 'liquid-fight', 'garage-route', 'garage-escape')]
    [string]$Probe,
    [ValidateRange(0, 2147483647)]
    [int]$Frames = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'input-session.ps1')

if ($RecordInput -or $ReplayInput) {
    if (-not $PSBoundParameters.ContainsKey('DebugOverlay')) { $DebugOverlay = $true }
    if (-not $CadenceLog) {
        $CadenceLog = if ($RecordInput) { "$RecordInput.timing.csv" } else {
            "$ReplayInput.replay-$([Guid]::NewGuid().ToString('N')).timing.csv"
        }
    }
}

if ($PSBoundParameters.ContainsKey('Resolution')) {
    $dimensions = $Resolution.Split('x')
    $displayWidth = 0
    $displayHeight = 0
    if (-not [int]::TryParse($dimensions[0], [ref]$displayWidth) -or
        -not [int]::TryParse($dimensions[1], [ref]$displayHeight) -or
        $displayWidth -lt 320 -or $displayWidth -gt 7680 -or
        $displayHeight -lt 240 -or $displayHeight -gt 4320) {
        throw '-Resolution requires width 320..7680 and height 240..4320, formatted as WIDTHxHEIGHT.'
    }
}

function Get-MgsInputFileIdentity {
    param([string]$Path)

    if (-not ('MgsInputFileIdentity' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class MgsInputFileIdentity
{
    [StructLayout(LayoutKind.Sequential)]
    private struct FileInformation
    {
        public uint Attributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME Created;
        public System.Runtime.InteropServices.ComTypes.FILETIME Accessed;
        public System.Runtime.InteropServices.ComTypes.FILETIME Written;
        public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetFileInformationByHandle(
        SafeFileHandle handle, out FileInformation information);

    public static string Read(string path)
    {
        using (var file = new FileStream(path, FileMode.Open, FileAccess.Read,
                                        FileShare.ReadWrite | FileShare.Delete))
        {
            FileInformation information;
            if (!GetFileInformationByHandle(file.SafeFileHandle, out information))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            return String.Format("{0:x8}:{1:x8}{2:x8}", information.Volume,
                                 information.IndexHigh, information.IndexLow);
        }
    }
}
'@
    }
    return [MgsInputFileIdentity]::Read($Path)
}

function Assert-MgsInputOutputAliases {
    param([string]$Movie, [string[]]$Outputs)

    $identities = [Collections.Generic.HashSet[string]]::new()
    foreach ($outputPath in $Outputs) {
        Assert-MgsInputPlainPath $outputPath
        if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
            [void]$identities.Add((Get-MgsInputFileIdentity $outputPath))
        }
    }
    if (-not $identities.Count) {
        return
    }
    if ((Test-Path -LiteralPath $Movie -PathType Leaf) -and
        $identities.Contains((Get-MgsInputFileIdentity $Movie))) {
        throw "Input-session output aliases the movie: $Movie"
    }
    $session = "$Movie.session"
    Assert-MgsInputPlainPath $session
    $pending = [Collections.Generic.Stack[string]]::new()
    if (Test-Path -LiteralPath $session -PathType Container) {
        $pending.Push($session)
    }
    while ($pending.Count) {
        foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Input sessions do not follow reparse points: $($entry.FullName)"
            }
            if ($entry.PSIsContainer) {
                $pending.Push($entry.FullName)
            } elseif ($identities.Contains((Get-MgsInputFileIdentity $entry.FullName))) {
                throw "Input-session output aliases a protected file: $($entry.FullName)"
            }
        }
    }
}

function Assert-MgsInputOutputs {
    param([string]$MoviePath, [string[]]$OutputPaths)

    $movie = [IO.Path]::GetFullPath($MoviePath, $projectDirectory)
    $session = "$movie.session"
    $sessionPrefix = $session + [IO.Path]::DirectorySeparatorChar
    $outputs = @(
        foreach ($outputPath in $OutputPaths) {
            if (-not $outputPath) { continue }
            $outputPath = [IO.Path]::GetFullPath($outputPath, $projectDirectory)
            if ([StringComparer]::OrdinalIgnoreCase.Equals($outputPath, $movie) -or
                [StringComparer]::OrdinalIgnoreCase.Equals($outputPath, $session) -or
                $outputPath.StartsWith($sessionPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Input-session output collision: $outputPath"
            }
            $outputPath
        }
    )
    Assert-MgsInputOutputAliases $movie $outputs
}

if ($ResumeInput -and ($ReplayInput -or $LoadCheckpoint -or $SaveCheckpoint -or
    $PSBoundParameters.ContainsKey('Stage') -or $PSBoundParameters.ContainsKey('StageMap'))) {
    throw '-ResumeInput selects its recorded map entry; do not combine it with replay, checkpoint or stage overrides.'
}
if ($LoadCheckpoint -and ($Stage -ne 'title' -or $PSBoundParameters.ContainsKey('StageMap'))) {
    throw '-LoadCheckpoint restores its saved map; do not combine it with development stage overrides.'
}
if ($SaveCheckpoint -and (-not $ReplayInput -or $ReplayTailFrames)) {
    throw '-SaveCheckpoint requires a verified replay endpoint without a diagnostic tail.'
}
if ($ReplayInput -and ($RecordInput -or $Probe -or $Frames -or $CaptureEvery)) {
    throw '-ReplayInput cannot be combined with -RecordInput, -Probe, -Frames or -CaptureEvery.'
}
if (($ReplayFast -or $ReplayTailFrames) -and -not $ReplayInput) {
    throw '-ReplayFast and -ReplayTailFrames require -ReplayInput.'
}
if ($LoadCheckpoint) {
    Assert-MgsInputOutputs $LoadCheckpoint @($Capture, $CadenceLog, $RecordInput, $SaveCheckpoint)
}
if ($RecordInput -or $ReplayInput -or $ResumeInput) {
    $moviePath = if ($RecordInput) { $RecordInput } elseif ($ReplayInput) { $ReplayInput } else { $ResumeInput }
    Assert-MgsInputOutputs $moviePath @($Capture, $CadenceLog, $SaveCheckpoint)
    if ($ResumeInput) {
        Assert-MgsInputOutputs $ResumeInput @($Capture, $CadenceLog, $RecordInput)
    }
}
if (($RecordInput -or $ReplayInput) -and
    (Test-Path -LiteralPath ([IO.Path]::GetFullPath($CadenceLog, $projectDirectory)))) {
    throw 'Input-session timing output requires a new file; recorded timing is never overwritten.'
}
if ($ReplayInput -or $ResumeInput) {
    $sourceMovie = if ($ReplayInput) { $ReplayInput } else { $ResumeInput }
    $replayPath = [IO.Path]::GetFullPath($sourceMovie, $projectDirectory)
    $replayMetadata = Get-Content -LiteralPath "$replayPath.session/session.json" -Raw | ConvertFrom-Json
    $startup = $replayMetadata.identityData.startup
    if ($ReplayInput -and $replayMetadata.PSObject.Properties['presentation']) {
        $presentation = $replayMetadata.presentation
        if (-not $PSBoundParameters.ContainsKey('Widescreen')) { $Widescreen = [bool]$presentation.widescreen }
        if (-not $PSBoundParameters.ContainsKey('Fullscreen')) { $Fullscreen = [bool]$presentation.fullscreen }
        if (-not $PSBoundParameters.ContainsKey('Resolution') -and $presentation.resolution) {
            $Resolution = $presentation.resolution
            $PSBoundParameters['Resolution'] = $Resolution
        }
    }
    if ($ReplayInput -and -not $PSBoundParameters.ContainsKey('Stage')) {
        $Stage = $startup.stage
        $PSBoundParameters['Stage'] = $Stage
    }
    if ($ReplayInput -and -not $PSBoundParameters.ContainsKey('StageMap') -and $startup.map -ge 0) {
        $StageMap = $startup.map
        $PSBoundParameters['StageMap'] = $StageMap
    }
    if (-not $PSBoundParameters.ContainsKey('BonusItems')) {
        $BonusItems = [bool]$startup.bonusItems
    }
    if (-not $PSBoundParameters.ContainsKey('Invulnerable')) {
        $Invulnerable = Get-MgsInputInvulnerability $startup
    }
    if (-not $PSBoundParameters.ContainsKey('AutoCard')) {
        $AutoCard = Get-MgsInputBooleanSetting $startup 'autoCard'
    }
    if (-not $PSBoundParameters.ContainsKey('MantisMemory')) {
        $recordedSeed = Get-MgsInputMantisMemory $startup
        if ($recordedSeed) { $MantisMemory = $recordedSeed.ToString() }
    }
}
$mantisMemorySeed = 0
if ($MantisMemory -eq 'random') {
    if ($ReplayInput) { throw 'Replay uses the recorded Mantis memory seed; omit -MantisMemory random.' }
    $mantisMemorySeed = Get-Random -Minimum 1 -Maximum 2147483647
} elseif ($MantisMemory -ne 'off') {
    if (-not [int]::TryParse($MantisMemory, [ref]$mantisMemorySeed) -or $mantisMemorySeed -lt 1) {
        throw '-MantisMemory requires random, off, or a seed from 1 to 2147483647.'
    }
}
if (-not $BuildDirectory) {
    $BuildDirectory = "build/windows-x86-$($Configuration.ToLowerInvariant())"
}
$executable = Join-Path ([IO.Path]::GetFullPath($BuildDirectory, $projectDirectory)) 'mgs-integral-native.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw 'Build the native executable first with tools/build.ps1.'
}
if (-not $Disc) {
    $manifestPath = Join-Path $projectDirectory '.local/content/disc1/manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'Provide -Disc <Integral disc 1.cue>, or import your discs first.'
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $Disc = $manifest.cue.path
}
if (-not $DiscTwo) {
    $secondManifestPath = Join-Path $projectDirectory '.local/content/disc2/manifest.json'
    if (Test-Path -LiteralPath $secondManifestPath -PathType Leaf) {
        $secondManifest = Get-Content -LiteralPath $secondManifestPath -Raw | ConvertFrom-Json
        $DiscTwo = $secondManifest.cue.path
    }
}
$Disc = (Resolve-Path -LiteralPath $Disc).Path
if ($DiscTwo) {
    $DiscTwo = (Resolve-Path -LiteralPath $DiscTwo).Path
}
if ($ModsRoot) {
    $ModsRoot = (Resolve-Path -LiteralPath $ModsRoot).Path
}
if ($ResumeInput) {
    . (Join-Path $PSScriptRoot 'resume-input.ps1')
    $LoadCheckpoint = Initialize-MgsInputResume -ProjectDirectory $projectDirectory `
        -Executable $executable -MoviePath $replayPath -Disc $Disc -DiscTwo $DiscTwo -ModsRoot $ModsRoot
}
if ($ResumeInput) {
    Assert-MgsInputOutputs $LoadCheckpoint @($Capture, $CadenceLog, $RecordInput, $SaveCheckpoint)
}
if ($Probe -in @('dock', 'bonus', 'dock-route') -and -not $LoadCheckpoint -and
    -not $PSBoundParameters.ContainsKey('Stage')) {
    $Stage = 's00a'
}
$gameArguments = @('--disc', $Disc, '--stage', $Stage)
if ($Widescreen) {
    $gameArguments += '--widescreen'
}
if ($PSBoundParameters.ContainsKey('Resolution')) {
    $gameArguments += @('--resolution', $Resolution)
}
if ($Fullscreen) {
    $gameArguments += '--fullscreen'
}
if ($DebugOverlay) {
    $gameArguments += '--debug-overlay'
}
if ($ReplayFast) {
    $gameArguments += @('--replay-fast', '1')
}
if ($ReplayTailFrames) {
    $gameArguments += @('--replay-tail-frames', $ReplayTailFrames.ToString())
}
if ($BonusItems) {
    $gameArguments += @('--bonus-items', '1')
}
if ($Invulnerable) {
    $gameArguments += @('--invulnerable', '1')
}
$gameArguments += @('--auto-card', ([int][bool]$AutoCard).ToString())
if ($mantisMemorySeed) {
    $gameArguments += @('--mantis-memory', $mantisMemorySeed.ToString())
    Write-Host "[mantis] Synthetic memory seed: $mantisMemorySeed"
}
if ($DiscTwo) {
    $gameArguments += @('--disc-two', $DiscTwo)
}
if ($PSBoundParameters.ContainsKey('StageMap')) {
    if (-not $PSBoundParameters.ContainsKey('Stage') -or $Stage -eq 'title') {
        throw '-StageMap requires an explicit development -Stage other than title.'
    }
    $gameArguments += @('--stage-map', $StageMap.ToString())
}
if ($ModsRoot) {
    $gameArguments += @('--mods-root', $ModsRoot)
}
if ($Frames) {
    $gameArguments += @('--frames', $Frames.ToString())
}
if ($Capture) {
    if (-not $Frames -and -not $ReplayInput) {
        throw '-Capture requires a positive -Frames limit or -ReplayInput.'
    }
    $capturePath = [IO.Path]::GetFullPath($Capture, $projectDirectory)
    New-Item -ItemType Directory -Path (Split-Path $capturePath -Parent) -Force | Out-Null
    $gameArguments += @('--capture', $capturePath)
}
if ($PSBoundParameters.ContainsKey('CaptureEvery')) {
    if (-not $Capture) {
        throw '-CaptureEvery requires -Capture and a positive -Frames limit.'
    }
    $gameArguments += @('--capture-every', $CaptureEvery.ToString())
}
if ($Probe) {
    if (-not $Frames) {
        throw '-Probe requires a positive -Frames limit.'
    }
    $gameArguments += @('--probe', $Probe)
}
if ($CadenceLog) {
    $cadencePath = [IO.Path]::GetFullPath($CadenceLog, $projectDirectory)
    New-Item -ItemType Directory -Path (Split-Path $cadencePath -Parent) -Force | Out-Null
    $gameArguments += @('--cadence-log', $cadencePath)
    Write-Host "[timing] $cadencePath"
}
if (-not $RuntimeDirectory) { $RuntimeDirectory = Join-Path $projectDirectory '.local/runtime' }
$runtimeDirectory = [IO.Path]::GetFullPath($RuntimeDirectory, $projectDirectory)
if ($LoadCheckpoint) {
    $LoadCheckpoint = [IO.Path]::GetFullPath($LoadCheckpoint, $projectDirectory)
}
if ($RecordInput -or $ReplayInput) {
    $sessionMap = if ($PSBoundParameters.ContainsKey('StageMap')) { $StageMap } else { -1 }
    $inputSession = Initialize-MgsInputSession -ProjectDirectory $projectDirectory `
        -RuntimeDirectory $runtimeDirectory `
        -Executable $executable -RecordPath $RecordInput -ReplayPath $ReplayInput `
        -Disc $Disc -DiscTwo $DiscTwo -Stage $Stage -StageMap $sessionMap `
        -BonusItems ([bool]$BonusItems) -Invulnerable ([bool]$Invulnerable) `
        -AutoCard ([bool]$AutoCard) `
        -MantisMemorySeed $mantisMemorySeed `
        -ModsRoot $ModsRoot -CheckpointPath $LoadCheckpoint `
        -Presentation @{ widescreen = [bool]$Widescreen; resolution = $Resolution; fullscreen = [bool]$Fullscreen }
    $runtimeDirectory = $inputSession.RuntimeDirectory
    $inputFlag = if ($RecordInput) { '--record-input' } else { '--replay-input' }
    $gameArguments += @($inputFlag, $inputSession.InputPath, '--input-identity', $inputSession.Identity)
    $LoadCheckpoint = $inputSession.CheckpointPath
    $performancePath = if ($RecordInput) { "$($inputSession.InputPath).session/performance.json" } else {
        Join-Path $runtimeDirectory 'performance.json'
    }
    $performance = [ordered]@{
        schema = 1; mode = $inputSession.Mode; movie = $inputSession.InputPath
        timingMode = 'slow-frames'; toleranceUs = 2000
        identity = $inputSession.Identity; timing = $cadencePath; replayFast = [bool]$ReplayFast
        executableSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
        widescreen = [bool]$Widescreen; resolution = $Resolution
        fullscreen = [bool]$Fullscreen; debugOverlay = [bool]$DebugOverlay
    }
    $performance | ConvertTo-Json | Set-Content -LiteralPath $performancePath -Encoding utf8
}
if ($LoadCheckpoint) {
    $gameArguments += @('--load-checkpoint', $LoadCheckpoint)
}
if ($SaveCheckpoint) {
    $gameArguments += @('--save-checkpoint', [IO.Path]::GetFullPath($SaveCheckpoint, $projectDirectory))
}
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
Push-Location $runtimeDirectory
try {
    do {
        & $executable @gameArguments
        $gameExitCode = $LASTEXITCODE
        if ($gameExitCode -eq 75 -and ($RecordInput -or $ReplayInput -or $LoadCheckpoint)) {
            throw 'Input movies stop at a native process restart; start a new recording for the next process.'
        }
    } while ($gameExitCode -eq 75)
    if ($gameExitCode -ne 0) {
        throw "Native game exited with code $gameExitCode."
    }
}
finally {
    Pop-Location
}
