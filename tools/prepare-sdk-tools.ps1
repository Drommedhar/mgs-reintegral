[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$lock = Get-Content -LiteralPath (Join-Path $repository 'sources.lock.json') -Raw | ConvertFrom-Json
$tools = @{}
foreach ($name in @('python', 'powershell')) {
    $entry = $lock.sdkTools.$name
    $archive = Join-Path $repository ('.tools/' + $entry.url.Split('/')[-1])
    if (-not (Test-Path -LiteralPath $archive)) { Invoke-WebRequest -Uri $entry.url -OutFile $archive }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $entry.sha256) { throw "SDK tool checksum mismatch: $archive" }
    $directory = Join-Path $repository ".tools/sdk-prerequisites/$name-$($entry.version)"
    $receipt = Join-Path $directory '.archive-sha256'
    if (-not (Test-Path -LiteralPath $receipt)) {
        Expand-Archive -LiteralPath $archive -DestinationPath $directory -Force
        Set-Content -LiteralPath $receipt -Value $entry.sha256 -Encoding ascii
    }
    elseif ((Get-Content -LiteralPath $receipt -Raw).Trim() -ne $entry.sha256) { throw "SDK tool extraction differs from lock: $directory" }
    $tools[$name] = $directory
}
$notices = Join-Path $repository '.tools/sdk-prerequisites/godot-notices'
New-Item -ItemType Directory -Path $notices -Force | Out-Null
foreach ($name in @('LICENSE.txt', 'COPYRIGHT.txt', 'AUTHORS.md')) {
    $path = Join-Path $notices $name
    if (-not (Test-Path -LiteralPath $path)) {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/godotengine/godot/c971f93e7/$name" -OutFile $path
    }
}
$tools.godotNotices = $notices
return $tools
