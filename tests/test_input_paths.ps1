[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [switch]$WrapperOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$project = Split-Path $PSScriptRoot -Parent
$wrapper = Join-Path $project 'tools/run.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('mgs-input-paths-' + [Guid]::NewGuid().ToString('N'))
$checks = 0

function Write-Fixture {
    param([string]$Path, [string]$Text)

    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, $Text)
}

function Get-FixtureState {
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($entry in Get-ChildItem -LiteralPath $fixture -Recurse -Force) {
        $relative = [IO.Path]::GetRelativePath($fixture, $entry.FullName)
        if ($entry.PSIsContainer) {
            $entries.Add("D $relative")
        } else {
            $hash = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash
            $entries.Add("F $relative $hash")
        }
    }
    $entries.Sort([StringComparer]::Ordinal)
    return $entries -join "`n"
}

function Assert-Unchanged {
    param([string]$Before, [string]$Name)

    if ($Before -cne (Get-FixtureState)) {
        throw "Rejected case modified files or directories: $Name; fixture=$fixture"
    }
}

function Assert-NativeRejected {
    param([string]$Name, [string[]]$Arguments, [string]$Expected)

    $before = Get-FixtureState
    $nativeArguments = @('--disc', $cue) + $Arguments
    $output = (& $Executable @nativeArguments 2>&1 | Out-String)
    $code = $LASTEXITCODE
    Assert-Unchanged $before $Name
    if ($code -ne 2) {
        throw "Native case '$Name' returned $code instead of 2: $output"
    }
    if ($Expected -and -not $output.Contains($Expected)) {
        throw "Native case '$Name' did not reject for '$Expected': $output"
    }
    ++$script:checks
}

function Assert-WrapperRejected {
    param([string]$Name, [hashtable]$Options, [string]$Expected = 'Input-session output')

    $before = Get-FixtureState
    $parameters = @{
        Disc = $cue
        BuildDirectory = (Join-Path $fixture 'missing-build')
    }
    foreach ($key in $Options.Keys) { $parameters[$key] = $Options[$key] }
    $message = $null
    try {
        & $wrapper @parameters | Out-Null
    } catch {
        $message = $_.Exception.Message
    }
    Assert-Unchanged $before $Name
    if (-not $message -or -not $message.Contains($Expected)) {
        throw "Wrapper case '$Name' did not reject for '$Expected': $message"
    }
    ++$script:checks
}

$cue = Join-Path $fixture 'discs/disc one.cue'
$bin = Join-Path $fixture 'discs/first track.bin'
$cueTwo = Join-Path $fixture 'discs/disc two.cue'
$binTwo = Join-Path $fixture 'discs/second track.bin'
$movie = Join-Path $fixture 'replays/movie.input'
$metadata = "$movie.session/session.json"
$snapshot = "$movie.session/initial/bu00/save-file"
$freshMovie = Join-Path $fixture 'fresh/new.input'
$checkpoint = Join-Path $fixture 'checkpoints/map-start.mgssave'
$freshCheckpoint = Join-Path $fixture 'fresh/new.mgssave'
$identity = '0' * 64
Write-Fixture $bin 'dummy disc one data, not a game image'
Write-Fixture $binTwo 'dummy disc two data, not a game image'
Write-Fixture $cue "FILE `"first track.bin`" BINARY`n TRACK 01 MODE2/2352`n INDEX 01 00:00:00`n"
Write-Fixture $cueTwo "FILE `"second track.bin`" BINARY`n TRACK 01 MODE2/2352`n INDEX 01 00:00:00`n"
Write-Fixture $movie 'protected input recording'
Write-Fixture $metadata 'invalid metadata: path validation must precede reading this'
Write-Fixture $snapshot 'protected initial memory card'
Write-Fixture $checkpoint 'protected checkpoint: path validation must precede loading this'
$movieAlias = Join-Path $fixture 'movie-hardlink'
$cueAlias = Join-Path $fixture 'cue-hardlink'
$binAlias = Join-Path $fixture 'bin-hardlink'
$metadataAlias = Join-Path $fixture 'metadata-hardlink'
$snapshotAlias = Join-Path $fixture 'snapshot-hardlink'
$checkpointAlias = Join-Path $fixture 'checkpoint-hardlink'
foreach ($pair in @(@($movieAlias, $movie), @($cueAlias, $cue), @($binAlias, $bin),
                     @($metadataAlias, $metadata), @($snapshotAlias, $snapshot),
                     @($checkpointAlias, $checkpoint))) {
    New-Item -ItemType HardLink -Path $pair[0] -Target $pair[1] | Out-Null
}
$linkedCue = Join-Path $fixture 'cue-link/disc.cue'
$linkedBin = Join-Path $fixture 'cue-link/first track.bin'
Write-Fixture $linkedBin 'protected image relative to the symbolic cue path'
try {
    New-Item -ItemType SymbolicLink -Path $linkedCue -Target $cue -ErrorAction Stop | Out-Null
} catch {
    Write-Warning "Symbolic CUE case unavailable on this host: $($_.Exception.Message)"
    $linkedCue = $null
}
$relativeMovie = [IO.Path]::GetRelativePath($project, $movie)
$collapsedMovie = Join-Path ([IO.Path]::GetDirectoryName($movie)) 'absent/../movie.input'

foreach ($output in @($movie, $movie.ToUpperInvariant(), $relativeMovie, $collapsedMovie, $movieAlias)) {
    Assert-WrapperRejected "replay cadence $output" @{ ReplayInput = $movie; CadenceLog = $output }
    Assert-WrapperRejected "replay capture $output" @{ ReplayInput = $movie; Capture = $output }
    Assert-WrapperRejected "replay checkpoint $output" @{ ReplayInput = $movie; SaveCheckpoint = $output }
}
foreach ($output in @($metadata, $snapshot, "$movie.session/new/output.csv", "$movie.session",
                      $metadata.ToUpperInvariant(), $metadataAlias, $snapshotAlias)) {
    Assert-WrapperRejected "protected session cadence $output" @{ ReplayInput = $movie; CadenceLog = $output }
    Assert-WrapperRejected "protected session capture $output" @{ ReplayInput = $movie; Capture = $output }
    Assert-WrapperRejected "protected session checkpoint $output" @{ ReplayInput = $movie; SaveCheckpoint = $output }
}
Assert-WrapperRejected 'new recording aliases cadence' @{ RecordInput = $freshMovie; CadenceLog = $freshMovie }
Assert-WrapperRejected 'new recording aliases capture' @{ RecordInput = $freshMovie; Capture = $freshMovie; Frames = 1 }
Assert-WrapperRejected 'new session output' @{ RecordInput = $freshMovie; Capture = "$freshMovie.session/new/frame.bmp"; Frames = 1 }
Assert-WrapperRejected 'session sibling is allowed' @{
    RecordInput = $freshMovie; CadenceLog = "$freshMovie.session-other/log.csv"
} 'Build the native executable first'
$relativeCheckpoint = [IO.Path]::GetRelativePath($project, $checkpoint)
$collapsedCheckpoint = Join-Path ([IO.Path]::GetDirectoryName($checkpoint)) 'absent/../map-start.mgssave'
foreach ($output in @($checkpoint, $checkpoint.ToUpperInvariant(), $relativeCheckpoint,
                      $collapsedCheckpoint, $checkpointAlias)) {
    Assert-WrapperRejected "checkpoint source cadence $output" @{
        LoadCheckpoint = $checkpoint; RecordInput = $freshMovie; CadenceLog = $output
    }
    Assert-WrapperRejected "checkpoint source capture $output" @{
        LoadCheckpoint = $checkpoint; RecordInput = $freshMovie; Capture = $output; Frames = 1
    }
    Assert-WrapperRejected "checkpoint source recording $output" @{
        LoadCheckpoint = $checkpoint; RecordInput = $output
    }
    Assert-WrapperRejected "checkpoint source export $output" @{
        LoadCheckpoint = $checkpoint; ReplayInput = $movie; SaveCheckpoint = $output
    }
}

if (-not $WrapperOnly) {
    Push-Location $project
    try {
        foreach ($output in @($movie, $movie.ToUpperInvariant(), $relativeMovie, $collapsedMovie, $movieAlias)) {
            $replay = @('--replay-input', $movie, '--input-identity', $identity)
            Assert-NativeRejected "movie cadence $output" ($replay + @('--cadence-log', $output))
            Assert-NativeRejected "movie capture $output" ($replay + @('--capture', $output))
            Assert-NativeRejected "movie checkpoint $output" ($replay + @('--save-checkpoint', $output)) 'Output path'
        }
        Assert-NativeRejected 'recording aliases capture' @(
            '--record-input', $freshMovie, '--input-identity', $identity,
            '--capture', $freshMovie, '--frames', '1')
        foreach ($output in @($metadata, $snapshot, "$movie.session/new/output.csv")) {
            Assert-NativeRejected "session output $output" @(
                '--replay-input', $movie, '--input-identity', $identity, '--cadence-log', $output)
            Assert-NativeRejected "session checkpoint $output" @(
                '--replay-input', $movie, '--input-identity', $identity, '--save-checkpoint', $output) 'Output path'
        }
        foreach ($output in @($cue, $cue.ToUpperInvariant(), $cueAlias, $bin, $binAlias, $cueTwo, $binTwo)) {
            Assert-NativeRejected "disc cadence $output" @('--disc-two', $cueTwo, '--cadence-log', $output)
            Assert-NativeRejected "disc capture $output" @('--disc-two', $cueTwo, '--capture', $output, '--frames', '1')
            Assert-NativeRejected "disc checkpoint $output" @(
                '--disc-two', $cueTwo, '--replay-input', $movie, '--input-identity', $identity,
                '--save-checkpoint', $output) 'Output path'
        }
        if ($linkedCue) {
            Assert-NativeRejected 'symbolic cue lexical image cadence' @('--disc', $linkedCue, '--cadence-log', $linkedBin)
            Assert-NativeRejected 'symbolic cue lexical image capture' @('--disc', $linkedCue, '--capture', $linkedBin, '--frames', '1')
            Assert-NativeRejected 'symbolic cue lexical image checkpoint' @(
                '--disc', $linkedCue, '--replay-input', $movie, '--input-identity', $identity,
                '--save-checkpoint', $linkedBin) 'Output path'
        }
        foreach ($output in @($checkpoint, $checkpoint.ToUpperInvariant(), $relativeCheckpoint,
                              $collapsedCheckpoint, $checkpointAlias)) {
            Assert-NativeRejected "loaded checkpoint cadence $output" @(
                '--load-checkpoint', $checkpoint, '--cadence-log', $output) 'Output path'
            Assert-NativeRejected "loaded checkpoint capture $output" @(
                '--load-checkpoint', $checkpoint, '--capture', $output, '--frames', '1') 'Output path'
            Assert-NativeRejected "loaded checkpoint recording $output" @(
                '--load-checkpoint', $checkpoint, '--record-input', $output,
                '--input-identity', $identity) 'Output path'
            Assert-NativeRejected "loaded checkpoint save $output" @(
                '--load-checkpoint', $checkpoint, '--replay-input', $movie,
                '--input-identity', $identity, '--save-checkpoint', $output) 'Output path'
        }
        foreach ($option in @('--capture', '--cadence-log')) {
            Assert-NativeRejected "checkpoint aliases $option" @(
                '--replay-input', $movie, '--input-identity', $identity,
                '--save-checkpoint', $freshCheckpoint, $option, $freshCheckpoint) 'Output path'
        }
        Assert-NativeRejected 'checkpoint export without replay' @('--save-checkpoint', $freshCheckpoint)
        Assert-NativeRejected 'checkpoint export with diagnostic tail' @(
            '--replay-input', $movie, '--input-identity', $identity,
            '--save-checkpoint', $freshCheckpoint, '--replay-tail-frames', '1')
        Assert-NativeRejected 'checkpoint load with development stage' @(
            '--load-checkpoint', $checkpoint, '--stage', 's01a')
        Assert-NativeRejected 'checkpoint load with stage map' @(
            '--load-checkpoint', $checkpoint, '--stage', 's01a', '--stage-map', '1')
        Assert-NativeRejected 'whitespace-negative frame count' @('--frames', ' -1')
        Assert-NativeRejected 'whitespace-negative capture interval' @(
            '--capture', (Join-Path $fixture 'new-frame.bmp'), '--frames', '1', '--capture-every', ' -1')
        Assert-NativeRejected 'wrapped-negative stage map' @('--stage', 's00a', '--stage-map', '-4294967295')
    } finally {
        Pop-Location
    }
}
"PASS: $checks input-path rejection cases; all fixture names and contents unchanged. Fixtures: $fixture"
