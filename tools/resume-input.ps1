Set-StrictMode -Version Latest

function Get-MgsResumeCache {
    param([string]$Directory, [string]$SourceHash, [string]$Identity)

    $metadataPath = Join-Path $Directory 'checkpoint.json'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $null
    }
    Assert-MgsInputPlainPath $metadataPath
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ($metadata.schema -ne 1 -or $metadata.sourceSha256 -cne $SourceHash -or
        $metadata.identity -cne $Identity -or $metadata.attempt -cnotmatch '^[0-9a-f]{32}$') {
        throw "Invalid resume cache metadata: $metadataPath"
    }
    $checkpoint = Join-Path $Directory "$($metadata.attempt)/checkpoint.mgssave"
    Assert-MgsInputPlainPath $checkpoint
    if ((Get-MgsInputFileHash $checkpoint) -cne $metadata.checkpointSha256) {
        throw "Resume checkpoint changed: $checkpoint"
    }
    Write-Host "[resume] Cached map entry: $($metadata.stage). No history replay needed."
    return $checkpoint
}

function Export-MgsResumeCheckpoint {
    param([string]$Executable, $Session, [string]$Prefix, [string]$Checkpoint,
          [string]$Log, $Startup, [string]$Disc, [string]$DiscTwo, [string]$ModsRoot, [string]$TextPack, [string]$VoicePack)

    $arguments = @('--disc', $Disc, '--stage', $Startup.stage,
        '--replay-input', $Prefix, '--input-identity', $Session.Identity,
        '--replay-fast', '1', '--save-checkpoint', $Checkpoint)
    if ($Startup.map -ge 0) { $arguments += @('--stage-map', $Startup.map.ToString()) }
    if ($Startup.bonusItems) { $arguments += @('--bonus-items', '1') }
    if (Get-MgsInputInvulnerability $Startup) { $arguments += @('--invulnerable', '1') }
    $arguments += @('--auto-card', ([int](Get-MgsInputBooleanSetting $Startup 'autoCard')).ToString())
    $memorySeed = Get-MgsInputMantisMemory $Startup
    if ($memorySeed) { $arguments += @('--mantis-memory', $memorySeed.ToString()) }
    if ($DiscTwo) { $arguments += @('--disc-two', $DiscTwo) }
    if ($ModsRoot) { $arguments += @('--mods-root', $ModsRoot) }
    if ($TextPack) { $arguments += @('--text-pack', $TextPack) }
    if ($VoicePack) { $arguments += @('--voice-pack', $VoicePack) }
    if ($Session.CheckpointPath) { $arguments += @('--load-checkpoint', $Session.CheckpointPath) }
    Push-Location $Session.RuntimeDirectory
    try {
        & $Executable @arguments *> $Log
        if ($LASTEXITCODE -ne 0) {
            throw "Map-entry recovery failed; see $Log"
        }
    } finally {
        Pop-Location
    }
    if (-not (Test-Path -LiteralPath $Checkpoint -PathType Leaf)) {
        throw "Replay did not export a checkpoint; see $Log"
    }
}

function New-MgsResumeCache {
    param([string]$ProjectDirectory, [string]$Executable, [string]$MoviePath,
          [string]$Directory, [string]$SourceHash, $Session, $Startup,
          [string]$Disc, [string]$DiscTwo, [string]$ModsRoot, [string]$TextPack, [string]$VoicePack)

    $attempt = [Guid]::NewGuid().ToString('N')
    $output = Join-Path $Directory $attempt
    [void][IO.Directory]::CreateDirectory($output)
    $prefix = Join-Path $output 'prefix.mgsinput'
    $manifest = Join-Path $output 'prefix.json'
    $checkpoint = Join-Path $output 'checkpoint.mgssave'
    $log = Join-Path $output 'recovery.log'
    $python = Join-Path $ProjectDirectory '.venv/Scripts/python.exe'
    & $python (Join-Path $ProjectDirectory 'tools/prepare-input-resume.py') `
        $MoviePath --output $prefix --manifest $manifest | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not prepare the recording map-entry prefix.' }
    $selection = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    if ((Get-MgsInputFileHash $MoviePath) -cne $SourceHash) {
        throw 'Recording changed while preparing resume; stop recording before resuming it.'
    }
    if ($selection.fallback.used) {
        Write-Host "[resume] Last visit was not fully loaded; using $($selection.selected.stage)."
    }
    Write-Host "[resume] Recovering the last loaded map entry once; progress log: $log"
    Export-MgsResumeCheckpoint -Executable $Executable -Session $Session -Prefix $prefix `
        -Checkpoint $checkpoint -Log $log -Startup $Startup -Disc $Disc -DiscTwo $DiscTwo -ModsRoot $ModsRoot -TextPack $TextPack -VoicePack $VoicePack
    $metadata = [ordered]@{
        schema = 1; sourceSha256 = $SourceHash; identity = $Session.Identity
        attempt = $attempt; stage = $selection.selected.stage
        checkpointSha256 = Get-MgsInputFileHash $checkpoint
        executableSha256 = Get-MgsInputFileHash $Executable
    }
    $json = ConvertTo-Json -InputObject $metadata -Depth 5
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $file = [IO.File]::Open((Join-Path $Directory 'checkpoint.json'), [IO.FileMode]::CreateNew)
    try { $file.Write($bytes, 0, $bytes.Length) } finally { $file.Dispose() }
    Write-Host "[resume] Saved map entry: $($selection.selected.stage). Future launches use this checkpoint."
    return $checkpoint
}

function Initialize-MgsInputResume {
    param([string]$ProjectDirectory, [string]$Executable, [string]$MoviePath,
          [string]$Disc, [string]$DiscTwo, [string]$ModsRoot, [string]$TextPack, [string]$VoicePack)

    Assert-MgsInputPlainPath $MoviePath
    Assert-MgsInputPlainPath "$MoviePath.session/session.json"
    $metadata = Get-Content -LiteralPath "$MoviePath.session/session.json" -Raw | ConvertFrom-Json
    $startup = $metadata.identityData.startup
    $session = Initialize-MgsInputSession -ProjectDirectory $ProjectDirectory -Executable $Executable `
        -ReplayPath $MoviePath -Disc $Disc -DiscTwo $DiscTwo -ModsRoot $ModsRoot -TextPack $TextPack -VoicePack $VoicePack `
        -Stage $startup.stage -StageMap $startup.map -BonusItems $startup.bonusItems `
        -Invulnerable (Get-MgsInputInvulnerability $startup) `
        -AutoCard (Get-MgsInputBooleanSetting $startup 'autoCard') `
        -MantisMemorySeed (Get-MgsInputMantisMemory $startup)
    $sourceHash = Get-MgsInputFileHash $MoviePath
    $directory = Join-Path $ProjectDirectory ".local/checkpoints/$sourceHash-$($session.Identity)"
    Assert-MgsInputPlainPath $directory
    $checkpoint = Get-MgsResumeCache $directory $sourceHash $session.Identity
    if ($checkpoint) { return $checkpoint }
    return New-MgsResumeCache -ProjectDirectory $ProjectDirectory -Executable $Executable `
        -MoviePath $MoviePath -Directory $directory -SourceHash $sourceHash -Session $session `
        -Startup $startup -Disc $Disc -DiscTwo $DiscTwo -ModsRoot $ModsRoot -TextPack $TextPack -VoicePack $VoicePack
}
