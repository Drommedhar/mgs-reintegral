[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SessionDirectory,
    [Parameter(Mandatory)][ValidateSet('title', 's00a', 's01a')][string]$Stage,
    [Parameter(Mandatory)][string]$Manifest,
    [string]$ModProfile,
    [ValidateSet(1, 2)][int]$StartDisc = 1,
    [int]$OwnerPid = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$sessionRoot = [IO.Path]::GetFullPath($SessionDirectory, $repository)
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $repository 'build/godot-editor-runs')) + [IO.Path]::DirectorySeparatorChar
if (-not $sessionRoot.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Editor test sessions must be inside build/godot-editor-runs.'
}
New-Item -ItemType Directory -Path $sessionRoot -Force | Out-Null
$statusPath = Join-Path $sessionRoot 'status.json'
$stopPath = Join-Path $sessionRoot 'stop'

function Write-SessionStatus([string]$State, [string]$Message) {
    @{schema = 1; state = $State; message = $Message; stage = $Stage; disc = $StartDisc} |
        ConvertTo-Json | Set-Content -LiteralPath "$statusPath.tmp" -Encoding utf8NoBOM
    Move-Item -LiteralPath "$statusPath.tmp" -Destination $statusPath -Force
}

$child = $null
$owner = $null
$stopTime = $null
$forced = $false
try {
    Write-SessionStatus 'starting' 'Preparing native test…'
    if (-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) { throw "Mod manifest is missing: $Manifest" }
    if ($OwnerPid -gt 0) { $owner = Get-Process -Id $OwnerPid -ErrorAction Stop }
    $runner = Join-Path $PSScriptRoot 'run-godot.ps1'
    $runtime = Join-Path $sessionRoot 'runtime'
    $runnerArguments = @(
        '-NoProfile', '-File', "`"$runner`"", '-Stage', $Stage, '-Scene3D',
        '-StartDisc', $StartDisc,
        '-Mods', "`"$Manifest`"", '-RuntimeDirectory', "`"$runtime`"",
        '-LogDirectory', "`"$sessionRoot`"", '-Resolution', '1280x720', '-Widescreen'
    )
    if ($ModProfile) { $runnerArguments += @('-ModProfile', "`"$ModProfile`"") }
    $child = Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList $runnerArguments `
        -Environment @{MGS_GODOT_STOP_FILE = $stopPath} -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $sessionRoot 'runner.log') `
        -RedirectStandardError (Join-Path $sessionRoot 'runner.err')
    $running = $false
    while (-not $child.WaitForExit(250)) {
        if ((Test-Path -LiteralPath $stopPath) -or ($owner -and $owner.HasExited)) {
            if ($null -eq $stopTime) {
                $stopTime = [DateTime]::UtcNow
                Set-Content -LiteralPath $stopPath -Value 'stop'
                Write-SessionStatus 'stopping' 'Stopping native test…'
            }
            if (([DateTime]::UtcNow - $stopTime).TotalSeconds -gt 5) {
                $child.Kill($true)
                $child.WaitForExit()
                $forced = $true
            }
        }
        elseif (-not $running) {
            $log = Join-Path $sessionRoot 'godot.log'
            if ((Test-Path -LiteralPath $log) -and (Select-String -LiteralPath $log -Pattern "^MGS_NATIVE_CONTEXT stage=$Stage epoch=" -Quiet)) {
                $running = $true
                Write-SessionStatus 'running' "Native test running ($Stage). Workspace edits were loaded at launch."
            }
        }
    }
    if ($null -ne $stopTime) {
        $message = if ($forced) { 'Native test stopped; forced process cleanup after shutdown timeout.' } else { 'Native test stopped.' }
        Write-SessionStatus 'stopped' $message
    }
    elseif ($child.ExitCode -eq 0) { Write-SessionStatus 'stopped' 'Native test finished.' }
    else {
        $details = foreach ($name in @('godot.err', 'runner.err')) {
            $path = Join-Path $sessionRoot $name
            if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Tail 12 }
        }
        throw "Native test failed (exit $($child.ExitCode)). $($details -join [Environment]::NewLine)"
    }
}
catch {
    Write-SessionStatus 'failed' $_.Exception.Message
    exit 1
}
finally {
    if ($child) {
        if (-not $child.HasExited) {
            $child.Kill($true)
            $child.WaitForExit()
        }
        $child.Dispose()
    }
    if ($owner) { $owner.Dispose() }
}
