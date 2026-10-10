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
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('mgs-video-cli-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$cue = Join-Path $fixture 'disc.cue'
$image = Join-Path $fixture 'disc.bin'
[IO.File]::WriteAllText($cue, "FILE disc.bin BINARY`n TRACK 01 MODE2/2352`n INDEX 01 00:00:00`n")
[IO.File]::WriteAllText($image, 'Protected test data; not a game disc.')
$cueHash = (Get-FileHash -LiteralPath $cue).Hash
$imageHash = (Get-FileHash -LiteralPath $image).Hash
$checks = 0

function Assert-WrapperResult {
    param([string]$Name, [hashtable]$Options, [string]$Expected)

    $parameters = @{ Disc = $cue; BuildDirectory = (Join-Path $fixture 'absent-build') }
    foreach ($key in $Options.Keys) { $parameters[$key] = $Options[$key] }
    $message = $null
    try {
        & $wrapper @parameters | Out-Null
    } catch {
        $message = $_.Exception.Message
    }
    if (-not $message -or -not $message.Contains($Expected)) {
        throw "Wrapper case '$Name' expected '$Expected': $message"
    }
    ++$script:checks
}

function Assert-NativeResult {
    param([string]$Name, [string[]]$Options, [string]$Expected)

    $arguments = @('--disc', $cue, '--record-input', $cue, '--input-identity', ('0' * 64)) + $Options
    $output = (& $Executable @arguments 2>&1 | Out-String)
    $code = $LASTEXITCODE
    if ($code -ne 2 -or -not $output.Contains($Expected)) {
        throw "Native case '$Name' expected exit 2 and '$Expected', got ${code}: $output"
    }
    ++$script:checks
}

$malformed = @('', '2560', '2560X1440', '2560x', 'x1440', '2560xx1440',
    ' 2560x1440', '2560x1440 ', '2560x1440junk', '+2560x1440', '-2560x1440',
    '2560.0x1440', '2560x1440x1')
$outOfRange = @('0x1440', '2560x0', '319x1440', '2560x239', '7681x1440',
    '2560x4321', '4294967296x1440', '2560x4294967296')
foreach ($value in $malformed) {
    Assert-WrapperResult "malformed resolution '$value'" @{Resolution = $value} 'Resolution'
}
foreach ($value in $outOfRange) {
    Assert-WrapperResult "out-of-range resolution '$value'" @{Resolution = $value} '-Resolution requires'
}
foreach ($value in @('320x240', '2560x1440', '7680x4320')) {
    Assert-WrapperResult "accepted resolution $value" @{
        Resolution = $value; Widescreen = $true; Fullscreen = $true
    } 'Build the native executable first'
}
Assert-WrapperResult 'default widescreen resolution' @{Widescreen = $true} 'Build the native executable first'
Assert-WrapperResult 'fullscreen without resolution' @{Fullscreen = $true} 'Build the native executable first'
Assert-WrapperResult 'fast loading' @{FastLoading = $true} 'Build the native executable first'

if (-not $WrapperOnly) {
    foreach ($value in $malformed + $outOfRange) {
        Assert-NativeResult "rejected resolution '$value'" @('--resolution', $value) 'Usage:'
    }
    foreach ($options in @(
        @('--resolution'),
        @('--resolution', '--fullscreen'),
        @('--widescreen', '1'),
        @('--fullscreen', '1'),
        @('--fast-loading'),
        @('--fast-loading', 'yes'),
        @('--widescreen', '--frames'),
        @('--resolution=2560x1440')
    )) {
        Assert-NativeResult "malformed arguments $options" $options 'Usage:'
    }
    foreach ($value in @('320x240', '2560x1440', '7680x4320')) {
        Assert-NativeResult "accepted resolution $value" @('--resolution', $value) 'Output path'
    }
    foreach ($options in @(
        @('--widescreen'),
        @('--texture-correction'),
        @('--geometry-precision'),
        @('--depth-buffer'),
        @('--fast-loading', '0'),
        @('--fast-loading', '1'),
        @('--texture-correction', '--geometry-precision', '--depth-buffer'),
        @('--fullscreen'),
        @('--widescreen', '--fullscreen'),
        @('--widescreen', '--resolution', '2560x1440', '--fullscreen'),
        @('--fullscreen', '--resolution', '2560x1440', '--widescreen')
    )) {
        Assert-NativeResult "accepted flags $options" $options 'Output path'
    }
}

if ((Get-FileHash -LiteralPath $cue).Hash -cne $cueHash -or
    (Get-FileHash -LiteralPath $image).Hash -cne $imageHash -or
    @(Get-ChildItem -LiteralPath $fixture -Force).Count -ne 2) {
    throw "CLI validation modified the test fixture: $fixture"
}
"PASS: $checks video CLI cases; protected fixtures unchanged. Fixtures: $fixture"
