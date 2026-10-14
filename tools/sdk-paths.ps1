function Get-MgsPython {
    param([Parameter(Mandatory)][string]$Root)
    $relative = if (Test-Path -LiteralPath (Join-Path $Root 'sdk.json')) {
        '.tools/python/python.exe'
    } else { '.venv/Scripts/python.exe' }
    return Join-Path $Root $relative
}
