[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModZip,
    [string]$Resolution = '2560x1440',
    [ValidateRange(1800, 6000)][int]$Frames = 3600,
    [ValidateRange(0, 5999)][int]$WarmupFrames = 1100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Frames - $WarmupFrames -lt 600) { throw 'Measure at least 600 frames after warmup.' }
$repo = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $repo ('build/godot-performance/' + [Guid]::NewGuid().ToString('N'))
$test = Join-Path $repo 'build/windows-x86-godot/reintegral_mod_tests.exe'
$discOne = (Get-Content (Join-Path $repo '.local/content/disc1/manifest.json') -Raw | ConvertFrom-Json).cue.path
$discTwo = (Get-Content (Join-Path $repo '.local/content/disc2/manifest.json') -Raw | ConvertFrom-Json).cue.path
& $test --performance-check $repo (Resolve-Path -LiteralPath $ModZip).Path $folder $discOne $discTwo $Resolution $Frames
if ($LASTEXITCODE -ne 0) { throw "Performance boot failed. See $folder" }

$samples = @(Import-Csv (Join-Path $folder 'timing.csv'))
if ($samples.Count -ne $Frames) { throw "Expected $Frames timing samples, got $($samples.Count)." }
$measured = @($samples | Where-Object { [int]$_.vsync -gt $WarmupFrames })
$culture = [Globalization.CultureInfo]::InvariantCulture
$times = @($measured | ForEach-Object { [double]::Parse($_.frame_us, $culture) } | Sort-Object)
$target = [double]::Parse($measured[0].target_us, $culture)
$mean = ($times | Measure-Object -Average).Average
$slow = @($times | Where-Object { $_ -gt $target + 2000 }).Count
$summary = [ordered]@{
    resolution = $Resolution
    warmup_frames = $WarmupFrames
    measured_frames = $times.Count
    target_fps = [math]::Round(1000000 / $target, 3)
    average_fps = [math]::Round(1000000 / $mean, 3)
    p50_ms = $times[[math]::Ceiling($times.Count * 0.50) - 1] / 1000
    p95_ms = $times[[math]::Ceiling($times.Count * 0.95) - 1] / 1000
    p99_ms = $times[[math]::Ceiling($times.Count * 0.99) - 1] / 1000
    max_ms = $times[-1] / 1000
    over_budget_plus_2ms = $slow
}
$json = $summary | ConvertTo-Json
$json | Set-Content -LiteralPath (Join-Path $folder 'summary.json') -Encoding utf8
Write-Output $json
Write-Host "Logs: $folder"
if ($slow -gt 0 -or $mean -gt $target + 50) {
    throw 'Steady gameplay missed the native 60 Hz cadence; inspect timing.csv.'
}
