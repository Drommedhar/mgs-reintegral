Set-StrictMode -Version Latest

function Get-MgsFileHash {
    param([string]$Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $algorithm.Dispose() }
}

function Get-MgsArchive {
    param([string]$Root, $Entry)
    $ProgressPreference = 'SilentlyContinue'
    $cache = Join-Path $Root '.tools/downloads'
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    $archive = Join-Path $cache ([Uri]$Entry.url).Segments[-1]
    if (Test-Path -LiteralPath $archive) {
        if ((Get-MgsFileHash $archive) -eq $Entry.sha256) { return $archive }
        Remove-Item -LiteralPath $archive
    }
    $partial = $archive + '.' + [Guid]::NewGuid().ToString('N') + '.partial'
    try {
        Write-Host "Downloading $($Entry.url)"
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $Entry.url -OutFile $partial
        if ((Get-MgsFileHash $partial) -ne $Entry.sha256) {
            throw "Download checksum mismatch: $($Entry.url). Run the command again to retry."
        }
        Move-Item -LiteralPath $partial -Destination $archive
        return $archive
    }
    finally { if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial } }
}

function Get-MgsChildPath {
    param([string]$Root, [string]$Relative)
    $parent = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $path = [IO.Path]::GetFullPath((Join-Path $parent $Relative))
    if (-not $path.StartsWith($parent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Tool path escapes its directory: $Relative"
    }
    return $path
}

function Test-MgsTool {
    param([string]$Directory, $Entry)
    foreach ($file in $Entry.files.PSObject.Properties) {
        $path = Get-MgsChildPath $Directory $file.Name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        if ((Get-MgsFileHash $path) -ne $file.Value) { return $false }
    }
    return $true
}

function Expand-MgsTool {
    param([string]$Archive, [string]$Destination)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $path = Get-MgsChildPath $Destination $entry.FullName
            if ($entry.FullName.EndsWith('/')) { continue }
            New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $path, $false)
        }
    }
    finally { $zip.Dispose() }
}

function Test-MgsArchiveContents {
    param([string]$Archive, [string]$Directory)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($entry in $zip.Entries) {
            $path = Get-MgsChildPath $Directory $entry.FullName
            if ($entry.FullName.EndsWith('/')) { continue }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
            $stream = $entry.Open()
            try { $expected = [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
            finally { $stream.Dispose() }
            if ((Get-MgsFileHash $path) -ne $expected) { return $false }
        }
        return $true
    }
    finally { $algorithm.Dispose(); $zip.Dispose() }
}

function Install-MgsTool {
    param([string]$Root, [ValidateSet('godot', 'powershell', 'python')][string]$Name)
    $lock = Get-Content -LiteralPath (Join-Path $Root 'sources.lock.json') -Raw | ConvertFrom-Json
    $entry = $lock.sdkTools.$Name
    $tools = Join-Path $Root '.tools'
    $directory = Get-MgsChildPath $tools $entry.directory
    if (Test-MgsTool $directory $entry) { return $directory }
    New-Item -ItemType Directory -Path $tools -Force | Out-Null
    $guard = [IO.File]::Open((Join-Path $tools '.prepare.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    $staging = Get-MgsChildPath $tools ('.install-' + [Guid]::NewGuid().ToString('N'))
    $previous = Get-MgsChildPath $tools ('.previous-' + [Guid]::NewGuid().ToString('N'))
    $installed = $false
    try {
        if (Test-MgsTool $directory $entry) { return $directory }
        $archive = Get-MgsArchive $Root $entry
        Expand-MgsTool $archive $staging
        if ($Name -eq 'python') {
            [IO.File]::WriteAllText((Join-Path $staging 'python313._pth'), "python313.zip`n.`n../../tools`n", [Text.Encoding]::ASCII)
        }
        if (-not (Test-MgsTool $staging $entry)) { throw "Extracted $Name does not match the pinned files." }
        if (Test-Path -LiteralPath $directory) { Move-Item -LiteralPath $directory -Destination $previous }
        try { Move-Item -LiteralPath $staging -Destination $directory }
        catch {
            if (Test-Path -LiteralPath $previous) { Move-Item -LiteralPath $previous -Destination $directory }
            throw
        }
        $installed = $true
        Write-Host "Prepared $Name $($entry.version)"
        return $directory
    }
    finally {
        $cleanup = @($staging)
        if ($installed) { $cleanup += $previous }
        foreach ($temporary in $cleanup) {
            $checked = Get-MgsChildPath $tools ([IO.Path]::GetFileName($temporary))
            if (Test-Path -LiteralPath $checked) { Remove-Item -LiteralPath $checked -Recurse -Force }
        }
        $guard.Dispose()
    }
}
