Set-StrictMode -Version Latest

function Assert-MgsInputPlainPath {
    param([string]$Path)

    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Input sessions do not follow reparse points: $current"
            }
        }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}

function Get-MgsInputFileHash {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing input-session file: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Get-MgsInputTree {
    param([string]$Root)

    Assert-MgsInputPlainPath $Root
    if (-not (Test-Path -LiteralPath $Root)) {
        return [ordered]@{ present = $false; files = @() }
    }
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "Expected an input-session directory: $Root"
    }
    $pending = [Collections.Generic.Stack[string]]::new()
    $paths = [Collections.Generic.List[string]]::new()
    $pending.Push($Root)
    while ($pending.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Input sessions do not follow reparse points: $($item.FullName)"
            }
            if ($item.PSIsContainer) {
                $pending.Push($item.FullName)
            } else {
                $paths.Add([IO.Path]::GetRelativePath($Root, $item.FullName).Replace('\', '/'))
            }
        }
    }
    $paths.Sort([StringComparer]::Ordinal)
    $files = @(
        foreach ($relative in $paths) {
            [ordered]@{
                path = $relative
                sha256 = Get-MgsInputFileHash (Join-Path $Root $relative)
            }
        }
    )
    return [ordered]@{ present = $true; files = $files }
}

function Get-MgsInputCards {
    param([string]$Root)

    return [ordered]@{
        bu00 = Get-MgsInputTree (Join-Path $Root 'bu00')
        bu10 = Get-MgsInputTree (Join-Path $Root 'bu10')
    }
}

function Copy-MgsInputCards {
    param([string]$Source, [string]$Destination)

    Assert-MgsInputPlainPath $Source
    Assert-MgsInputPlainPath $Destination
    foreach ($port in @('bu00', 'bu10')) {
        $sourcePort = Join-Path $Source $port
        $tree = Get-MgsInputTree $sourcePort
        if (-not $tree.present) {
            continue
        }
        $destinationPort = Join-Path $Destination $port
        New-Item -ItemType Directory -Path $destinationPort -ErrorAction Stop | Out-Null
        foreach ($file in $tree.files) {
            $destinationFile = Join-Path $destinationPort $file.path
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destinationFile))
            [IO.File]::Copy((Join-Path $sourcePort $file.path), $destinationFile, $false)
        }
    }
}

function Get-MgsInputDisc {
    param([string]$CuePath)

    if (-not $CuePath) {
        return $null
    }
    $cueDirectory = [IO.Path]::GetDirectoryName($CuePath)
    $cueHash = Get-MgsInputFileHash $CuePath
    $images = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($line in Get-Content -LiteralPath $CuePath -ErrorAction Stop) {
        if ($line -notmatch '^\s*FILE\s') {
            continue
        }
        if ($line -notmatch '^\s*FILE\s+(?:"(?<quoted>[^"]+)"|(?<plain>.+?))\s+(?<type>\S+)\s*$') {
            throw "Invalid FILE declaration in cue: $CuePath"
        }
        if ($Matches.type -ine 'BINARY') {
            throw "Unsupported cue image type '$($Matches.type)' in $CuePath"
        }
        $name = if ($Matches.ContainsKey('quoted')) { $Matches.quoted } else { $Matches.plain }
        $imagePath = [IO.Path]::GetFullPath($name, $cueDirectory)
        if ($seen.Add($imagePath)) {
            $images.Add([ordered]@{
                path = [IO.Path]::GetRelativePath($cueDirectory, $imagePath).Replace('\', '/')
                sha256 = Get-MgsInputFileHash $imagePath
            })
        }
    }
    if ($images.Count -eq 0) {
        throw "Cue has no FILE image declarations: $CuePath"
    }
    return [ordered]@{ cueSha256 = $cueHash; images = $images.ToArray() }
}

function Get-MgsInputIdentity {
    param($Data)

    $json = ConvertTo-Json -InputObject $Data -Depth 20 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($sha.ComputeHash($bytes)).ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-MgsInputCheckpointHash {
    param([string]$Path)

    Assert-MgsInputPlainPath $Path
    $hash = Get-MgsInputFileHash $Path
    if ((Get-Item -LiteralPath $Path -ErrorAction Stop).Length -ne 0xA40) {
        throw "Checkpoint must contain a 0xA40-byte original save payload: $Path"
    }
    return $hash
}

function Get-MgsInputInvulnerability {
    param($Startup)

    $setting = $Startup.PSObject.Properties['invulnerable']
    if (-not $setting) { return $false }
    if ($setting.Value -isnot [bool]) { throw 'Invalid invulnerability setting in input session.' }
    return $setting.Value
}

function Get-MgsInputBooleanSetting {
    param($Startup, [ValidateSet('autoCard')][string]$Name)

    $setting = $Startup.PSObject.Properties[$Name]
    if (-not $setting) { return $false }
    if ($setting.Value -isnot [bool]) { throw "Invalid $Name setting in input session." }
    return $setting.Value
}

function Get-MgsInputMantisMemory {
    param($Startup)

    $setting = $Startup.PSObject.Properties['mantisMemorySeed']
    if (-not $setting) { return 0 }
    if (($setting.Value -isnot [int] -and $setting.Value -isnot [long]) -or
        $setting.Value -lt 1 -or $setting.Value -gt 2147483647) {
        throw 'Invalid Mantis memory seed in input session.'
    }
    return [int]$setting.Value
}

function Initialize-MgsInputSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectDirectory,
        [string]$RuntimeDirectory,
        [Parameter(Mandatory)][string]$Executable,
        [string]$RecordPath,
        [string]$ReplayPath,
        [Parameter(Mandatory)][string]$Disc,
        [string]$DiscTwo,
        [Parameter(Mandatory)][string]$Stage,
        [ValidateRange(-1, 65535)][int]$StageMap = -1,
        [bool]$BonusItems = $false,
        [bool]$Invulnerable = $false,
        [bool]$AutoCard = $false,
        [ValidateRange(0, 2147483647)][int]$MantisMemorySeed = 0,
        [string]$ModsRoot,
        [string]$TextPack,
        [string]$VoicePack,
        [string]$CheckpointPath,
        [hashtable]$Presentation
    )

    if ((-not $RecordPath) -eq (-not $ReplayPath)) {
        throw 'Specify exactly one of RecordPath and ReplayPath.'
    }
    $project = [IO.Path]::GetFullPath($ProjectDirectory)
    $executablePath = [IO.Path]::GetFullPath($Executable, $project)
    $executableHash = Get-MgsInputFileHash $executablePath
    $discPath = [IO.Path]::GetFullPath($Disc, $project)
    $discTwoPath = if ($DiscTwo) { [IO.Path]::GetFullPath($DiscTwo, $project) } else { $null }
    $modsPath = if ($ModsRoot) { [IO.Path]::GetFullPath($ModsRoot, $project) } else { $null }
    $checkpointSource = if ($CheckpointPath) { [IO.Path]::GetFullPath($CheckpointPath, $project) } else { $null }
    $checkpointHash = if ($checkpointSource) { Get-MgsInputCheckpointHash $checkpointSource } else { $null }
    if ($modsPath -and -not (Test-Path -LiteralPath $modsPath -PathType Container)) {
        throw "Missing mods directory: $modsPath"
    }
    $movie = [IO.Path]::GetFullPath($(if ($RecordPath) { $RecordPath } else { $ReplayPath }), $project)
    $session = "$movie.session"
    $initial = Join-Path $session 'initial'
    $checkpointSnapshot = Join-Path $initial 'checkpoint.mgssave'
    $startupCheckpoint = $null
    $metadataPath = Join-Path $session 'session.json'
    $runtime = if ($RuntimeDirectory) { [IO.Path]::GetFullPath($RuntimeDirectory, $project) } else {
        Join-Path $project '.local/runtime'
    }
    Assert-MgsInputPlainPath $session
    $data = [ordered]@{
        startup = [ordered]@{ stage = $Stage; map = $StageMap; bonusItems = $BonusItems }
        assets = [ordered]@{
            disc = Get-MgsInputDisc $discPath
            discTwo = Get-MgsInputDisc $discTwoPath
            mods = if ($modsPath) { Get-MgsInputTree $modsPath } else { $null }
        }
        cards = $null
    }
    if ($Invulnerable) { $data.startup.invulnerable = $true }
    $languagePaths = @{}
    foreach ($option in @('TextPack', 'VoicePack')) {
        $path = Get-Variable -Name $option -ValueOnly
        if ($path) {
            $path = [IO.Path]::GetFullPath($path, $project)
            $languagePaths[$option] = $path
            $data.assets[$option] = Get-MgsInputFileHash $path
        }
    }
    if ($AutoCard) { $data.startup.autoCard = $true }
    if ($MantisMemorySeed) { $data.startup.mantisMemorySeed = $MantisMemorySeed }
    if ($checkpointHash) {
        if ($Stage -cne 'title' -or $StageMap -ne -1) {
            throw 'Checkpoint startup requires Stage title and StageMap -1.'
        }
        $data.startup.checkpointSha256 = $checkpointHash
    }
    if ($RecordPath) {
        if ((Test-Path -LiteralPath $movie) -or (Test-Path -LiteralPath $session)) {
            throw "Recording requires a new movie and session directory: $movie"
        }
        $data.cards = Get-MgsInputCards $runtime
        New-Item -ItemType Directory -Path $initial -ErrorAction Stop | Out-Null
        Copy-MgsInputCards $runtime $initial
        if ((Get-MgsInputIdentity (Get-MgsInputCards $initial)) -ne (Get-MgsInputIdentity $data.cards)) {
            throw 'Initial memory cards changed while creating the recording snapshot.'
        }
        if ($checkpointSource) {
            [IO.File]::Copy($checkpointSource, $checkpointSnapshot, $false)
            if ((Get-MgsInputCheckpointHash $checkpointSnapshot) -cne $checkpointHash) {
                throw 'Checkpoint changed while creating the recording snapshot.'
            }
            $startupCheckpoint = $checkpointSnapshot
        }
        $identity = Get-MgsInputIdentity $data
        $metadata = [ordered]@{
            schema = 1
            identity = $identity
            identityData = $data
            executable = [ordered]@{ path = $executablePath; sha256 = $executableHash }
            sources = [ordered]@{ disc = $discPath; discTwo = $discTwoPath; modsRoot = $modsPath }
        }
        if ($Presentation) { $metadata.presentation = $Presentation }
        foreach ($option in $languagePaths.Keys) { $metadata.sources[$option] = $languagePaths[$option] }
        $metadataJson = ConvertTo-Json -InputObject $metadata -Depth 20
        [IO.File]::WriteAllText($metadataPath, $metadataJson, [Text.UTF8Encoding]::new($false))
        [void][IO.Directory]::CreateDirectory($runtime)
        return [pscustomobject]@{
            RuntimeDirectory = $runtime; InputPath = $movie; Identity = $identity; Mode = 'record'
            CheckpointPath = $startupCheckpoint
        }
    }
    if (-not (Test-Path -LiteralPath $movie -PathType Leaf)) {
        throw "Missing input recording: $movie"
    }
    Assert-MgsInputPlainPath $metadataPath
    $metadata = Get-Content -LiteralPath $metadataPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($metadata.schema -ne 1 -or $metadata.identity -cnotmatch '^[0-9a-f]{64}$') {
        throw "Unsupported input-session metadata: $metadataPath"
    }
    if ((Get-MgsInputIdentity $metadata.identityData) -cne $metadata.identity) {
        throw 'Input-session metadata does not match its recorded identity.'
    }
    $recordedInvulnerability = Get-MgsInputInvulnerability $metadata.identityData.startup
    if ((Get-MgsInputBooleanSetting $metadata.identityData.startup 'autoCard') -ne $AutoCard) {
        throw 'Replay auto-card setting differs from the recording session.'
    }
    if ((Get-MgsInputMantisMemory $metadata.identityData.startup) -ne $MantisMemorySeed) {
        throw 'Replay Mantis memory seed differs from the recording session.'
    }
    if ($recordedInvulnerability -ne $Invulnerable) {
        throw 'Replay invulnerability differs from the recording session.'
    }
    $recordedCheckpoint = $metadata.identityData.startup.PSObject.Properties['checkpointSha256']
    if ($recordedCheckpoint) {
        if ($recordedCheckpoint.Value -isnot [string] -or $recordedCheckpoint.Value -cnotmatch '^[0-9a-f]{64}$') {
            throw 'Invalid checkpoint hash in input-session metadata.'
        }
        if ($Stage -cne 'title' -or $StageMap -ne -1) {
            throw 'Checkpoint startup requires Stage title and StageMap -1.'
        }
        $snapshotHash = Get-MgsInputCheckpointHash $checkpointSnapshot
        if ($snapshotHash -cne $recordedCheckpoint.Value) {
            throw 'Checkpoint snapshot differs from the recording session.'
        }
        if ($checkpointHash -and $checkpointHash -cne $snapshotHash) {
            throw 'Supplied checkpoint differs from the recording session.'
        }
        $data.startup.checkpointSha256 = $snapshotHash
        $startupCheckpoint = $checkpointSnapshot
    } elseif ($checkpointHash) {
        throw 'The recording session did not start from a checkpoint.'
    }
    if (-not (Test-Path -LiteralPath $initial -PathType Container)) {
        throw "Missing initial card snapshot: $initial"
    }
    $data.cards = Get-MgsInputCards $initial
    foreach ($field in @('startup', 'assets', 'cards')) {
        if ((Get-MgsInputIdentity $data[$field]) -cne (Get-MgsInputIdentity $metadata.identityData.$field)) {
            throw "Replay $field differ from the recording session."
        }
    }
    $identity = Get-MgsInputIdentity $data
    if ($identity -cne $metadata.identity) {
        throw 'Replay identity differs from the recording session.'
    }
    $replayRuntime = Join-Path $session "replays/$([Guid]::NewGuid().ToString('N'))"
    Assert-MgsInputPlainPath $replayRuntime
    New-Item -ItemType Directory -Path $replayRuntime -ErrorAction Stop | Out-Null
    Copy-MgsInputCards $initial $replayRuntime
    if ((Get-MgsInputIdentity (Get-MgsInputCards $replayRuntime)) -cne (Get-MgsInputIdentity $data.cards)) {
        throw 'Initial memory cards changed while preparing the replay.'
    }
    return [pscustomobject]@{
        RuntimeDirectory = $replayRuntime; InputPath = $movie; Identity = $identity; Mode = 'replay'
        CheckpointPath = $startupCheckpoint
    }
}
