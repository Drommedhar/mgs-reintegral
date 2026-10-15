function Get-MgsPython {
    param([Parameter(Mandatory)][string]$Root)
    $relative = if (Test-Path -LiteralPath (Join-Path $Root 'sdk.json')) {
        . (Join-Path $PSScriptRoot 'download-tool.ps1')
        Install-MgsTool $Root 'python' | Out-Null
        '.tools/python/python.exe'
    } else { '.venv/Scripts/python.exe' }
    return Join-Path $Root $relative
}
