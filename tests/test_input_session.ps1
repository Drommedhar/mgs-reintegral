$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../tools/input-session.ps1')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('mgs-input-session-' + [Guid]::NewGuid().ToString('N'))
function Write-Text([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, $Text)
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Assert-Rejected([scriptblock]$Operation, [string]$Expected) {
    try { & $Operation | Out-Null } catch {
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
        return
    }
    throw "Expected rejection: $Expected"
}
$exe = Join-Path $fixture 'build/game.exe'
$cue = Join-Path $fixture 'discs/disc one.cue'
$cue2 = Join-Path $fixture 'discs/disc2.cue'
$bin = Join-Path $fixture 'discs/first [track].bin'
$bin2 = Join-Path $fixture 'discs/second track.bin'
$mods = Join-Path $fixture 'mods'
$modFile = Join-Path $mods 'stage/s00a/f072.p'
$normal = Join-Path $fixture '.local/runtime'
$normalCard = Join-Path $normal 'bu00/save-file'
$movie = Join-Path $fixture 'replays/sample.input'
Write-Text $exe 'build-one'
Write-Text $bin 'first-bin'
Write-Text $bin2 'second-bin'
Write-Text $cue "FILE `"first [track].bin`" BINARY`n TRACK 01 MODE2/2352`nFILE second track.bin BINARY`n TRACK 02 AUDIO`nFILE `"first [track].bin`" BINARY`n TRACK 03 AUDIO"
Write-Text $cue2 "FILE `"second track.bin`" BINARY`n TRACK 01 MODE2/2352"
Write-Text $modFile 'mod-content'
Write-Text $normalCard 'initial-save'
[void][IO.Directory]::CreateDirectory((Join-Path $normal 'bu10'))
$options = @{ ProjectDirectory=$fixture; Executable=$exe; Disc=$cue; DiscTwo=$cue2; Stage='title'; StageMap=-1; BonusItems=$false; ModsRoot=$mods }
$record = @(Initialize-MgsInputSession @options -RecordPath $movie)
Assert-True ($record.Count -eq 1) 'Helper produced extra output.'
$record = $record[0]
Assert-True ($record.RuntimeDirectory -eq $normal -and $record.Mode -eq 'record') 'Wrong recording runtime.'
Assert-True ($null -eq $record.CheckpointPath) 'Legacy recording acquired a checkpoint.'
Assert-True ($record.Identity -ceq 'b06d2456f2171c8617c9ae29336cb4d2bc47671856e48855497c1a2532801758') 'Legacy identity changed.'
Assert-True (-not (Test-Path -LiteralPath $movie)) 'Helper wrote the movie.'
$initialCard = "$movie.session/initial/bu00/save-file"
Assert-True ([IO.File]::ReadAllText($initialCard) -eq 'initial-save') 'Initial save not copied.'
Assert-True (Test-Path -LiteralPath "$movie.session/initial/bu10" -PathType Container) 'Empty card directory not retained.'
$metadataPath = "$movie.session/session.json"
$metadataOriginal = [IO.File]::ReadAllText($metadataPath)
$metadata = $metadataOriginal | ConvertFrom-Json
Assert-True ($metadata.identityData.assets.disc.images.Count -eq 2) 'CUE images not resolved/deduplicated.'
Assert-True ($null -eq $metadata.identityData.startup.PSObject.Properties['checkpointSha256']) 'Legacy metadata changed.'
Assert-Rejected { Initialize-MgsInputSession @options -RecordPath $movie } 'requires a new'
Write-Text $movie 'fake-input-data'
$pack = Join-Path $fixture 'languages/german.mgslang'
Write-Text $pack 'pack-one'
$languageMovie = Join-Path $fixture 'replays/german.input'
$languageRecord = Initialize-MgsInputSession @options -RecordPath $languageMovie -TextPack $pack -VoicePack $pack
Write-Text $languageMovie 'fake-input-data'
$languageReplay = Initialize-MgsInputSession @options -ReplayPath $languageMovie -TextPack $pack -VoicePack $pack
Assert-True ($languageReplay.Identity -ceq $languageRecord.Identity) 'Language replay identity changed.'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $languageMovie -TextPack $pack } 'assets differ'
Write-Text $pack 'pack-two'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $languageMovie -TextPack $pack -VoicePack $pack } 'assets differ'
Write-Text $exe 'build-two'
Write-Text $normalCard 'new-human-progress'
$replay = Initialize-MgsInputSession @options -ReplayPath $movie
Assert-True ($replay.Identity -ceq $record.Identity) 'Changing executable changed identity.'
Assert-True ($null -eq $replay.CheckpointPath) 'Legacy replay acquired a checkpoint.'
Assert-True ($replay.RuntimeDirectory -ne $normal -and $replay.Mode -eq 'replay') 'Replay used normal runtime.'
Assert-True ([IO.File]::ReadAllText((Join-Path $replay.RuntimeDirectory 'bu00/save-file')) -eq 'initial-save') 'Replay did not use snapshot.'
Write-Text (Join-Path $replay.RuntimeDirectory 'bu00/save-file') 'replay-progress'
$second = Initialize-MgsInputSession @options -ReplayPath $movie
Assert-True ($second.RuntimeDirectory -ne $replay.RuntimeDirectory) 'Replay reused a directory.'
Assert-True ([IO.File]::ReadAllText((Join-Path $second.RuntimeDirectory 'bu00/save-file')) -eq 'initial-save') 'Replay overwrote a prior replay.'
Assert-True ([IO.File]::ReadAllText($normalCard) -eq 'new-human-progress') 'Normal cards were modified.'
foreach ($change in @(@{Stage='s00a'}, @{StageMap=1}, @{BonusItems=$true})) {
    $changed = $options.Clone()
    foreach ($key in $change.Keys) { $changed[$key] = $change[$key] }
    Assert-Rejected { Initialize-MgsInputSession @changed -ReplayPath $movie } 'startup differ'
}
Assert-True (-not (Get-MgsInputInvulnerability $metadata.identityData.startup)) 'Legacy movie enabled invulnerability.'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie -Invulnerable $true } 'invulnerability differs'
$protectedMovie = Join-Path $fixture 'replays/invulnerable.input'
$protectedRecord = Initialize-MgsInputSession @options -RecordPath $protectedMovie -Invulnerable $true
Write-Text $protectedMovie 'fake-input-data'
$protectedMetadata = Get-Content "$protectedMovie.session/session.json" -Raw | ConvertFrom-Json
Assert-True (Get-MgsInputInvulnerability $protectedMetadata.identityData.startup) 'Invulnerability was not recorded.'
$protectedReplay = Initialize-MgsInputSession @options -ReplayPath $protectedMovie -Invulnerable $true
Assert-True ($protectedReplay.Identity -ceq $protectedRecord.Identity) 'Invulnerable replay identity changed.'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $protectedMovie } 'invulnerability differs'
Assert-Rejected { Get-MgsInputInvulnerability ([pscustomobject]@{invulnerable='false'}) } 'Invalid invulnerability'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie -AutoCard $true } 'auto-card setting differs'
$cardMovie = Join-Path $fixture 'replays/card.input'
$cardRecord = Initialize-MgsInputSession @options -RecordPath $cardMovie -AutoCard $true
Write-Text $cardMovie 'fake-input-data'
$cardReplay = Initialize-MgsInputSession @options -ReplayPath $cardMovie -AutoCard $true
Assert-True ($cardReplay.Identity -ceq $cardRecord.Identity) 'Auto-card replay identity changed.'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $cardMovie } 'auto-card setting differs'
Assert-Rejected { Get-MgsInputBooleanSetting ([pscustomobject]@{autoCard='false'}) 'autoCard' } 'Invalid autoCard'
$loadingMovie = Join-Path $fixture 'replays/fast-loading.input'
$loadingRecord = Initialize-MgsInputSession @options -RecordPath $loadingMovie -Presentation @{FastLoading=$true}
Write-Text $loadingMovie 'fake-input-data'
$loadingMetadata = Get-Content "$loadingMovie.session/session.json" -Raw | ConvertFrom-Json
Assert-True $loadingMetadata.presentation.FastLoading 'Fast loading presentation setting was not recorded.'
$loadingReplay = Initialize-MgsInputSession @options -ReplayPath $loadingMovie -Presentation @{FastLoading=$false}
Assert-True ($loadingReplay.Identity -ceq $loadingRecord.Identity) 'Loading presentation changed replay identity.'
Write-Text $modFile 'changed-mod'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie } 'assets differ'
Write-Text $modFile 'mod-content'
Write-Text $bin2 'changed-image'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie } 'assets differ'
Write-Text $bin2 'second-bin'
Write-Text $initialCard 'changed-snapshot'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie } 'cards differ'
Write-Text $initialCard 'initial-save'
$metadata.identityData.cards.bu00.files[0].path = '../../outside'
$metadata.identity = Get-MgsInputIdentity $metadata.identityData
Write-Text $metadataPath (ConvertTo-Json $metadata -Depth 20)
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie } 'cards differ'
Write-Text $metadataPath $metadataOriginal
$badCue = Join-Path $fixture 'discs/missing.cue'
Write-Text $badCue 'FILE missing.bin BINARY'
$changed = $options.Clone(); $changed.Disc = $badCue
Assert-Rejected { Initialize-MgsInputSession @changed -ReplayPath $movie } 'Missing input-session file'
Write-Text $badCue 'FILE broken'
Assert-Rejected { Initialize-MgsInputSession @changed -ReplayPath $movie } 'Invalid FILE'
Write-Text $badCue 'FILE track.wav WAVE'
Assert-Rejected { Initialize-MgsInputSession @changed -ReplayPath $movie } 'Unsupported cue image type'
$changed = $options.Clone(); $changed.ModsRoot = Join-Path $fixture 'absent-mods'
Assert-Rejected { Initialize-MgsInputSession @changed -ReplayPath $movie } 'Missing mods'
$existing = Join-Path $fixture 'existing.movie'
Write-Text $existing 'keep-this'
Assert-Rejected { Initialize-MgsInputSession @options -RecordPath $existing } 'requires a new'
Assert-True ([IO.File]::ReadAllText($existing) -eq 'keep-this') 'Existing movie overwritten.'
$checkpoint = Join-Path $fixture 'map-start.mgssave'
$checkpointBytes = [byte[]]::new(0xA40)
for ($i = 0; $i -lt $checkpointBytes.Length; $i++) { $checkpointBytes[$i] = $i % 251 }
[IO.File]::WriteAllBytes($checkpoint, $checkpointBytes)
$checkpointHash = Get-MgsInputFileHash $checkpoint
$checkpointMovie = Join-Path $fixture 'replays/checkpoint.input'
$checkpointRecord = @(Initialize-MgsInputSession @options -RecordPath $checkpointMovie -CheckpointPath $checkpoint)
Assert-True ($checkpointRecord.Count -eq 1) 'Checkpoint setup produced extra output.'
$checkpointRecord = $checkpointRecord[0]
$checkpointSnapshot = [IO.Path]::GetFullPath("$checkpointMovie.session/initial/checkpoint.mgssave")
Assert-True ($checkpointRecord.CheckpointPath -eq $checkpointSnapshot) 'Recording did not use immutable checkpoint snapshot.'
Assert-True ((Get-MgsInputFileHash $checkpointRecord.CheckpointPath) -ceq $checkpointHash) 'Checkpoint snapshot changed.'
$checkpointMetadataPath = "$checkpointMovie.session/session.json"
$checkpointMetadataOriginal = [IO.File]::ReadAllText($checkpointMetadataPath)
$checkpointMetadata = $checkpointMetadataOriginal | ConvertFrom-Json
Assert-True ($checkpointMetadata.identityData.startup.checkpointSha256 -ceq $checkpointHash) 'Checkpoint hash absent from startup identity.'
Assert-True ($checkpointMetadata.identityData.cards.bu00.files.Count -eq 1) 'Checkpoint leaked into memory-card identity.'
Write-Text $checkpointMovie 'fake-input-data'
$checkpointReplay = Initialize-MgsInputSession @options -ReplayPath $checkpointMovie
Assert-True ($checkpointReplay.CheckpointPath -eq $checkpointRecord.CheckpointPath) 'Replay did not discover checkpoint.'
Assert-True ($checkpointReplay.Identity -ceq $checkpointRecord.Identity) 'Checkpoint replay identity changed.'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $checkpointReplay.RuntimeDirectory 'checkpoint.mgssave'))) 'Checkpoint copied into card runtime.'
$explicitCheckpointReplay = Initialize-MgsInputSession @options -ReplayPath $checkpointMovie -CheckpointPath $checkpoint
Assert-True ($explicitCheckpointReplay.CheckpointPath -eq $checkpointSnapshot) 'Explicit matching checkpoint escaped snapshot.'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie -CheckpointPath $checkpoint } 'did not start from a checkpoint'
foreach ($change in @(@{Stage='s01a'}, @{StageMap=1})) {
    $changed = $options.Clone()
    foreach ($key in $change.Keys) { $changed[$key] = $change[$key] }
    Assert-Rejected { Initialize-MgsInputSession @changed -ReplayPath $checkpointMovie } 'Checkpoint startup requires'
    Assert-Rejected { Initialize-MgsInputSession @changed -RecordPath "$fixture/bad-start.input" -CheckpointPath $checkpoint } 'Checkpoint startup requires'
}
$checkpointBytes[0] = $checkpointBytes[0] -bxor 1
[IO.File]::WriteAllBytes($checkpoint, $checkpointBytes)
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $checkpointMovie -CheckpointPath $checkpoint } 'Supplied checkpoint differs'
$detachedCheckpointReplay = Initialize-MgsInputSession @options -ReplayPath $checkpointMovie
Assert-True ($detachedCheckpointReplay.Identity -ceq $checkpointRecord.Identity) 'Replay depended on changed checkpoint source.'
[IO.File]::WriteAllBytes($checkpointSnapshot, $checkpointBytes)
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $checkpointMovie } 'Checkpoint snapshot differs'
$checkpointBytes[0] = $checkpointBytes[0] -bxor 1
[IO.File]::WriteAllBytes($checkpointSnapshot, $checkpointBytes)
[IO.File]::Move($checkpointSnapshot, "$checkpointSnapshot.missing")
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $checkpointMovie } 'Missing input-session file'
[IO.File]::Move("$checkpointSnapshot.missing", $checkpointSnapshot)
Write-Text $checkpoint 'short'
Assert-Rejected { Initialize-MgsInputSession @options -RecordPath "$fixture/short.input" -CheckpointPath $checkpoint } '0xA40-byte'
$checkpointMetadata.identityData.startup.checkpointSha256 = 'invalid'
$checkpointMetadata.identity = Get-MgsInputIdentity $checkpointMetadata.identityData
Write-Text $checkpointMetadataPath (ConvertTo-Json $checkpointMetadata -Depth 20)
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $checkpointMovie } 'Invalid checkpoint hash'
Write-Text $checkpointMetadataPath $checkpointMetadataOriginal
Assert-True ([IO.File]::ReadAllText($normalCard) -eq 'new-human-progress') 'Checkpoint sessions modified normal cards.'
$outside = Join-Path $fixture 'outside'
$memoryMovie = Join-Path $fixture 'memory.input'
$memoryRecord = Initialize-MgsInputSession @options -RecordPath $memoryMovie -MantisMemorySeed 42
Write-Text $memoryMovie 'fake-input-data'
$memoryMetadata = Get-Content "$memoryMovie.session/session.json" -Raw | ConvertFrom-Json
Assert-True ((Get-MgsInputMantisMemory $memoryMetadata.identityData.startup) -eq 42) 'Memory profile seed missing.'
$memoryReplay = Initialize-MgsInputSession @options -ReplayPath $memoryMovie -MantisMemorySeed 42
Assert-True ($memoryReplay.Identity -ceq $memoryRecord.Identity) 'Memory profile replay identity changed.'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $memoryMovie } 'Mantis memory seed differs'
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $memoryMovie -MantisMemorySeed 43 } 'Mantis memory seed differs'
Assert-True ((Get-MgsInputMantisMemory $metadata.identityData.startup) -eq 0) 'Legacy replay acquired a memory profile.'
foreach ($invalid in @('42', $true, -1, 0, 2147483648)) {
    Assert-Rejected { Get-MgsInputMantisMemory ([pscustomobject]@{ mantisMemorySeed = $invalid }) } 'Invalid Mantis memory seed'
}
Assert-True ([IO.File]::ReadAllText($normalCard) -eq 'new-human-progress') 'Memory profile modified real cards.'
$prototypeRuntime = Join-Path $fixture '.local/godot-runtime'
Write-Text (Join-Path $prototypeRuntime 'bu00/save-file') 'prototype-save'
$prototypeMovie = Join-Path $fixture 'prototype.input'
$prototypeRecord = Initialize-MgsInputSession @options -RecordPath $prototypeMovie -RuntimeDirectory $prototypeRuntime
Assert-True ($prototypeRecord.RuntimeDirectory -eq $prototypeRuntime) 'Prototype recording used campaign cards.'
Assert-True ([IO.File]::ReadAllText("$prototypeMovie.session/initial/bu00/save-file") -eq 'prototype-save') 'Prototype cards were not snapshotted.'
Assert-True ([IO.File]::ReadAllText($normalCard) -eq 'new-human-progress') 'Prototype recording modified campaign cards.'
Write-Text (Join-Path $outside 'private-save') 'do-not-copy'
New-Item -ItemType Junction -Path (Join-Path $mods 'link') -Target $outside | Out-Null
Assert-Rejected { Initialize-MgsInputSession @options -ReplayPath $movie } 'reparse points'
$changed = $options.Clone(); $changed.ModsRoot = $null
$fresh = Join-Path $fixture 'fresh.movie'
$changed.ProjectDirectory = Join-Path $fixture 'empty-project'
$noCards = Initialize-MgsInputSession @changed -RecordPath $fresh
Write-Text $fresh 'fake-input-data'
$emptyReplay = Initialize-MgsInputSession @changed -ReplayPath $fresh
Assert-True (-not (Test-Path -LiteralPath (Join-Path $emptyReplay.RuntimeDirectory 'bu00'))) 'Absent card became present.'
New-Item -ItemType Junction -Path "$fresh.session/initial/bu00" -Target $outside | Out-Null
Assert-Rejected { Initialize-MgsInputSession @changed -ReplayPath $fresh } 'reparse points'
Assert-True ([IO.File]::ReadAllText((Join-Path $outside 'private-save')) -eq 'do-not-copy') 'External files changed.'
"PASS: session setup/asset/card identity, legacy identity, checkpoint snapshots and integrity, build changes, replay isolation, exclusive paths, cue parsing, metadata traversal, reparse rejection. Fixtures: $fixture"
